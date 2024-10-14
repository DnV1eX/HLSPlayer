//
//  ContentView.swift
//  PlayerExample
//
//  Created by Alexey Demin on 2024-10-10.
//

import SwiftUI

struct ContentView: View {
    
    @State var model = PlayerModel()
    
    var body: some View {
        NavigationSplitView {
            List(PlayerModel.Stream.allCases, selection: $model.stream) { stream in
                Text(stream.description)
            }
        } detail: {
            PlayerView(model: $model)
        }
    }
}

#Preview {
    ContentView()
}
