import UIKit
import Flutter
import MediaPlayer

class LockScreenEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(sendSkipForward), name: NSNotification.Name("SkipForward"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sendSkipBackward), name: NSNotification.Name("SkipBackward"), object: nil)
    }

    @objc private func sendSkipForward() {
        eventSink?("skipForward")
    }

    @objc private func sendSkipBackward() {
        eventSink?("skipBackward")
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

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
            } else if call.method == "updateNowPlaying" {
                if let args = call.arguments as? [String: Any] {
                    self.updateNowPlayingInfo(
                        title: args["title"] as? String ?? "Unknown",
                        artist: args["artist"] as? String ?? "Unknown",
                        duration: args["duration"] as? Double ?? 0.0
                    )
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        // Setup lock screen commands
        setupRemoteCommands()
        
        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)
        
        // Set up lock screen event channel
        let eventChannel = FlutterEventChannel(name: "lockscreen.control", binaryMessenger: controller.binaryMessenger)
        let streamHandler = LockScreenEventStreamHandler()
        eventChannel.setStreamHandler(streamHandler)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        let infoCenter = MPNowPlayingInfoCenter.default()

        // Enable skip forward command
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 10)]
        commandCenter.skipForwardCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("SkipForward"), object: nil)
            return .success
        }

        // Enable skip backward command
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 10)]
        commandCenter.skipBackwardCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("SkipBackward"), object: nil)
            return .success
        }

        // Configure initial now playing info to display on lock screen
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Now Playing"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Sahab Audio"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        infoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingInfo(title: String, artist: String, duration: Double) {
        let infoCenter = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo = infoCenter.nowPlayingInfo ?? [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        infoCenter.nowPlayingInfo = nowPlayingInfo
        print("Updated now playing info: \(title) by \(artist)")
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
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("Removed existing file at: \(destinationURL.path)")
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("Successfully copied file to: \(destinationURL.path)")
            
            self.sharedFilePath = destinationURL.path
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let channel = self.sharedDataChannel {
                    print("Sending shared file notification to Flutter: \(destinationURL.path)")
                    channel.invokeMethod("onSharedFile", arguments: destinationURL.path) { result in
                        if let error = result as? FlutterError {
                            print("Error notifying Flutter: \(error.message ?? "Unknown error")")
                        } else {
                            print("Successfully notified Flutter about shared file")
                            self.sharedFilePath = nil
                        }
                    }
                } else {
                    print("Flutter channel not available yet")
                }
            }
            
            return true
            
        } catch {
            print("Error copying shared file: \(error)")
            return false
        }
    }
}