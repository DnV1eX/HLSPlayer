//
//  VideoView.swift
//  PlayerExample
//
//  Created by Alexey Demin on 2024-10-11.
//

import QuartzCore

struct VideoView: MultiplatformViewRepresentable {
    
    let layer: CALayer

    func makeView(context: Context) -> MultiplatformView {
        let view = MultiplatformView()
        view.setLayer(layer)
        return view
    }
    
    func updateView(_ view: MultiplatformView, context: Context) { }
}
