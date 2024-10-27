//
//  ControlsView.swift
//  PlayerExample
//
//  Created by Alexey Demin on 2024-10-11.
//

import SwiftUI

struct ControlsView: View {
    
    @Binding var playerModel: PlayerModel

    var body: some View {
        VStack {
            Slider(value: $playerModel.time, in: 0 ... playerModel.duration) {
            } minimumValueLabel: {
                Text(Duration.seconds(playerModel.time), format: .time(pattern: .hourMinuteSecond))
            } maximumValueLabel: {
                Text(Duration.seconds(playerModel.duration), format: .time(pattern: .hourMinuteSecond))
            } onEditingChanged: { isEditing in
                playerModel.isSeeking = isEditing
                if !isEditing {
                    playerModel.player.seek(to: playerModel.time)
                }
            }
            .monospacedDigit()
            .padding([.top, .horizontal])
            
            HStack {
                if playerModel.isPlaying {
                    Button {
                        playerModel.player.pause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .padding()
                            .contentShape(.rect)
                    }
                } else {
                    Button {
                        playerModel.player.play()
                    } label: {
                        Image(systemName: "play.fill")
                            .padding()
                            .contentShape(.rect)
                    }
                }
                Picker("Playback speed", selection: $playerModel.speed) {
                    Text("½x").tag(0.5)
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                    Text("10x").tag(10.0)
                }
                Picker("Playback bit rate", selection: $playerModel.preferredBitRate) {
                    Text("LD").tag(1_000_000)
                    Text("SD").tag(3_000_000)
                    Text("HD").tag(5_000_000)
                    Text("Auto").tag(0)
                }
                Text(playerModel.bitRateDescription)
                    .padding()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .imageScale(.large)
        }
    }
}

#Preview {
    ControlsView(playerModel: .constant(PlayerModel()))
}
