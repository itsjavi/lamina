import Foundation

package enum LevelsChannel: String, CaseIterable, Sendable, Codable {
    case rgb = "RGB", red = "Red", green = "Green", blue = "Blue"
    package var index: Int { Self.allCases.firstIndex(of: self)! }
}
package struct LevelRange: Equatable, Sendable, Codable {
    package var black: Double = 0
    package var gamma: Double = 1
    package var white: Double = 255
    package var outputBlack: Double = 0
    package var outputWhite: Double = 255

    package init(black: Double = 0, gamma: Double = 1, white: Double = 255, outputBlack: Double = 0,
                 outputWhite: Double = 255) {
        self.black = black
        self.gamma = gamma
        self.white = white
        self.outputBlack = outputBlack
        self.outputWhite = outputWhite
    }

    package var normalized: Self {
        func clamp(_ n: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            n.isFinite ? min(range.upperBound, max(range.lowerBound, n)) : fallback
        }
        var result = self
        result.black = clamp(black, 0...254, 0)
        result.white = clamp(white, (result.black + 1)...255, 255)
        result.gamma = clamp(gamma, 0.1...9.99, 1)
        result.outputBlack = clamp(outputBlack, 0...255, 0)
        result.outputWhite = clamp(outputWhite, 0...255, 255)
        return result
    }
    package func apply(_ value: Double) -> Double {
        let s = normalized
        let input = min(1, max(0, (value * 255 - s.black) / (s.white - s.black)))
        return (s.outputBlack + pow(input, 1 / s.gamma) * (s.outputWhite - s.outputBlack)) / 255
    }
}
package struct LevelsSettings: Equatable, Sendable, Codable {
    package var channel: LevelsChannel = .rgb
    package var ranges = Array(repeating: LevelRange(), count: 4)

    package init(channel: LevelsChannel = .rgb, ranges: [LevelRange] = Array(repeating: LevelRange(), count: 4)) {
        self.channel = channel
        self.ranges = ranges
    }

    package var current: LevelRange {
        get { ranges[channel.index] }
        set { ranges[channel.index] = newValue.normalized }
    }
    package var isIdentity: Bool { ranges.allSatisfy { $0.normalized == LevelRange() } }
    /// Individual channels, followed by the composite RGB adjustment.
    package func apply(_ value: Double, channel: LevelsChannel) -> Double {
        ranges[0].apply(ranges[channel.index].apply(value))
    }
}
