//
//  AVPlayer.swift
//  HLSPlayer
//
//  Created by Alexey Demin on 2024-10-09.
//

#if canImport(UIKit)
import UIKit
#endif
import AVFoundation

final class AVPlayer: NSObject, @preconcurrency Player, @unchecked Sendable {
    
    private let player = AVFoundation.AVPlayer(playerItem: nil)
    
    private var willEnterForegroundObserver: NSObjectProtocol?
    private var didEnterBackgroundObserver: NSObjectProtocol?
    
    private var itemDidPlayToEndTimeObserver: NSObjectProtocol?
    private var itemFailedToPlayToEndTimeObserver: NSObjectProtocol?
    private var itemFailureObserver: NSObjectProtocol?
    private var itemErrorObserver: NSObjectProtocol?

    lazy var layer: CALayer = AVPlayerLayer(player: player)

    override init() {
        super.init()
        
        player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        
        #if canImport(UIKit)
        willEnterForegroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self, let layer = layer as? AVPlayerLayer else {
                return
            }
            layer.player = player
        }
        didEnterBackgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self, let layer = layer as? AVPlayerLayer else {
                return
            }
            layer.player = nil
        }
        #endif
    }
    
    deinit {
        currentItem = nil // Remove item observers.
        
        player.removeObserver(self, forKeyPath: "rate")
        
        if let willEnterForegroundObserver {
            NotificationCenter.default.removeObserver(willEnterForegroundObserver)
        }
        if let didEnterBackgroundObserver {
            NotificationCenter.default.removeObserver(didEnterBackgroundObserver)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if isPlaying {
                isBuffering = false
            }
            onChangeStatus?()
        } else if keyPath == "playbackBufferEmpty" {
            isBuffering = true
            onChangeStatus?()
        } else if keyPath == "playbackLikelyToKeepUp" || keyPath == "playbackBufferFull" {
            isBuffering = false
            onChangeStatus?()
        } else if keyPath == "presentationSize" {
            if let currentItem = player.currentItem {
                print("Presentation size: \(Int(currentItem.presentationSize.height))")
            }
        }
    }
    
    var defaultRate: Double {
        get {
            if #available(iOS 16.0, macOS 13.0, *) {
                Double(player.defaultRate)
            } else {
                0
            }
        }
        set {
            if #available(iOS 16.0, macOS 13.0, *) {
                player.defaultRate = Float(newValue)
            }
        }
    }
    
    @MainActor var rate: Double {
        get {
            Double(player.rate)
        }
        set {
            player.rate = Float(newValue)
        }
    }
    
    var isBuffering = false
    
    var onChangeStatus: (() -> Void)?

    var volume: Double {
        get {
            Double(player.volume)
        }
        set {
            player.volume = Float(newValue)
        }
    }
    
    var actionAtItemEnd: Action {
        get {
            switch player.actionAtItemEnd {
            case .advance: .advance
            case .pause: .pause
            case .none: .none
            @unknown default: .none
            }
        }
        set {
            player.actionAtItemEnd = switch newValue {
            case .advance: .advance
            case .pause: .pause
            case .none: .none
            }
        }
    }
    
    var itemDidPlayToEndTime: (() -> Void)?

    var currentItem: AVPlayerItem? {
        didSet {
            if let item = oldValue {
                item.removeObserver(self, forKeyPath: "playbackBufferEmpty")
                item.removeObserver(self, forKeyPath: "playbackBufferFull")
                item.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
                item.removeObserver(self, forKeyPath: "presentationSize")
//                item.removeObserver(self, forKeyPath: "status")
            }
            
            if let itemFailedToPlayToEndTimeObserver {
                self.itemFailedToPlayToEndTimeObserver = nil
                NotificationCenter.default.removeObserver(itemFailedToPlayToEndTimeObserver)
            }
            
            if let itemDidPlayToEndTimeObserver {
                self.itemDidPlayToEndTimeObserver = nil
                NotificationCenter.default.removeObserver(itemDidPlayToEndTimeObserver)
            }
            
            if let itemFailureObserver {
                self.itemFailureObserver = nil
                NotificationCenter.default.removeObserver(itemFailureObserver)
            }
            
            if let itemErrorObserver {
                self.itemErrorObserver = nil
                NotificationCenter.default.removeObserver(itemErrorObserver)
            }
                        
            if let currentItem {
                itemDidPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: currentItem, queue: nil) { [weak self] _ in
                    self?.itemDidPlayToEndTime?()
                }
                
                itemFailedToPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: currentItem, queue: OperationQueue.main) { notification in
                    #if DEBUG
                    print("Player Error: \(notification.description)")
                    #endif
                }

                itemFailureObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: currentItem, queue: .main) { notification in
                    #if DEBUG
                    print("Player Error: \(notification.description)")
                    #endif
                }
                
                itemErrorObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.newErrorLogEntryNotification, object: currentItem, queue: .main) { [weak item = currentItem] _ in
                    let event = item?.errorLog()?.events.last
                    if let event {
                        #if DEBUG
                        print("Player Error: \(event.errorComment ?? "<no comment>")")
                        #endif
                    }
                }
                
                currentItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
                currentItem.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
                currentItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
                currentItem.addObserver(self, forKeyPath: "presentationSize", options: [], context: nil)
//                currentItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            }
            
            player.replaceCurrentItem(with: currentItem)
        }
    }
    
    func setItem(url: URL) {
        let item = AVPlayerItem(url: url)
        if #available(iOS 14.0, macOS 11.0, *) {
            item.startsOnFirstEligibleVariant = true
        }
        currentItem = item
    }

    var currentTime: TimeInterval {
        player.currentTime().seconds
    }
    
    func seek(to seconds: TimeInterval) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 30))
    }

    @MainActor func play() {
        if #available(iOS 16.0, macOS 13.0, *) {
            player.play()
        } else {
            DispatchQueue.main.async {
                self.player.play()
            }
        }
    }
    
    @MainActor func pause() {
        if #available(iOS 16.0, macOS 13.0, *) {
            player.pause()
        } else {
            DispatchQueue.main.async {
                self.player.pause()
            }
        }
    }
}

extension AVPlayerItem: PlayerItem { }
