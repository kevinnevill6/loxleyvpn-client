#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <dispatch/dispatch.h>

#include <QByteArray>
#include <QFile>
#include <QString>

#include "ios_controller.h"

using SceneOpenURLContexts = void (*)(id, SEL, UIScene *, NSSet<UIOpenURLContext *> *);
using SceneWillConnectToSession = void (*)(id, SEL, UIScene *, UISceneSession *, UISceneConnectionOptions *);

static SceneOpenURLContexts g_originalSceneOpenURLContexts = nullptr;
static SceneWillConnectToSession g_originalSceneWillConnectToSession = nullptr;
static UIResponder *g_loxleyFirstResponder = nil;
static bool g_loxleyOneTimeCodeAutofillActive = false;
using LoxleyOneTimeCodeHandler = void (*)(const char *code);
static LoxleyOneTimeCodeHandler g_loxleyOneTimeCodeHandler = nullptr;

@interface LoxleyOneTimeCodeInputTarget : NSObject <UITextFieldDelegate>
- (void)textDidChange:(UITextField *)field;
@end

static UITextField *g_loxleyOneTimeCodeField = nil;
static LoxleyOneTimeCodeInputTarget *g_loxleyOneTimeCodeTarget = nil;

static NSString *loxley_digitsOnly(NSString *value)
{
    NSMutableString *digits = [NSMutableString string];
    NSCharacterSet *decimalDigits = [NSCharacterSet decimalDigitCharacterSet];
    for (NSUInteger i = 0; i < value.length && digits.length < 6; ++i) {
        unichar character = [value characterAtIndex:i];
        if ([decimalDigits characterIsMember:character]) {
            [digits appendFormat:@"%C", character];
        }
    }
    return digits;
}

@implementation LoxleyOneTimeCodeInputTarget

- (void)textDidChange:(UITextField *)field
{
    NSString *digits = loxley_digitsOnly(field.text ?: @"");
    if (![field.text isEqualToString:digits]) {
        field.text = digits;
    }

    if (digits.length > 0 && g_loxleyOneTimeCodeHandler) {
        g_loxleyOneTimeCodeHandler(digits.UTF8String);
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *current = textField.text ?: @"";
    NSString *candidate = [current stringByReplacingCharactersInRange:range withString:string ?: @""];
    NSString *digits = loxley_digitsOnly(candidate);
    textField.text = digits;

    if (digits.length > 0 && g_loxleyOneTimeCodeHandler) {
        g_loxleyOneTimeCodeHandler(digits.UTF8String);
    }

    return NO;
}

@end

@interface UIResponder (LoxleyFirstResponder)
- (void)loxley_reportFirstResponder:(id)sender;
@end

@implementation UIResponder (LoxleyFirstResponder)
- (void)loxley_reportFirstResponder:(id)sender
{
    g_loxleyFirstResponder = self;
}
@end

static UIColor *loxley_backgroundColor()
{
    return [UIColor colorWithRed:0.01960784314 green:0.03137254902 blue:0.02745098039 alpha:1.0];
}

static UIResponder *loxley_currentFirstResponder()
{
    g_loxleyFirstResponder = nil;
    [[UIApplication sharedApplication] sendAction:@selector(loxley_reportFirstResponder:) to:nil from:nil forEvent:nil];
    return g_loxleyFirstResponder;
}

static void loxley_applyOneTimeCodeAutofill()
{
    if (@available(iOS 12.0, *)) {
        UIResponder *responder = loxley_currentFirstResponder();
        if (!responder) {
            return;
        }

        id traits = responder;
        if ([traits respondsToSelector:@selector(setTextContentType:)]) {
            [traits setTextContentType:g_loxleyOneTimeCodeAutofillActive ? UITextContentTypeOneTimeCode : nil];
        }
        if (g_loxleyOneTimeCodeAutofillActive) {
            if ([traits respondsToSelector:@selector(setKeyboardType:)]) {
                [traits setKeyboardType:UIKeyboardTypeNumberPad];
            }
            if ([traits respondsToSelector:@selector(setAutocorrectionType:)]) {
                [traits setAutocorrectionType:UITextAutocorrectionTypeNo];
            }
            if ([traits respondsToSelector:@selector(setSpellCheckingType:)]) {
                [traits setSpellCheckingType:UITextSpellCheckingTypeNo];
            }
        }
        if ([responder respondsToSelector:@selector(reloadInputViews)]) {
            [responder reloadInputViews];
        }
    }
}

static UIWindow *loxley_keyWindow()
{
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }

    return [UIApplication sharedApplication].keyWindow;
}

static UITextField *loxley_ensureOneTimeCodeField()
{
    if (!g_loxleyOneTimeCodeTarget) {
        g_loxleyOneTimeCodeTarget = [[LoxleyOneTimeCodeInputTarget alloc] init];
    }

    if (!g_loxleyOneTimeCodeField) {
        g_loxleyOneTimeCodeField = [[UITextField alloc] initWithFrame:CGRectMake(0, -120, 1, 1)];
        g_loxleyOneTimeCodeField.textContentType = UITextContentTypeOneTimeCode;
        g_loxleyOneTimeCodeField.keyboardType = UIKeyboardTypeNumberPad;
        g_loxleyOneTimeCodeField.autocorrectionType = UITextAutocorrectionTypeNo;
        g_loxleyOneTimeCodeField.spellCheckingType = UITextSpellCheckingTypeNo;
        g_loxleyOneTimeCodeField.textColor = UIColor.clearColor;
        g_loxleyOneTimeCodeField.tintColor = UIColor.clearColor;
        g_loxleyOneTimeCodeField.backgroundColor = UIColor.clearColor;
        g_loxleyOneTimeCodeField.borderStyle = UITextBorderStyleNone;
        g_loxleyOneTimeCodeField.alpha = 0.01;
        g_loxleyOneTimeCodeField.delegate = g_loxleyOneTimeCodeTarget;
        [g_loxleyOneTimeCodeField addTarget:g_loxleyOneTimeCodeTarget action:@selector(textDidChange:) forControlEvents:UIControlEventEditingChanged];
    }

    UIWindow *window = loxley_keyWindow();
    UIView *container = window.rootViewController.view ?: window;
    if (container && g_loxleyOneTimeCodeField.superview != container) {
        [g_loxleyOneTimeCodeField removeFromSuperview];
        [container addSubview:g_loxleyOneTimeCodeField];
    }

    return g_loxleyOneTimeCodeField;
}

extern "C" void loxley_setOneTimeCodeAutofillActive(bool active)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        g_loxleyOneTimeCodeAutofillActive = active;

        if (!active) {
            if (g_loxleyOneTimeCodeField) {
                g_loxleyOneTimeCodeField.text = @"";
                [g_loxleyOneTimeCodeField resignFirstResponder];
            }
            loxley_applyOneTimeCodeAutofill();
            return;
        }

        UITextField *field = loxley_ensureOneTimeCodeField();
        field.text = @"";
        field.textContentType = UITextContentTypeOneTimeCode;
        field.keyboardType = UIKeyboardTypeNumberPad;
        [field becomeFirstResponder];
        loxley_applyOneTimeCodeAutofill();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [g_loxleyOneTimeCodeField becomeFirstResponder];
            loxley_applyOneTimeCodeAutofill();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [g_loxleyOneTimeCodeField becomeFirstResponder];
            loxley_applyOneTimeCodeAutofill();
        });
    });
}

extern "C" void loxley_setOneTimeCodeAutofillHandler(LoxleyOneTimeCodeHandler handler)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        g_loxleyOneTimeCodeHandler = handler;
    });
}

static void loxley_applyFullScreenAppearance(UIScene *scene)
{
    if (@available(iOS 13.0, *)) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            UIColor *backgroundColor = loxley_backgroundColor();
            CGRect fullBounds = windowScene.screen.bounds;

            for (UIWindow *window in windowScene.windows) {
                window.backgroundColor = backgroundColor;
                window.frame = fullBounds;
                window.clipsToBounds = NO;

                UIViewController *rootController = window.rootViewController;
                if (!rootController) {
                    continue;
                }

                rootController.view.backgroundColor = backgroundColor;
                rootController.view.frame = window.bounds;
                rootController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                rootController.additionalSafeAreaInsets = UIEdgeInsetsZero;

                if (@available(iOS 11.0, *)) {
                    rootController.view.insetsLayoutMarginsFromSafeArea = NO;
                }
            }
        });
    }
}

static void amnezia_handleURL(NSURL *url)
{
    if (!url || !url.isFileURL) {
        return;
    }

    QString filePath(url.path.UTF8String);
    if (filePath.isEmpty()) {
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (filePath.contains("backup")) {
            IosController::Instance()->importBackupFromOutside(filePath);
            return;
        }

        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly)) {
            return;
        }

        const QByteArray data = file.readAll();
        IosController::Instance()->importConfigFromOutside(QString::fromUtf8(data));
    });
}

static void amnezia_scene_openURLContexts(id self, SEL _cmd, UIScene *scene, NSSet<UIOpenURLContext *> *contexts)
{
    if (g_originalSceneOpenURLContexts) {
        g_originalSceneOpenURLContexts(self, _cmd, scene, contexts);
    }

    if (!contexts || contexts.count == 0) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        for (UIOpenURLContext *context in contexts) {
            amnezia_handleURL(context.URL);
        }
    }
}

static void loxley_scene_willConnectToSession(id self, SEL _cmd, UIScene *scene, UISceneSession *session, UISceneConnectionOptions *connectionOptions)
{
    if (g_originalSceneWillConnectToSession) {
        g_originalSceneWillConnectToSession(self, _cmd, scene, session, connectionOptions);
    }

    loxley_applyFullScreenAppearance(scene);
}

@interface AmneziaSceneDelegateHooks : NSObject
@end

@implementation AmneziaSceneDelegateHooks

+ (void)load
{
    Class cls = objc_getClass("QIOSWindowSceneDelegate");
    if (!cls) {
        return;
    }

    SEL selector = @selector(scene:openURLContexts:);
    Method method = class_getInstanceMethod(cls, selector);
    if (method) {
        g_originalSceneOpenURLContexts = reinterpret_cast<SceneOpenURLContexts>(method_getImplementation(method));
        method_setImplementation(method, reinterpret_cast<IMP>(amnezia_scene_openURLContexts));
    } else {
        const char *types = "v@:@@";
        class_addMethod(cls, selector, reinterpret_cast<IMP>(amnezia_scene_openURLContexts), types);
    }

    SEL willConnectSelector = @selector(scene:willConnectToSession:options:);
    Method willConnectMethod = class_getInstanceMethod(cls, willConnectSelector);
    if (willConnectMethod) {
        g_originalSceneWillConnectToSession = reinterpret_cast<SceneWillConnectToSession>(method_getImplementation(willConnectMethod));
        method_setImplementation(willConnectMethod, reinterpret_cast<IMP>(loxley_scene_willConnectToSession));
    }

}

@end
