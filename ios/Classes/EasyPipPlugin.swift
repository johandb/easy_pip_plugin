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
    
    // Onthoud de breedte en hoogte voor hergebruik bij re-initialisatie
    private var savedWidth: Int64 = 300
    private var savedHeight: Int64 = 200

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
        
        instance.setupAudioSession()
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
            
            // FIX: Als de controller kapot of nil is (na de 1e keer sluiten), maak hem opnieuw aan
            if self.pipController == nil {
                try? self.setupAutoPiP(width: width, height: height)
            }
            
            // FORCEER AFSPELEN: iOS weigert stabiele PiP-activatie als de speler niet al actief draait.
            self.setupAudioSession()
            self.nativePlayer?.play()
            
            // Geef de AVPlayer een fractie van een seconde de tijd om buffers te starten alvorens PiP te triggeren
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let controller = self.pipController, controller.isPictureInPicturePossible {
                    controller.startPictureInPicture()
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
            self.nativePlayer?.play() // Extra zekerheid dat het beeld niet bevriest bij opstarten
            self.bridgeChannel?.invokeMethod("onPiPStatusChanged", arguments: true)
        }
    }

    // FIX: Wanneer de PiP volledig stopt (gesloten door de gebruiker of hersteld naar de app)
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.setupAudioSession()
            if self.isVideoPlaying {
                self.nativePlayer?.play() // Direct verder spelen in-app zonder hapering
            }
            self.bridgeChannel?.invokeMethod("onPiPStatusChanged", arguments: false)
            
            // CRUCIAL FIX VOOR HET "2E KEER WERKT NIET" PROBLEEM:
            // Maak de oude controller leeg. Bij een volgende enterPiP() call wordt er direct een frisse controller gebouwd.
            self.pipController = nil
        }
    }
    
    // FIX VOOR AUTOMATISCH AFSPELEN: Mocht iOS om wat voor reden dan ook de stream pauzeren tijdens het openen, vangen we dit hier op.
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaybackPaused paused: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Als iOS probeert te pauzeren, maar we willen dat de video afspeelt, dwingen we hem terug naar play.
            if !paused && self.isVideoPlaying {
                self.nativePlayer?.play()
            }
        }
    }
}

