import Foundation

/// A linear quota budget, never an estimate of token counts or credit spend.
struct UsagePace: Equatable {
    let usedPercent: Double
    let expectedNowPercent: Double
    let targetTonightPercent: Double
    let targetDate: Date
    let resetsAt: Date
    let secondsRemaining: TimeInterval

    init?(limit: UsageLimit, now: Date, timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai")!) {
        guard limit.isAvailable,
              let minutes = limit.windowMinutes, minutes.isFinite, minutes > 0,
              let reset = limit.resetsAt else { return nil }
        let duration = minutes * 60
        let start = reset.addingTimeInterval(-duration)
        guard now >= start, now < reset else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let day = calendar.dateInterval(of: .day, for: now) else { return nil }
        let target = min(day.end, reset)
        usedPercent = 100 - limit.clampedLeftPercent
        expectedNowPercent = min(max(now.timeIntervalSince(start) / duration * 100, 0), 100)
        targetTonightPercent = min(max(target.timeIntervalSince(start) / duration * 100, 0), 100)
        targetDate = target
        resetsAt = reset
        secondsRemaining = reset.timeIntervalSince(now)
    }

    var gapToTonight: Double { targetTonightPercent - usedPercent }
    var deviationNow: Double { usedPercent - expectedNowPercent }
    var targetIsReset: Bool { targetDate == resetsAt }

    var advice: String {
        if gapToTonight > 0.5 {
            return "距今日目标还差 \(Self.number(gapToTonight)) 个百分点"
        }
        if gapToTonight < -0.5 {
            return "已超过今日目标 \(Self.number(-gapToTonight)) 个百分点，今天可放慢"
        }
        return "已达到今日参考目标"
    }

    var paceDescription: String {
        if deviationNow > 0.5 { return "比匀速快 \(Self.number(deviationNow)) 个百分点" }
        if deviationNow < -0.5 { return "比匀速慢 \(Self.number(-deviationNow)) 个百分点" }
        return "与匀速进度一致"
    }

    var countdown: String {
        let minutes = max(1, Int(ceil(secondsRemaining / 60)))
        let days = minutes / 1440
        let hours = (minutes % 1440) / 60
        if days > 0 { return "\(days) 天 \(hours) 小时后重置" }
        if hours > 0 { return "\(hours) 小时 \(minutes % 60) 分后重置" }
        return "\(minutes) 分钟后重置"
    }

    static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
