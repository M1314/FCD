import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static var orientationMask: UIInterfaceOrientationMask =
    UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let registrar = self.registrar(forPlugin: "OrientationLockPlugin") {
      let channel = FlutterMethodChannel(
        name: "orientation_lock",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "setOrientationMask" {
          if let args = call.arguments as? [String: Any],
             let mask = args["mask"] as? String {
            AppDelegate.updateOrientationMask(mask)
            result(nil as Any?)
          } else {
            result(
              FlutterError(
                code: "bad_args",
                message: "Missing orientation mask",
                details: nil
              )
            )
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationMask
  }

  static func updateOrientationMask(_ mask: String) {
    switch mask {
    case "portrait":
      orientationMask = .portrait
      forceDeviceOrientation(.portrait)
    case "landscape":
      orientationMask = .landscape
      forceDeviceOrientation(.landscape)
    case "all":
      orientationMask = .all
    default:
      break
    }

    DispatchQueue.main.async {
      for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else {
          continue
        }
        for window in windowScene.windows {
          if #available(iOS 16.0, *) {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
          }
        }
      }
      UIViewController.attemptRotationToDeviceOrientation()
    }
  }

  private static func forceDeviceOrientation(_ mask: UIInterfaceOrientationMask) {
    guard UIDevice.current.userInterfaceIdiom == .phone else {
      return
    }
    if mask.contains(.landscapeRight) || mask.contains(.landscapeLeft) {
      UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    } else if mask.contains(.portrait) {
      UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
    }
  }
}
