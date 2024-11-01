//
//  Player.swift
//  HLSPlayer
//
//  Created by Alexey Demin on 2024-10-09.
//

import QuartzCore

public protocol Player: AnyObject {
    
    typealias Action = PlayerAction
    associatedtype Item: PlayerItem
    associatedtype Layer: CALayer
    
    var layer: Layer { get }

    /// A default rate at which to begin playback.
    var defaultRate: Double { get set }
    
    /// The current playback rate.
    var rate: Double { get set }
    
    var isBuffering: Bool { get }
    
    /// Observer for changes in playback status such as buffering and rate.
    var onChangeStatus: (() -> Void)? { get set }
    
    var volume: Double { get set }
    
    var actionAtItemEnd: Action { get set }
    
    var itemDidPlayToEndTime: (() -> Void)? { get set }
    
    var currentItem: Item? { get }
    
    func setItem(url: URL?)
    
    var currentTime: TimeInterval { get }
    
    func seek(to: TimeInterval)

    func play()
    
    func pause()
}

public extension Player {
    
    var isPlaying: Bool {
        !rate.isZero
    }
    
    var isMuted: Bool {
        volume.isZero
    }
    func mute() {
        volume = 0
    }
    func unmute() {
        volume = 1
    }
}

public protocol PlayerItem: AnyObject {
        
    var preferredPeakBitRate: Double { get set }

    var presentationSize: CGSize { get }
    
    var duration: TimeInterval { get }
    
    var bitRate: Double { get }
}

public enum PlayerAction {
    case advance, pause, none
}

public enum Players {
    
    public static var `default`: any Player {
        Self.hlsPlayer
    }
    
    public static var avPlayer: any Player {
        AVPlayer()
    }
    
    public static var hlsPlayer: any Player {
        HLSPlayer()
    }
}
