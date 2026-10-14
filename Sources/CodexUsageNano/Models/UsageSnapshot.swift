import Foundation

struct UsageSnapshot: Equatable, Sendable {
    let session: UsageLimit
    let weekly: UsageLimit
    let updatedAt: Date
    var creditBalance: Double? = nil

    static let placeholder = UsageSnapshot(
        session: UsageLimit(title: "Session", leftPercent: 0, resetText: "Refreshing", isAvailable: false),
        weekly: UsageLimit(title: "Weekly", leftPercent: 0, resetText: "Refreshing", isAvailable: false),
        updatedAt: Date()
    )
}

struct UsageLimit: Equatable, Sendable {
    let title: String
    let leftPercent: Double
    let resetText: String
    let detailText: String?
    let projectionText: String?
    let markerPercent: Double?
    let isAvailable: Bool
    let windowMinutes: Double?
    let resetsAt: Date?

    init(
        title: String,
        leftPercent: Double,
        resetText: String,
        detailText: String? = nil,
        projectionText: String? = nil,
        markerPercent: Double? = nil,
        isAvailable: Bool = true,
        windowMinutes: Double? = nil,
        resetsAt: Date? = nil
    ) {
        self.isAvailable = isAvailable
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
        self.title = title
        self.leftPercent = leftPercent
        self.resetText = resetText
        self.detailText = detailText
        self.projectionText = projectionText
        self.markerPercent = markerPercent
    }

    var clampedLeftPercent: Double {
        min(max(leftPercent, 0), 100)
    }

    var leftText: String {
        "\(Int(clampedLeftPercent.rounded()))% left"
    }

    var tone: UsageTone {
        if clampedLeftPercent <= 15 {
            return .critical
        }
        if clampedLeftPercent <= 30 {
            return .warning
        }
        return .healthy
    }
}

enum UsageTone: Equatable, Sendable {
    case healthy
    case warning
    case critical
}
