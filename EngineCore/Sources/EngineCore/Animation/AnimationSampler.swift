import Foundation

public struct AnimationSample: Equatable, Hashable, Codable, Sendable {
    public let clipID: AnimationClipID
    public let normalizedTime: Float
    public let pose: Pose
    public let footPlantWeights: AnimationFootPlantWeights
    public let rootMotionMeters: Float

    public init(
        clipID: AnimationClipID,
        normalizedTime: Float,
        pose: Pose,
        footPlantWeights: AnimationFootPlantWeights,
        rootMotionMeters: Float
    ) {
        self.clipID = clipID
        self.normalizedTime = min(max(normalizedTime, 0), 1)
        self.pose = pose
        self.footPlantWeights = footPlantWeights
        self.rootMotionMeters = max(rootMotionMeters, 0)
    }
}

public struct AnimationSampler: Sendable {
    public init() {}

    public func sample(
        clip: AnimationClip,
        time: Float,
        looping: Bool = true
    ) -> AnimationSample {
        let normalizedTime = normalizedTime(for: time, duration: clip.duration, looping: looping)
        let clipTime = normalizedTime * clip.duration
        let framePair = surroundingKeyframes(in: clip, at: clipTime)
        let amount = blendAmount(from: framePair.previous.time, to: framePair.next.time, at: clipTime)
        let pose = Pose.blended(framePair.previous.pose, framePair.next.pose, amount: amount)

        return AnimationSample(
            clipID: clip.id,
            normalizedTime: normalizedTime,
            pose: pose,
            footPlantWeights: AnimationFootPlantWeights(
                left: clip.contactWeight(side: .left, normalizedTime: normalizedTime),
                right: clip.contactWeight(side: .right, normalizedTime: normalizedTime)
            ),
            rootMotionMeters: clip.rootMotionMetersPerCycle * normalizedTime
        )
    }

    public func blend(_ first: AnimationSample, _ second: AnimationSample, amount: Float) -> AnimationSample {
        let amount = min(max(amount, 0), 1)

        return AnimationSample(
            clipID: amount < 0.5 ? first.clipID : second.clipID,
            normalizedTime: first.normalizedTime + (second.normalizedTime - first.normalizedTime) * amount,
            pose: Pose.blended(first.pose, second.pose, amount: amount),
            footPlantWeights: AnimationFootPlantWeights(
                left: first.footPlantWeights.left + (second.footPlantWeights.left - first.footPlantWeights.left) * amount,
                right: first.footPlantWeights.right + (second.footPlantWeights.right - first.footPlantWeights.right) * amount
            ),
            rootMotionMeters: first.rootMotionMeters + (second.rootMotionMeters - first.rootMotionMeters) * amount
        )
    }

    private func normalizedTime(for time: Float, duration: Float, looping: Bool) -> Float {
        guard duration > 0 else {
            return 0
        }

        let raw = time / duration

        if looping {
            let wrapped = raw - floor(raw)
            return wrapped < 0 ? wrapped + 1 : wrapped
        }

        return min(max(raw, 0), 1)
    }

    private func surroundingKeyframes(
        in clip: AnimationClip,
        at time: Float
    ) -> (previous: AnimationKeyframe, next: AnimationKeyframe) {
        guard clip.keyframes.count > 1 else {
            return (clip.keyframes[0], clip.keyframes[0])
        }

        var previous = clip.keyframes[0]

        for next in clip.keyframes.dropFirst() {
            if time <= next.time {
                return (previous, next)
            }

            previous = next
        }

        return (previous, previous)
    }

    private func blendAmount(from start: Float, to end: Float, at time: Float) -> Float {
        guard end > start else {
            return 0
        }

        return min(max((time - start) / (end - start), 0), 1)
    }
}
