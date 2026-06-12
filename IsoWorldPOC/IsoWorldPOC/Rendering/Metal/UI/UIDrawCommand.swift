//
//  UIDrawCommand.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore

enum UIDrawCommandKind: Int, Hashable {
    case panel
    case fill
    case outline
    case glyph
    case icon
}

struct UIDrawCommand: Hashable {
    let kind: UIDrawCommandKind
    let rect: UIFrameRect
    let color: UIStyleColor
    let layer: Int
    let cornerRadius: Float
    let sortKey: UInt64

    init(
        kind: UIDrawCommandKind,
        rect: UIFrameRect,
        color: UIStyleColor,
        layer: Int,
        cornerRadius: Float = 0,
        materialOrder: Int = 0
    ) {
        self.kind = kind
        self.rect = rect
        self.color = color
        self.layer = layer
        self.cornerRadius = max(cornerRadius, 0)
        self.sortKey = Self.makeSortKey(layer: layer, kind: kind, materialOrder: materialOrder)
    }

    private static func makeSortKey(
        layer: Int,
        kind: UIDrawCommandKind,
        materialOrder: Int
    ) -> UInt64 {
        UInt64(max(layer, 0)) << 48 |
            UInt64(max(materialOrder, 0)) << 24 |
            UInt64(kind.rawValue)
    }
}

enum UIDrawCommandBatcher {
    static func sorted(_ commands: [UIDrawCommand]) -> [UIDrawCommand] {
        commands.sorted { lhs, rhs in
            if lhs.sortKey != rhs.sortKey {
                return lhs.sortKey < rhs.sortKey
            }

            if lhs.rect.y != rhs.rect.y {
                return lhs.rect.y < rhs.rect.y
            }

            return lhs.rect.x < rhs.rect.x
        }
    }
}
