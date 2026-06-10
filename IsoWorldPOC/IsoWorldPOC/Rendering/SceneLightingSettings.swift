//
//  SceneLightingSettings.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import simd

struct SceneLightingSettings {
    let sunDirection: SIMD3<Float>
    let sunIntensity: Float
    let ambientIntensity: Float
    let shadowsEnabled: Bool

    static let standard = SceneLightingSettings(
        sunDirection: simd_normalize(SIMD3<Float>(-0.45, -0.78, -0.32)),
        sunIntensity: 3_200,
        ambientIntensity: 450,
        shadowsEnabled: true
    )
}
