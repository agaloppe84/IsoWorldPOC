//
//  RendererMode.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import Foundation

enum RendererMode: String, CaseIterable {
    case realityKit
    case metalExperimental

    static var defaultMode: RendererMode {
        #if DEBUG
        if let rawMode = UserDefaults.standard.string(forKey: "RendererMode"),
           let mode = RendererMode(rawValue: rawMode) {
            return mode
        }
        #endif

        return .realityKit
    }

    var displayName: String {
        switch self {
        case .realityKit:
            "RealityKit"
        case .metalExperimental:
            "MetalExperimental"
        }
    }
}
