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
static UIResponder *g_guardoFirstResponder = nil;
static bool g_guardoOneTimeCodeAutofillActive = false;
using GuardoOneTimeCodeHandler = void (*)(const char *code);
static GuardoOneTimeCodeHandler g_guardoOneTimeCodeHandler = nullptr;

@interface GuardoOneTimeCodeInputTarget : NSObject <UITextFieldDelegate>
- (void)textDidChange:(UITextField *)field;
@end

static UITextField *g_guardoOneTimeCodeField = nil;
static GuardoOneTimeCodeInputTarget *g_guardoOneTimeCodeTarget = nil;

static NSString *guardo_digitsOnly(NSString *value)
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

@implementation GuardoOneTimeCodeInputTarget

- (void)textDidChange:(UITextField *)field
{
    NSString *digits = guardo_digitsOnly(field.text ?: @"");
    if (![field.text isEqualToString:digits]) {
        field.text = digits;
    }

    if (digits.length > 0 && g_guardoOneTimeCodeHandler) {
        g_guardoOneTimeCodeHandler(digits.UTF8String);
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *current = textField.text ?: @"";
    NSString *candidate = [current stringByReplacingCharactersInRange:range withString:string ?: @""];
    NSString *digits = guardo_digitsOnly(candidate);
    textField.text = digits;

    if (digits.length > 0 && g_guardoOneTimeCodeHandler) {
        g_guardoOneTimeCodeHandler(digits.UTF8String);
    }

    return NO;
}

@end

@interface UIResponder (GuardoFirstResponder)
- (void)guardo_reportFirstResponder:(id)sender;
@end

@implementation UIResponder (GuardoFirstResponder)
- (void)guardo_reportFirstResponder:(id)sender
{
    g_guardoFirstResponder = self;
}
@end

static UIColor *guardo_backgroundColor()
{
    return [UIColor colorWithRed:0.01960784314 green:0.03137254902 blue:0.02745098039 alpha:1.0];
}

static UIResponder *guardo_currentFirstResponder()
{
    g_guardoFirstResponder = nil;
    [[UIApplication sharedApplication] sendAction:@selector(guardo_reportFirstResponder:) to:nil from:nil forEvent:nil];
    return g_guardoFirstResponder;
}

static void guardo_applyOneTimeCodeAutofill()
{
    if (@available(iOS 12.0, *)) {
        UIResponder *responder = guardo_currentFirstResponder();
        if (!responder) {
            return;
        }

        id traits = responder;
        if ([traits respondsToSelector:@selector(setTextContentType:)]) {
            [traits setTextContentType:g_guardoOneTimeCodeAutofillActive ? UITextContentTypeOneTimeCode : nil];
        }
        if (g_guardoOneTimeCodeAutofillActive) {
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

static UIWindow *guardo_keyWindow()
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

static UITextField *guardo_ensureOneTimeCodeField()
{
    if (!g_guardoOneTimeCodeTarget) {
        g_guardoOneTimeCodeTarget = [[GuardoOneTimeCodeInputTarget alloc] init];
    }

    if (!g_guardoOneTimeCodeField) {
        g_guardoOneTimeCodeField = [[UITextField alloc] initWithFrame:CGRectMake(0, -120, 1, 1)];
        g_guardoOneTimeCodeField.textContentType = UITextContentTypeOneTimeCode;
        g_guardoOneTimeCodeField.keyboardType = UIKeyboardTypeNumberPad;
        g_guardoOneTimeCodeField.autocorrectionType = UITextAutocorrectionTypeNo;
        g_guardoOneTimeCodeField.spellCheckingType = UITextSpellCheckingTypeNo;
        g_guardoOneTimeCodeField.textColor = UIColor.clearColor;
        g_guardoOneTimeCodeField.tintColor = UIColor.clearColor;
        g_guardoOneTimeCodeField.backgroundColor = UIColor.clearColor;
        g_guardoOneTimeCodeField.borderStyle = UITextBorderStyleNone;
        g_guardoOneTimeCodeField.alpha = 0.01;
        g_guardoOneTimeCodeField.delegate = g_guardoOneTimeCodeTarget;
        [g_guardoOneTimeCodeField addTarget:g_guardoOneTimeCodeTarget action:@selector(textDidChange:) forControlEvents:UIControlEventEditingChanged];
    }

    UIWindow *window = guardo_keyWindow();
    UIView *container = window.rootViewController.view ?: window;
    if (container && g_guardoOneTimeCodeField.superview != container) {
        [g_guardoOneTimeCodeField removeFromSuperview];
        [container addSubview:g_guardoOneTimeCodeField];
    }

    return g_guardoOneTimeCodeField;
}

extern "C" void guardo_setOneTimeCodeAutofillActive(bool active)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        g_guardoOneTimeCodeAutofillActive = active;

        if (!active) {
            if (g_guardoOneTimeCodeField) {
                g_guardoOneTimeCodeField.text = @"";
                [g_guardoOneTimeCodeField resignFirstResponder];
            }
            guardo_applyOneTimeCodeAutofill();
            return;
        }

        UITextField *field = guardo_ensureOneTimeCodeField();
        field.text = @"";
        field.textContentType = UITextContentTypeOneTimeCode;
        field.keyboardType = UIKeyboardTypeNumberPad;
        [field becomeFirstResponder];
        guardo_applyOneTimeCodeAutofill();

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [g_guardoOneTimeCodeField becomeFirstResponder];
            guardo_applyOneTimeCodeAutofill();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [g_guardoOneTimeCodeField becomeFirstResponder];
            guardo_applyOneTimeCodeAutofill();
        });
    });
}

extern "C" void guardo_setOneTimeCodeAutofillHandler(GuardoOneTimeCodeHandler handler)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        g_guardoOneTimeCodeHandler = handler;
    });
}

static void guardo_applyFullScreenAppearance(UIScene *scene)
{
    if (@available(iOS 13.0, *)) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            UIColor *backgroundColor = guardo_backgroundColor();
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

static void guardo_scene_willConnectToSession(id self, SEL _cmd, UIScene *scene, UISceneSession *session, UISceneConnectionOptions *connectionOptions)
{
    if (g_originalSceneWillConnectToSession) {
        g_originalSceneWillConnectToSession(self, _cmd, scene, session, connectionOptions);
    }

    guardo_applyFullScreenAppearance(scene);
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
        method_setImplementation(willConnectMethod, reinterpret_cast<IMP>(guardo_scene_willConnectToSession));
    }

}

@end
