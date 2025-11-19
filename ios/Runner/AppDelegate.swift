import UIKit
import Flutter
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    var sharedDataChannel: FlutterMethodChannel?
    // CHANGED: Using a list to queue multiple files if the app isn't ready yet
    var pendingSharedFiles: [String] = []
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller = window?.rootViewController as! FlutterViewController
        
        sharedDataChannel = FlutterMethodChannel(name: "app.channel.shared.data", binaryMessenger: controller.binaryMessenger)
        
        sharedDataChannel!.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "getSharedData" {
                // CHANGED: Return ALL pending files as a list, then clear the queue
                if !self.pendingSharedFiles.isEmpty {
                    result(self.pendingSharedFiles)
                    self.pendingSharedFiles.removeAll()
                } else {
                    result(nil)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
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
            // Remove existing file if it exists to avoid conflicts
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            let filePath = destinationURL.path
            
            // CHANGED: Handle "Race Condition" for multiple files
            if let channel = self.sharedDataChannel {
                // If Flutter is ready, send the file immediately
                channel.invokeMethod("onSharedFile", arguments: filePath)
            } else {
                // If Flutter is NOT ready (cold boot), add to queue
                self.pendingSharedFiles.append(filePath)
            }
            
            return true
            
        } catch {
            print("Error copying shared file: \(error)")
            return false
        }
    }
}