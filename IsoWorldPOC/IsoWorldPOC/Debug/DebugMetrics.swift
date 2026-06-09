//
//  DebugMetrics.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import Combine
import simd

@MainActor
final class DebugMetrics: ObservableObject {
    @Published var inputState = PlayerInputState()
    @Published var controllerName = "None"
    @Published var playerPosition = SIMD3<Float>(0, 0, 0)
}
