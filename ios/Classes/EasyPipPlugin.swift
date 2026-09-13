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
    
    // Universele Apple Player componenten (Foutloos vanaf iOS 15.0+)
    private var nativePlayer: AVPlayer?
    private var playerLayer = AVPlayerLayer()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = EasyPipPlugin()
        
        EasyPipApiSetup.setUp(binaryMessenger: messenger, api: instance)
        instance.flutterApi = EasyPipFlutterApi(binaryMessenger: messenger)
        
        instance.bridgeChannel = FlutterMethodChannel(
            name: "com.jdbs.iptv.easy_pip_plugin.bridge",
            binaryMessenger: messenger
        )
        
        registrar.addMethodCallDelegate(instance, channel: FlutterMethodChannel(name: "easy_pip_plugin", binaryMessenger: messenger))
        
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

    func setupAutoPiP(width: Int64, height: Int64) throws {
        guard try isPiPSupported() else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else { return }
            let mainView = rootViewController.view
            
            if self.containerView == nil {
                let view = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                view.alpha = 0.01 // Onzichtbaar voor de gebruiker
                mainView?.addSubview(view)
                
                // FIX: Gebruik de universele AVPlayer met AVPlayerLayer (Geen iOS 17.2 vereist!)
                if let url = URL(string: "https://www.jdbs.nl/iptv/movie/demo/demo/20301.mp4") {
                    let player = AVPlayer(url: url)
                    self.nativePlayer = player
                    
                    self.playerLayer.player = player
                    self.playerLayer.frame = view.bounds
                    self.playerLayer.videoGravity = .resizeAspect
                    view.layer.addSublayer(self.playerLayer)
                    
                    player.isMuted = true // Voorkomt dubbel geluid
                    player.play()
                }
                self.containerView = view
            }
            
            if self.pipController == nil {
                // Gebruik de klassieke PlayerLayer initialisatie van AVPictureInPictureController
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
            if self.pipController == nil {
                try? self.setupAutoPiP(width: width, height: height)
            }
            if let controller = self.pipController, controller.isPictureInPicturePossible {
                controller.startPictureInPicture()
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

    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async { [weak self] in
            self?.bridgeChannel?.invokeMethod("onPiPStatusChanged", arguments: true)
        }
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async { [weak self] in
            self?.bridgeChannel?.invokeMethod("onPiPStatusChanged", arguments: false)
        }
    }
}

