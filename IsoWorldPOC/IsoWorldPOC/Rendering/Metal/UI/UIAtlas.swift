//
//  UIAtlas.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore

enum UIAtlasIcon: String, Hashable {
    case health
    case stamina
    case weather
    case biome
}

enum UIAtlas {
    static func iconCommands(
        _ icon: UIAtlasIcon,
        originX: Float,
        originY: Float,
        size: Float,
        color: UIStyleColor,
        layer: Int
    ) -> [UIDrawCommand] {
        let unit = max(size / 5, 1)

        return pattern(for: icon).enumerated().flatMap { rowIndex, row -> [UIDrawCommand] in
            row.enumerated().compactMap { columnIndex, cell in
                guard cell == "1" else {
                    return nil
                }

                return UIDrawCommand(
                    kind: .icon,
                    rect: UIFrameRect(
                        x: originX + Float(columnIndex) * unit,
                        y: originY + Float(rowIndex) * unit,
                        width: unit,
                        height: unit
                    ),
                    color: color,
                    layer: layer,
                    materialOrder: 3
                )
            }
        }
    }

    private static func pattern(for icon: UIAtlasIcon) -> [String] {
        switch icon {
        case .health:
            [
                "01010",
                "11111",
                "11111",
                "01110",
                "00100",
            ]
        case .stamina:
            [
                "00110",
                "01100",
                "11110",
                "00110",
                "01100",
            ]
        case .weather:
            [
                "01110",
                "11111",
                "01110",
                "00100",
                "01010",
            ]
        case .biome:
            [
                "00100",
                "01110",
                "11111",
                "00100",
                "00100",
            ]
        }
    }
}
