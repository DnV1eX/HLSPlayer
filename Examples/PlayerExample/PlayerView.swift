//
//  PlayerView.swift
//  PlayerExample
//
//  Created by Alexey Demin on 2024-10-10.
//

import SwiftUI

struct PlayerView: View {
    
    @Binding var model: PlayerModel
    
    var body: some View {
        VideoView(layer: model.player.layer)
            .overlay(alignment: .center) {
                if model.isBuffering {
                    ProgressView()
                        .blendMode(.difference)
                }
            }
            .overlay(alignment: .bottom) {
                ControlsView(playerModel: $model)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding()
            }
    }
}

#Preview {
    PlayerView(model: .constant(PlayerModel()))
}
