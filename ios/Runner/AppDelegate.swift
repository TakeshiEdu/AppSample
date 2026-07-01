import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let audioChannel = FlutterMethodChannel(
      name: "com.takeshi.mr_remover/audio",
      binaryMessenger: controller.binaryMessenger
    )
    audioChannel.setMethodCallHandler { call, result in
      guard call.method == "prepareWav" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "入力値が不正です。", details: nil))
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let outputPath = try AudioProcessor.convertToWav(path: path)
          DispatchQueue.main.async {
            result(outputPath)
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "EXTRACTION_FAILED", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
