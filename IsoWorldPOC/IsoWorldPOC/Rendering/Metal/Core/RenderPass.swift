//
//  RenderPass.swift
//  IsoWorldPOC
//
//  Created by Work on 11/06/2026.
//

import Foundation

enum RenderPassKind: String, CaseIterable, Hashable {
    case depthPrepass
    case opaque
    case debugOverlay
    case hudOverlay
}

struct RenderResourceID: Hashable, ExpressibleByStringLiteral {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }
}

extension RenderResourceID {
    static let backbuffer: RenderResourceID = "backbuffer"
    static let depth: RenderResourceID = "depth"
    static let worldGeometry: RenderResourceID = "worldGeometry"
    static let debugGeometry: RenderResourceID = "debugGeometry"
    static let hudGeometry: RenderResourceID = "hudGeometry"
}

struct RenderPassDescriptor: Hashable, Identifiable {
    let kind: RenderPassKind
    let name: String
    let reads: [RenderResourceID]
    let writes: [RenderResourceID]
    let isOptional: Bool

    var id: RenderPassKind {
        kind
    }
}

protocol RenderPass {
    var descriptor: RenderPassDescriptor { get }
}
