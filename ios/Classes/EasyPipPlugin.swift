import Flutter
import UIKit
import AVKit
import AVFoundation

@objc public class EasyPipPlugin: NSObject, FlutterPlugin, EasyPipApi, AVPictureInPictureControllerDelegate {
    private var flutterApi: EasyPipFlutterApi?
    private var pipController: AVPictureInPictureController?
    private var binaryMessenger: FlutterBinaryMessenger? 
    
    private var isVideoPlaying: Bool = true
    private var containerView: UIView?
    
    private var nativePlayer: AVPlayer?
    private var playerLayer = AVPlayerLayer()
    
    private var savedWidth: Int64 = 300
    private var savedHeight: Int64 = 200

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = EasyPipPlugin()
        instance.binaryMessenger = messenger
        
        EasyPipApiSetup.setUp(binaryMessenger: messenger, api: instance)
        instance.flutterApi = EasyPipFlutterApi(binaryMessenger: messenger)
        
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
            
            let playerItem = AVPlayerItem(url: url)
            if let player = self.nativePlayer {
                player.replaceCurrentItem(with: playerItem)
            } else {
                let player = AVPlayer(playerItem: playerItem)
                self.nativePlayer = player
                self.playerLayer.player = player
            }
            
            self.nativePlayer?.isMuted = isMuted
            self.setupAudioSession()
            
            if self.isVideoPlaying {
                self.nativePlayer?.play()
            }
        }
    }

    func setupAutoPiP(width: Int64, height: Int64, urlStr: String, startTimeInSeconds: Double) throws {
        guard try isPiPSupported() else { return }
        
        self.savedWidth = width
        self.savedHeight = height
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else { return }
            let mainView = rootViewController.view
            guard let url = URL(string: urlStr) else { return }
            
            // IPTV-vriendelijke headers om blokkades van de server te omzeilen
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": "Mozilla/5.0 (Linux; Android 10)"]])
            let playerItem = AVPlayerItem(asset: asset)
            
            // Schone streaming-instellingen voor .ts live zenders
            playerItem.preferredForwardBufferDuration = 5
            
            let targetTime = CMTimeMakeWithSeconds(startTimeInSeconds, preferredTimescale: Int32(NSEC_PER_SEC))
            let isSameUrl = (self.nativePlayer?.currentItem?.asset as? AVURLAsset)?.url == url
            
            if self.containerView == nil {
                let view = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                view.alpha = 0.01 
                mainView?.addSubview(view)
                
                let player = AVPlayer(playerItem: playerItem)
                // GEFIXT: Niet-bestaande 'automaticallyPreservesTimeHolesFromStart' regel is volledig verwijderd
                self.nativePlayer = player
                
                self.playerLayer.player = player
                self.playerLayer.frame = view.bounds
                self.playerLayer.videoGravity = .resizeAspect
                view.layer.addSublayer(self.playerLayer)
                
                player.isMuted = false 
                player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                player.play()
                
                self.containerView = view
            } else {
                if isSameUrl {
                    let currentTime = self.nativePlayer?.currentTime().seconds ?? 0.0
                    if abs(currentTime - startTimeInSeconds) > 1.5 {
                        self.nativePlayer?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                } else {
                    self.pipController = nil
                    let player = AVPlayer(playerItem: playerItem)
                    self.nativePlayer = player
                    self.playerLayer.player = player
                    
                    if let view = self.containerView {
                        view.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
                        self.playerLayer.frame = view.bounds
                    }
                    
                    player.isMuted = false
                    player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    player.play()
                }
                
                if self.isVideoPlaying {
                    self.nativePlayer?.play()
                }
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
            
            self.containerView?.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            self.playerLayer.frame = self.containerView?.bounds ?? .zero
            
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
        let currentPositionSeconds = nativePlayer?.currentTime().seconds ?? 0.0
        
        return PipStatus(isSupported: supported, isActive: active, lastPositionSeconds: currentPositionSeconds)
    }

    func minimizeApp() throws {
        DispatchQueue.main.async {
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
        }
    }
    
    func updatePlaybackState(isPlaying: Bool) throws {
        self.isVideoPlaying = isPlaying
        if isPlaying {
            nativePlayer?.play()
        } else {
            nativePlayer?.pause()
        }
    }

    private func sendNativePiPStatus(isActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let messenger = self.binaryMessenger else { return }
            
            let channelName = "dev.flutter.pigeon.easy_pip_plugin.EasyPipFlutterApi.onPiPStatusChanged"
            let arguments: [Any] = [isActive]
            
            let codec = FlutterStandardMessageCodec.sharedInstance()
            let messageData = codec.encode(arguments)
            
            messenger.send(onChannel: channelName, message: messageData)
        }
    }

    // --- AVPictureInPictureControllerDelegate Callbacks ---

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        self.setupAudioSession()
        self.sendNativePiPStatus(isActive: false)
        
        if self.isVideoPlaying {
            self.nativePlayer?.play()
            self.playerLayer.setNeedsDisplay() 
        }
        completionHandler(true)
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.setupAudioSession()
        self.nativePlayer?.play() 
        self.sendNativePiPStatus(isActive: true)
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.setupAudioSession()
        
        self.nativePlayer?.pause()
        self.nativePlayer = nil
        self.playerLayer.player = nil
        
        self.containerView?.alpha = 0.01
        self.sendNativePiPStatus(isActive: false)
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaybackPaused paused: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isVideoPlaying {
                self.nativePlayer?.play()
            }
        }
    }
}

