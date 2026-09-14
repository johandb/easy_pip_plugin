import Flutter
import UIKit
import AVKit
import AVFoundation

@objc public class EasyPipPlugin: NSObject, FlutterPlugin, EasyPipApi, AVPictureInPictureControllerDelegate {
    private var flutterApi: EasyPipFlutterApi?
    private var pipController: AVPictureInPictureController?
    private var bridgeChannel: FlutterMethodChannel?
    
    private var isVideoPlaying: Bool = true
    private var containerView: UIView?
    
    private var nativePlayer: AVPlayer?
    private var playerLayer = AVPlayerLayer()
    
    private var savedWidth: Int64 = 300
    private var savedHeight: Int64 = 200

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = EasyPipPlugin()
        
        EasyPipApiSetup.setUp(binaryMessenger: messenger, api: instance)
        instance.flutterApi = EasyPipFlutterApi(binaryMessenger: messenger)
        
        // 1. Maak het kanaal aan
        let bridgeChannelInstance = FlutterMethodChannel(
            name: "com.jdbs.iptv.easy_pip_plugin.bridge",
            binaryMessenger: messenger
        )
        instance.bridgeChannel = bridgeChannelInstance
        
        // CRUCIALE FIX: Registreer het bridge-kanaal ook als delegate bij de registrar!
        // Dit zorgt ervoor dat Flutter de berichten via 'flutter run' wél kan ontvangen en printen.
        registrar.addMethodCallDelegate(instance, channel: bridgeChannelInstance)
        
        registrar.addMethodCallDelegate(instance, channel: FlutterMethodChannel(name: "easy_pip_plugin", binaryMessenger: messenger))
        
        instance.setupAudioSession()
        
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(instance.appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }


    @objc private func appDidBecomeActive() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isVideoPlaying && (self.pipController?.isPictureInPictureActive == false) {
                self.nativePlayer?.play()
                self.playerLayer.setNeedsDisplay()
            }
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("EasyPipPlugin: AVAudioSession fout: \(error)")
        }
    }

    func isPiPSupported() throws -> Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    func updateStream(urlStr: String, isMuted: Bool) throws {
        guard let url = URL(string: urlStr) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let player = AVPlayer(url: url)
            self.nativePlayer = player
            self.playerLayer.player = player
            
            player.isMuted = isMuted
            self.setupAudioSession()
            
            if self.isVideoPlaying {
                player.play()
            }
        }
    }

    func setupAutoPiP(width: Int64, height: Int64) throws {
        guard try isPiPSupported() else { return }
        
        self.savedWidth = width
        self.savedHeight = height
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else { return }
            let mainView = rootViewController.view
            
            if self.containerView == nil {
                let view = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                view.alpha = 0.01 
                mainView?.addSubview(view)
                
                if let url = URL(string: "https://www.jdbs.nl/iptv/movie/demo/demo/20301.mp4") {
                    let player = AVPlayer(url: url)
                    self.nativePlayer = player
                    
                    self.playerLayer.player = player
                    self.playerLayer.frame = view.bounds
                    self.playerLayer.videoGravity = .resizeAspect
                    view.layer.addSublayer(self.playerLayer)
                    
                    player.isMuted = false 
                    player.play()
                }
                self.containerView = view
            }
            
            if self.pipController == nil {
                let controller = AVPictureInPictureController(playerLayer: self.playerLayer)
                if let controller = controller {
                    controller.delegate = self
                    if #available(iOS 14.2, *) {
                        controller.canStartPictureInPictureAutomaticallyFromInline = true
                    }
                    self.pipController = controller
                }
            }
        }
    }

    func enterPiP(width: Int64, height: Int64) throws {
        guard try isPiPSupported() else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.pipController != nil {
                self.pipController = nil
            }
            
            let controller = AVPictureInPictureController(playerLayer: self.playerLayer)
            if let controller = controller {
                controller.delegate = self
                if #available(iOS 14.2, *) {
                    controller.canStartPictureInPictureAutomaticallyFromInline = true
                }
                self.pipController = controller
            }
            
            self.setupAudioSession()
            self.nativePlayer?.play()
            
            // FIX VOOR ZWART BEELD (1E KEER): We verhogen de buffertijd naar 350ms zodat iOS gegarandeerd 
            // gevulde frames heeft voordat de PiP animatie start.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if let controller = self.pipController, controller.isPictureInPicturePossible {
                    controller.startPictureInPicture()
                } else {
                    self.pipController?.startPictureInPicture()
                }
            }
        }
    }

    func getPiPStatus() throws -> PipStatus {
        let supported = AVPictureInPictureController.isPictureInPictureSupported()
        let active = pipController?.isPictureInPictureActive ?? false
        return PipStatus(isSupported: supported, isActive: active)
    }
    
    func updatePlaybackState(isPlaying: Bool) throws {
        self.isVideoPlaying = isPlaying
        if isPlaying {
            nativePlayer?.play()
        } else {
            nativePlayer?.pause()
        }
    }

    // --- AVPictureInPictureControllerDelegate Callbacks ---

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupAudioSession()
            self.nativePlayer?.play() 
            
            let arguments: [String: Any] = ["isActive": true, "seekPosition": 0.0]
            self.bridgeChannel?.invokeMethod("onPiPStatusChanged", arguments: arguments)
        }
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                completionHandler(false)
                return 
            }
            self.setupAudioSession()
            
            let currentSeconds = CMTimeGetSeconds(self.nativePlayer?.currentTime() ?? .zero)
            let arguments: [String: Any] = [
                "isActive": false,
                "seekPosition": currentSeconds
            ]
            
            self.bridgeChannel?.invokeMethod("onPiPStatusChanged", arguments: arguments)
            
            if self.isVideoPlaying {
                self.nativePlayer?.play()
                self.playerLayer.setNeedsDisplay() 
            }
            
            completionHandler(true)
        }
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupAudioSession()
            
            let currentSeconds = CMTimeGetSeconds(self.nativePlayer?.currentTime() ?? .zero)
            let arguments: [String: Any] = [
                "isActive": false,
                "seekPosition": currentSeconds
            ]
            
            self.bridgeChannel?.invokeMethod("onPiPStatusChanged", arguments: arguments)
            
            if self.isVideoPlaying {
                self.nativePlayer?.play()
                self.playerLayer.setNeedsDisplay()
            }
        }
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaybackPaused paused: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if paused && self.isVideoPlaying {
                self.nativePlayer?.play()
            }
        }
    }
}

