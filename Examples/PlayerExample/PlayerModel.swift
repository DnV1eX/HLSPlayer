//
//  PlayerModel.swift
//  PlayerExample
//
//  Created by Alexey Demin on 2024-10-10.
//

import SwiftUI
import HLSPlayer

@Observable final class PlayerModel {
    
    let player = Players.default
    
    var stream: Stream? {
        didSet {
            player.setItem(url: stream?.url)
        }
    }
    
    var isPlaying = false
    var isBuffering = false
    var isSeeking = false

    var time: TimeInterval = 0
    var duration: TimeInterval = 0
    var speed: Double = 1 {
        didSet {
            player.defaultRate = speed
        }
    }
    var preferredBitRate: Int = 0 {
        didSet {
            player.currentItem?.preferredPeakBitRate = Double(preferredBitRate)
        }
    }
    var bitRate: Int = 0
    let bi = 1024
    var bitRateDescription: String {
        switch bitRate {
        case ..<bi: "\(bitRate) bps"
        case ..<(bi * bi): "\(bitRate / bi) Kbps"
        case ..<(bi * bi * bi): "\(bitRate / bi / bi) Mbps"
        default: "\(bitRate / bi / bi / bi) Gbps"
        }
    }
    
    init() {
        player.onChangeStatus = { [weak self, unowned player] in
            guard let self else { return }
            isPlaying = player.isPlaying
            isBuffering = player.isBuffering
            if !isSeeking {
                time = player.currentTime
            }
            duration = player.currentItem?.duration ?? 0
            bitRate = (player.currentItem?.bitRate).map(Int.init) ?? 0
        }
    }
}

extension PlayerModel {
    /// https://developer.apple.com/streaming/examples/
    enum Stream: String, Identifiable, CaseIterable, CustomStringConvertible {
        
        case basicStream1 = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8"
        case basicStream2 = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
        case advancedStreamTS = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
        case advancedStreamFMP4 = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
        case advancedStreamHEVC = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8"
        case advancedStreamDVAtmos = "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"
        case advancedStream3D = "https://devstreaming-cdn.apple.com/videos/streaming/examples/historic_planet_content_2023-10-26-3d-video/main.m3u8"
        
        var id: Self { self }

        var url: URL {
            URL(string: rawValue)!
        }
        
        var description: String {
            switch self {
            case .basicStream1: "Basic stream 4x3"
            case .basicStream2: "Basic stream 16x9"
            case .advancedStreamTS: "Advanced stream TS"
            case .advancedStreamFMP4: "Advanced stream fMP4"
            case .advancedStreamHEVC: "Advanced stream HEVC"
            case .advancedStreamDVAtmos: "Advanced stream Dolby"
            case .advancedStream3D: "3D movie stream"
            }
        }
    }
}
