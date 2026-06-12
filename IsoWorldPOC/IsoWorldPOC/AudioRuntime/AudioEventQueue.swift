//
//  AudioEventQueue.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore

struct AudioEventQueueSnapshot: Equatable {
    static let empty = AudioEventQueueSnapshot(
        pendingEventCount: 0,
        drainedEventCount: 0,
        droppedEventCount: 0
    )

    let pendingEventCount: Int
    let drainedEventCount: Int
    let droppedEventCount: Int
}

final class AudioEventQueue {
    let capacity: Int

    private var events: [IsoAudioEvent] = []
    private(set) var droppedEventCount = 0
    private(set) var drainedEventCount = 0

    init(capacity: Int = 128) {
        self.capacity = max(capacity, 1)
    }

    var pendingEventCount: Int {
        events.count
    }

    func enqueue(_ event: IsoAudioEvent) {
        if events.count < capacity {
            events.append(event)
            sortEvents()
            return
        }

        guard let lowestPriorityEvent = events.last, shouldSort(event, before: lowestPriorityEvent) else {
            droppedEventCount += 1
            return
        }

        events[events.count - 1] = event
        droppedEventCount += 1
        sortEvents()
    }

    private func sortEvents() {
        events.sort(by: shouldSort)
    }

    private func shouldSort(_ lhs: IsoAudioEvent, before rhs: IsoAudioEvent) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }

        if lhs.time != rhs.time {
            return lhs.time < rhs.time
        }

        return lhs.id.rawValue < rhs.id.rawValue
    }

    func enqueue(contentsOf newEvents: [IsoAudioEvent]) {
        for event in newEvents {
            enqueue(event)
        }
    }

    func drain(maxCount: Int? = nil) -> [IsoAudioEvent] {
        let count = min(maxCount ?? events.count, events.count)
        let drained = Array(events.prefix(count))

        events.removeFirst(count)
        drainedEventCount += drained.count

        return drained
    }

    func snapshot() -> AudioEventQueueSnapshot {
        AudioEventQueueSnapshot(
            pendingEventCount: pendingEventCount,
            drainedEventCount: drainedEventCount,
            droppedEventCount: droppedEventCount
        )
    }
}
