import Flutter
import UIKit
import AVKit
import AVFoundation

public class EasyPipPlugin: NSObject, FlutterPlugin, EasyPipApi, AVPictureInPictureControllerDelegate {
    private var flutterApi: EasyPipFlutterApi?
    private var pipController: AVPictureInPictureController?
    
    // Status om bij te houden of de video speelt (nodig voor iOS updates)
    private var isVideoPlaying: Bool = true
    
    // Native render-lagen om iOS te voorzien van de verplichte videolaag
    private var sampleBufferLayer = AVSampleBufferDisplayLayer()
    private var containerView: UIView?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = EasyPipPlugin()
        
        // Setup de gegenereerde Pigeon Host API
        EasyPipApiSetup.setUp(binaryMessenger: messenger, api: instance)
        
        // Initialiseer de Flutter API voor status-callbacks naar Dart
        instance.flutterApi = EasyPipFlutterApi(binaryMessenger: messenger)
        
        // Configureer de AVAudioSession (Essentieel: zonder actieve audio/video op de achtergrond sluit iOS PiP direct)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("EasyPipPlugin: AVAudioSession kon niet worden geconfigureerd: \(error)")
        }
    }

    // --- EasyPipApi (Pigeon Interface) Implementatie ---

    public func isPiPSupported() throws -> Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    /// Bereidt de native iOS-views voor op automatische PiP bij swipen naar home.
    /// Roep dit in Flutter aan zodra de IPTV 'media_kit' stream start met afspelen.
    public func setupAutoPiP(width: Int64, height: Int64) throws {
        guard try isPiPSupported() else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Haal de hoofd-view van de Flutter-app op om onze layer aan te haken
            guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else { return }
            let mainView = rootViewController.view
            
            // Bouw de onzichtbare container view op als deze nog niet bestaat
            if self.containerView == nil {
                let view = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
                view.alpha = 0.01 // Onzichtbaar voor de gebruiker, maar detecteerbaar voor iOS
                mainView?.addSubview(view)
                
                self.sampleBufferLayer.frame = view.bounds
                self.sampleBufferLayer.videoGravity = .resizeAspect
                view.layer.addSublayer(self.sampleBufferLayer)
                self.containerView = view
            }
            
            // Initialiseer de PiP Controller met de Custom Content Source (Vereist iOS 15+)
            if self.pipController == nil {
                let contentSource = AVPictureInPictureController.ContentSource(
                    sampleBufferDisplayLayer: self.sampleBufferLayer,
                    playbackFilenameHint: nil
                )
                
                let controller = AVPictureInPictureController(contentSource: contentSource)
                controller.delegate = self
                
                // Activeer de magische vlag voor automatische PiP-transities bij home-gestures
                controller.canStartPictureInPictureAutomaticallyFromInline = true
                
                self.pipController = controller
            }
        }
    }

    /// Triggert Picture-in-Picture handmatig (bijv. via de testknop).
    public func enterPiP(width: Int64, height: Int64) throws {
        guard try isPiPSupported() else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Zorg dat de lagen zijn klaargezet (als setupAutoPiP niet eerder is aangeroepen)
            if self.pipController == nil {
                try? self.setupAutoPiP(width: width, height: height)
            }
            
            // Start de PiP-animatie als de controller er klaar voor is
            if let controller = self.pipController, controller.isPictureInPicturePossible {
                controller.startPictureInPicture()
            }
        }
    }

    public func getPiPStatus() throws -> PipStatus {
        let supported = AVPictureInPictureController.isPictureInPictureSupported()
        let active = pipController?.isPictureInPictureActive ?? false
        return PipStatus(isSupported: supported, isActive: active)
    }
    
    // NIEUW: Pigeon implementatie om de native iOS afspeelstatus bij te werken
    public func updatePlaybackState(isPlaying: Bool) throws {
        self.isVideoPlaying = isPlaying
        
        // iOS synchroniseert het native knopicoontje via de AVPictureInPictureController.
        // Door de controller te triggeren dat de playback rate veranderd is, switcht iOS
        // de knop automatisch tussen een Pause-symbool en een Play-symbool.
        if #available(iOS 15.0, *) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Forceert iOS om de tijdsbalk en afspeelstatus te verversen
                self.pipController?.invalidatePlaybackState()
            }
        }
    }

    // --- AVPictureInPictureControllerDelegate Callbacks ---

    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Breng Flutter op de hoogte dat PiP actief wordt, zodat de UI versmalt
        flutterApi?.onPiPStatusChanged(isActive: true) { _ in }
    }

    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Breng Flutter op de hoogte dat PiP stopt, zodat de normale UI herstelt
        flutterApi?.onPiPStatusChanged(isActive: false) { _ in }
    }
}

// --- Extensie voor iOS 15+ Custom Playback State Handling ---
extension EasyPipPlugin: AVPictureInPictureSampleBufferPlaybackDelegate {
    
    // GECORRIGEERD: Wordt afgevuurd als de gebruiker op de native iOS PiP play/pause knop drukt
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        self.isVideoPlaying = playing
        
        // Sluis de native iOS klik direct via Pigeon door naar Flutter
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.flutterApi?.onPlayPauseActionTriggered { _ in }
            
            // Zorg dat het native knopje visueel direct meespringt
            pictureInPictureController.invalidatePlaybackState()
        }
    }

    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // IPTV-streams zijn live uitzendingen, dus we retourneren een live óf oneindige tijdsduur.
        // Door een forward-moving range te sturen of een live status te veinsen, 
        // snapt iOS dat er geen traditionele scrubber getoond hoeft te worden.
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    // NIEUW VERPLICHTE DELEGATE METHODE: Vertelt iOS of de video momenteel speelt of gepauzeerd is
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return !isVideoPlaying
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newSize: CMSize) {
        // Eventuele afhandeling van venster-formaat wijzigingen
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completionHandler: @escaping () -> Void) {
        // Verplicht voor de interface; bevestig dat de actie is afgehandeld
        completionHandler()
    }
}
