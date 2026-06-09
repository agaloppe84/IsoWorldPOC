//
//  KeyboardInput.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

struct KeyboardInput {
    enum Key: Hashable {
        case w
        case a
        case s
        case d
        case z
        case q
        case space
        case leftShift
        case rightShift
    }

    private var pressedKeys: Set<Key> = []

    var state: PlayerInputState {
        PlayerInputState(
            moveX: movementAxis(positive: .d, negative: [.a, .q]),
            moveY: movementAxis(positive: [.w, .z], negative: .s),
            jumpPressed: pressedKeys.contains(.space),
            primaryActionPressed: pressedKeys.contains(.space),
            sprintPressed: pressedKeys.contains(.leftShift) || pressedKeys.contains(.rightShift)
        )
    }

    mutating func keyDown(keyCode: UInt16) {
        setKey(for: keyCode, isPressed: true)
    }

    mutating func keyUp(keyCode: UInt16) {
        setKey(for: keyCode, isPressed: false)
    }

    mutating func reset() {
        pressedKeys.removeAll()
    }

    private mutating func setKey(for keyCode: UInt16, isPressed: Bool) {
        guard let key = Self.key(for: keyCode) else {
            return
        }

        if isPressed {
            pressedKeys.insert(key)
        } else {
            pressedKeys.remove(key)
        }
    }

    private func movementAxis(positive: Key, negative: Key) -> Float {
        movementAxis(positive: [positive], negative: [negative])
    }

    private func movementAxis(positive: [Key], negative: Key) -> Float {
        movementAxis(positive: positive, negative: [negative])
    }

    private func movementAxis(positive: Key, negative: [Key]) -> Float {
        movementAxis(positive: [positive], negative: negative)
    }

    private func movementAxis(positive: [Key], negative: [Key]) -> Float {
        let positivePressed = positive.contains { pressedKeys.contains($0) }
        let negativePressed = negative.contains { pressedKeys.contains($0) }

        switch (positivePressed, negativePressed) {
        case (true, false):
            return 1
        case (false, true):
            return -1
        default:
            return 0
        }
    }

    private static func key(for keyCode: UInt16) -> Key? {
        switch keyCode {
        case 13:
            return .w
        case 0:
            return .a
        case 1:
            return .s
        case 2:
            return .d
        case 6:
            return .z
        case 12:
            return .q
        case 49:
            return .space
        case 56:
            return .leftShift
        case 60:
            return .rightShift
        default:
            return nil
        }
    }
}

