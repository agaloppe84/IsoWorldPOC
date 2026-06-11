//
//  RendererMode.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

enum RendererMode: String, Equatable {
    case metal

    static let activeMode: RendererMode = .metal

    var displayName: String {
        switch self {
        case .metal:
            "Metal"
        }
    }
}
