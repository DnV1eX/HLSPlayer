//
//  MultiplatformView.swift
//  PlayerExample
//
//  Created by Alexey Demin on 2024-10-11.
//

#if canImport(UIKit)
import UIKit

typealias MultiplatformView = LayerView

final class LayerView: UIView {
    override func layoutSublayers(of layer: CALayer) {
        if layer == self.layer {
            layer.sublayers?.first?.frame = bounds
        }
        super.layoutSublayers(of: layer)
    }
}

extension MultiplatformView {
    func setLayer(_ layer: CALayer) {
        layer.frame = bounds
        self.layer.addSublayer(layer)
    }
}
#else
import AppKit

typealias MultiplatformView = NSView

extension MultiplatformView {
    func setLayer(_ layer: CALayer) {
        self.layer = layer
    }
}
#endif
