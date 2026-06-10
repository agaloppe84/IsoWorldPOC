//
//  GameRenderer.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

@MainActor
protocol GameRenderer: AnyObject {
    func handleKeyDown(keyCode: UInt16)
    func handleKeyUp(keyCode: UInt16)
    func resetKeyboard()
    func update(deltaTime: Float)
}
