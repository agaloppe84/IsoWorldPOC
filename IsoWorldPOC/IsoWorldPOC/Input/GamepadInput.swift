//
//  GamepadInput.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import Foundation
import GameController

final class GamepadInput: NSObject {
    private var activeController: GCController?
    private var leftShoulderSprintPressed = false
    private var leftThumbstickSprintPressed = false

    private(set) var state = PlayerInputState() {
        didSet {
            guard state != oldValue else {
                return
            }

            onStateChanged?(state)
        }
    }

    var onStateChanged: ((PlayerInputState) -> Void)?

    override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        configureInitialController()
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        GCController.stopWirelessControllerDiscovery()
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }

        logConnectedController(controller)
        configure(controller: controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }

        if controller === activeController {
            clearHandlers(for: controller)
            activeController = nil
        }

        configureInitialController()
    }

    private func configureInitialController() {
        guard let controller = GCController.controllers().first else {
            leftShoulderSprintPressed = false
            leftThumbstickSprintPressed = false
            state = PlayerInputState(isGamepadConnected: false)
            return
        }

        logConnectedController(controller)
        configure(controller: controller)
    }

    private func configure(controller: GCController) {
        if let activeController {
            clearHandlers(for: activeController)
        }

        activeController = controller
        leftShoulderSprintPressed = false
        leftThumbstickSprintPressed = false
        state = PlayerInputState(isGamepadConnected: true)

        guard let gamepad = controller.extendedGamepad else {
            return
        }

        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.state.moveX = xValue
            self?.state.moveY = yValue
        }

        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.state.lookX = xValue
            self?.state.lookY = yValue
        }

        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, isPressed in
            self?.state.primaryActionPressed = isPressed
            self?.state.jumpPressed = isPressed
        }

        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, isPressed in
            self?.state.secondaryActionPressed = isPressed
        }

        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, isPressed in
            self?.leftShoulderSprintPressed = isPressed
            self?.updateSprintPressed()
        }

        gamepad.leftThumbstickButton?.pressedChangedHandler = { [weak self] _, _, isPressed in
            self?.leftThumbstickSprintPressed = isPressed
            self?.updateSprintPressed()
        }
    }

    private func clearHandlers(for controller: GCController) {
        guard let gamepad = controller.extendedGamepad else {
            return
        }

        gamepad.leftThumbstick.valueChangedHandler = nil
        gamepad.rightThumbstick.valueChangedHandler = nil
        gamepad.buttonA.pressedChangedHandler = nil
        gamepad.rightTrigger.pressedChangedHandler = nil
        gamepad.leftShoulder.pressedChangedHandler = nil
        gamepad.leftThumbstickButton?.pressedChangedHandler = nil
    }

    private func logConnectedController(_ controller: GCController) {
        let name = controller.vendorName ?? controller.productCategory
        print("Gamepad connected: \(name)")
    }

    private func updateSprintPressed() {
        state.sprintPressed = leftShoulderSprintPressed || leftThumbstickSprintPressed
    }
}
