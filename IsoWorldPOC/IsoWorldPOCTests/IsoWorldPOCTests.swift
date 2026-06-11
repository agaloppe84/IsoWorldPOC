//
//  IsoWorldPOCTests.swift
//  IsoWorldPOCTests
//
//  Created by Work on 09/06/2026.
//

import Testing
@testable import IsoWorldPOC

struct IsoWorldPOCTests {

    @Test func slowInspectionUsesThrottledCadence() {
        let policy = DebugWorldRunMode.slowInspection.cadencePolicy

        #expect(policy.mode == .throttled(fps: 15))
        #expect(policy.maxFPS == 15)
        #expect(policy.renderOnlyWhenDirty == false)
        #expect(policy.allowContinuousAnimation == true)
    }

    @Test func pausedInspectionRendersOnlyWhenDirty() {
        let policy = DebugWorldRunMode.pausedInspection.cadencePolicy

        #expect(policy.mode == .onDemand)
        #expect(policy.renderOnlyWhenDirty == true)
        #expect(policy.allowContinuousAnimation == false)
    }

    @Test func liveGameplayIsTheOnlyNormalDisplayLinkedMode() {
        let policy = DebugWorldRunMode.liveGameplay.cadencePolicy

        #expect(policy.mode == .displayLinked)
        #expect(policy.maxFPS == 60)
        #expect(policy.renderOnlyWhenDirty == false)
        #expect(policy.allowContinuousAnimation == true)
    }

    @MainActor
    @Test func appStoreStartsInMainMenu() {
        let store = AppStore()

        #expect(store.mode == .mainMenu)
        #expect(store.loadingProgress == nil)
        #expect(store.currentWorldSession == nil)
    }

    @MainActor
    @Test func debugWorldTransitionDoesNotStartLoading() {
        let store = AppStore()

        store.openDebugWorld()

        if case .debugWorld = store.mode {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected debug world mode")
        }

        #expect(store.loadingProgress == nil)
        #expect(store.currentWorldSession == nil)
    }

    @MainActor
    @Test func toolsHubTransitionDoesNotCreateWorldSession() {
        let store = AppStore()

        store.openToolsHub()

        if case .toolsHub = store.mode {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected tools hub mode")
        }

        #expect(store.loadingProgress == nil)
        #expect(store.currentWorldSession == nil)
    }

    @MainActor
    @Test func prepareWorldNormalizesEmptySeedAndStartsLoading() {
        let store = AppStore(seedInput: "   ")

        store.prepareWorldFromSeed()

        if case .preparingWorld = store.mode {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected preparing world mode")
        }

        #expect(store.loadingProgress?.seed == "isoworld-seed-001")
        #expect(store.currentWorldSession == nil)
    }

}
