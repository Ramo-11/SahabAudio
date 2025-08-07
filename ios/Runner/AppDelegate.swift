import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    var sharedDataChannel: FlutterMethodChannel?
    var sharedFilePath: String?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller = window?.rootViewController as! FlutterViewController
        sharedDataChannel = FlutterMethodChannel(name: "app.channel.shared.data", binaryMessenger: controller.binaryMessenger)
        
        sharedDataChannel!.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "getSharedData" {
                print("Flutter requested shared data: \(self.sharedFilePath ?? "nil")")
                result(self.sharedFilePath)
                // Don't clear the path here - let Flutter handle it
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("AppDelegate: Received shared file URL: \(url)")
        
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not get documents directory")
            return false
        }
        
        let fileName = url.lastPathComponent
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("Removed existing file at: \(destinationURL.path)")
            }
            
            // Copy the shared file to documents directory
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("Successfully copied file to: \(destinationURL.path)")
            
            // Store the file path
            self.sharedFilePath = destinationURL.path
            
            // Notify Flutter immediately if the channel is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let channel = self.sharedDataChannel {
                    print("Sending shared file notification to Flutter: \(destinationURL.path)")
                    channel.invokeMethod("onSharedFile", arguments: destinationURL.path) { result in
                        if let error = result as? FlutterError {
                            print("Error notifying Flutter: \(error.message ?? "Unknown error")")
                        } else {
                            print("Successfully notified Flutter about shared file")
                            // Clear the stored path after successful notification
                            self.sharedFilePath = nil
                        }
                    }
                } else {
                    print("Flutter channel not available yet, file will be handled on app startup")
                }
            }
            
            return true
            
        } catch {
            print("Error copying shared file: \(error)")
            return false
        }
    }
}