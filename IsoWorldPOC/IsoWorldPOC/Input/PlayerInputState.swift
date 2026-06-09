//
//  PlayerInputState.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

struct PlayerInputState: Equatable {
    var moveX: Float
    var moveY: Float
    var lookX: Float
    var lookY: Float
    var jumpPressed: Bool
    var primaryActionPressed: Bool
    var secondaryActionPressed: Bool
    var sprintPressed: Bool
    var isGamepadConnected: Bool

    init(
        moveX: Float = 0,
        moveY: Float = 0,
        lookX: Float = 0,
        lookY: Float = 0,
        jumpPressed: Bool = false,
        primaryActionPressed: Bool = false,
        secondaryActionPressed: Bool = false,
        sprintPressed: Bool = false,
        isGamepadConnected: Bool = false
    ) {
        self.moveX = moveX
        self.moveY = moveY
        self.lookX = lookX
        self.lookY = lookY
        self.jumpPressed = jumpPressed
        self.primaryActionPressed = primaryActionPressed
        self.secondaryActionPressed = secondaryActionPressed
        self.sprintPressed = sprintPressed
        self.isGamepadConnected = isGamepadConnected
    }
}

