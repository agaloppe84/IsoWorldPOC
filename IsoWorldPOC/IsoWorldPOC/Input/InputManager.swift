//
//  InputManager.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

final class InputManager {
    private let gamepadInput: GamepadInput
    private var keyboardInput = KeyboardInput()

    private(set) var state = PlayerInputState() {
        didSet {
            guard state != oldValue else {
                return
            }

            onStateChanged?(state)
        }
    }

    var onStateChanged: ((PlayerInputState) -> Void)?

    var controllerName: String {
        gamepadInput.controllerName
    }

    init(gamepadInput: GamepadInput = GamepadInput()) {
        self.gamepadInput = gamepadInput

        self.gamepadInput.onStateChanged = { [weak self] _ in
            self?.refreshState()
        }

        refreshState()
    }

    func keyDown(keyCode: UInt16) {
        keyboardInput.keyDown(keyCode: keyCode)
        refreshState()
    }

    func keyUp(keyCode: UInt16) {
        keyboardInput.keyUp(keyCode: keyCode)
        refreshState()
    }

    func resetKeyboard() {
        keyboardInput.reset()
        refreshState()
    }

    private func refreshState() {
        state = Self.combine(keyboardState: keyboardInput.state, gamepadState: gamepadInput.state)
    }

    private static func combine(
        keyboardState: PlayerInputState,
        gamepadState: PlayerInputState
    ) -> PlayerInputState {
        PlayerInputState(
            moveX: preferredAxis(gamepadState.moveX, fallback: keyboardState.moveX),
            moveY: preferredAxis(gamepadState.moveY, fallback: keyboardState.moveY),
            lookX: gamepadState.lookX,
            lookY: gamepadState.lookY,
            jumpPressed: keyboardState.jumpPressed || gamepadState.jumpPressed,
            primaryActionPressed: keyboardState.primaryActionPressed || gamepadState.primaryActionPressed,
            secondaryActionPressed: keyboardState.secondaryActionPressed || gamepadState.secondaryActionPressed,
            sprintPressed: keyboardState.sprintPressed || gamepadState.sprintPressed,
            isGamepadConnected: gamepadState.isGamepadConnected
        )
    }

    private static func preferredAxis(_ preferred: Float, fallback: Float) -> Float {
        preferred == 0 ? fallback : preferred
    }
}
