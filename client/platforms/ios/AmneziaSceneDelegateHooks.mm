#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <dispatch/dispatch.h>

#include <QByteArray>
#include <QFile>
#include <QString>

#include "ios_controller.h"

using SceneOpenURLContexts = void (*)(id, SEL, UIScene *, NSSet<UIOpenURLContext *> *);
using SceneWillConnectToSession = void (*)(id, SEL, UIScene *, UISceneSession *, UISceneConnectionOptions *);
using SceneDidBecomeActive = void (*)(id, SEL, UIScene *);

static SceneOpenURLContexts g_originalSceneOpenURLContexts = nullptr;
static SceneWillConnectToSession g_originalSceneWillConnectToSession = nullptr;
static SceneDidBecomeActive g_originalSceneDidBecomeActive = nullptr;

static UIColor *loxley_backgroundColor()
{
    return [UIColor colorWithRed:0.01960784314 green:0.03137254902 blue:0.02745098039 alpha:1.0];
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

static void loxley_scene_didBecomeActive(id self, SEL _cmd, UIScene *scene)
{
    if (g_originalSceneDidBecomeActive) {
        g_originalSceneDidBecomeActive(self, _cmd, scene);
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

    SEL didBecomeActiveSelector = @selector(sceneDidBecomeActive:);
    Method didBecomeActiveMethod = class_getInstanceMethod(cls, didBecomeActiveSelector);
    if (didBecomeActiveMethod) {
        g_originalSceneDidBecomeActive = reinterpret_cast<SceneDidBecomeActive>(method_getImplementation(didBecomeActiveMethod));
        method_setImplementation(didBecomeActiveMethod, reinterpret_cast<IMP>(loxley_scene_didBecomeActive));
    } else {
        const char *types = "v@:@";
        class_addMethod(cls, didBecomeActiveSelector, reinterpret_cast<IMP>(loxley_scene_didBecomeActive), types);
    }
}

@end
