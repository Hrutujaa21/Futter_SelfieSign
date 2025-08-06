import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    var flutterNavController: UINavigationController?

    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let flutterViewController = FlutterViewController()
        
        // ✅ Wrap Flutter view in Navigation Controller
        let navController = UINavigationController(rootViewController: flutterViewController)
        navController.setNavigationBarHidden(true, animated: false) // Hide nav bar for Flutter UI
        navController.modalPresentationStyle = .fullScreen

        // ✅ Set as rootViewController of window
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = navController
        self.window?.makeKeyAndVisible()

        self.flutterNavController = navController

        // ✅ Setup platform channel
        let channel = FlutterMethodChannel(
            name: "com.flutter.native/channel",
            binaryMessenger: flutterViewController.binaryMessenger
        )

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "captureSelfie":
                CaptureManager.shared.startCapture(mode: .selfie, flutterResult: result)
            case "captureSingleSignature":
                CaptureManager.shared.startCapture(mode: .singleSignature, flutterResult: result)
            case "captureDualSignature":
                CaptureManager.shared.startCapture(mode: .dualSignature, flutterResult: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}


//import Flutter
//import UIKit
//
//@UIApplicationMain
//@objc class AppDelegate: FlutterAppDelegate {
//    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        let controller = window?.rootViewController as! FlutterViewController
//        let channel = FlutterMethodChannel(
//            name: "com.flutter.native/channel",
//            binaryMessenger: controller.binaryMessenger
//        )
//
//        channel.setMethodCallHandler { call, result in
//            switch call.method {
//            case "captureSelfie":
//                CaptureManager.shared.startCapture(mode: .selfie, flutterResult: result)
//            case "captureSingleSignature":
//                CaptureManager.shared.startCapture(mode: .singleSignature, flutterResult: result)
//            case "captureDualSignature":
//                CaptureManager.shared.startCapture(mode: .dualSignature, flutterResult: result)
//            default:
//                result(FlutterMethodNotImplemented)
//            }
//        }
//        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//    }
//}
