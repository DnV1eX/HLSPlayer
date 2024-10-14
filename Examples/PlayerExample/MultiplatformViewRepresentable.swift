//
//  MultiplatformViewRepresentable.swift
//  PlayerExample
//
//  Created by Alexey Demin on 2024-10-10.
//

import SwiftUI

#if canImport(UIKit)
typealias ViewRepresentable = UIViewRepresentable

extension MultiplatformViewRepresentable where ViewType == UIViewType {
    
    func makeUIView(context: Context) -> UIViewType {
        makeView(context: context)
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        updateView(uiView, context: context)
    }
}
#else
typealias ViewRepresentable = NSViewRepresentable

extension MultiplatformViewRepresentable where ViewType == NSViewType {
    
    func makeNSView(context: Context) -> NSViewType {
        makeView(context: context)
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        updateView(nsView, context: context)
    }
}
#endif

protocol MultiplatformViewRepresentable: ViewRepresentable {
    associatedtype ViewType
    
    func makeView(context: Context) -> ViewType
    
    func updateView(_ view: ViewType, context: Context)
}
