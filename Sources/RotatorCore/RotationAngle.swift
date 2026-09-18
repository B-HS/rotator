public enum RotationAngle: Int, CaseIterable, Sendable {
    case normal = 0
    case right = 90
    case upsideDown = 180
    case left = 270

    public var title: String {
        rawValue == 0 ? "0° (기본)" : "\(rawValue)°"
    }

    public static func nearest(to degrees: Double) -> RotationAngle {
        let normalized = (Int(degrees.rounded()) % 360 + 360) % 360
        return allCases.min {
            circularDistance($0.rawValue, normalized) < circularDistance($1.rawValue, normalized)
        } ?? .normal
    }

    private static func circularDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let difference = abs(lhs - rhs)
        return min(difference, 360 - difference)
    }
}
