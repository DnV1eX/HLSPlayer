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
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .imageScale(.large)
    }
}

#Preview {
    ControlsView(playerModel: .constant(PlayerModel()))
}
