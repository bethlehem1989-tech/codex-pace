import Foundation

@main struct PaceChecks {
    static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    static func near(_ actual: Double, _ expected: Double) { precondition(abs(actual - expected) < 0.0001, "\(actual) != \(expected)") }
    static func main() throws {
        let reset = date("2026-10-20T06:00:00Z")
        let limit = UsageLimit(title: "Weekly", leftPercent: 65, resetText: "", windowMinutes: 10080, resetsAt: reset)
        // A week starting Oct 13 at 14:00 China time; Oct 14 at 20:00 is 30h in.
        let mid = UsagePace(limit: limit, now: date("2026-10-14T12:00:00Z"))!
        near(mid.expectedNowPercent, 30.0 / 168 * 100)
        near(mid.targetTonightPercent, 34.0 / 168 * 100)
        near(mid.usedPercent, 35)
        precondition(mid.targetDate == date("2026-10-14T16:00:00Z"))
        precondition(mid.advice.contains("今天可放慢"))
        let slow = UsageLimit(title: "Weekly", leftPercent: 95, resetText: "", windowMinutes: 10080, resetsAt: reset)
        precondition(UsagePace(limit: slow, now: date("2026-10-14T12:00:00Z"))!.advice.contains("还差"))
        let start = UsagePace(limit: slow, now: reset.addingTimeInterval(-604800))!
        near(start.expectedNowPercent, 0)
        precondition(UsagePace(limit: slow, now: reset) == nil)
        precondition(UsagePace(limit: slow, now: reset.addingTimeInterval(1)) == nil)
        precondition(UsagePace(limit: slow, now: reset.addingTimeInterval(-604801)) == nil)
        let final = UsagePace(limit: slow, now: date("2026-10-20T05:00:00Z"))!
        near(final.targetTonightPercent, 100)
        precondition(final.targetIsReset)
        precondition(final.targetDate == reset)
        let unknown = UsageLimit(title: "Weekly", leftPercent: 20, resetText: "")
        precondition(UsagePace(limit: unknown, now: date("2026-10-14T12:00:00Z")) == nil)
        let unavailable = UsageLimit(title: "Weekly", leftPercent: 20, resetText: "", isAvailable: false, windowMinutes: 10080, resetsAt: reset)
        precondition(UsagePace(limit: unavailable, now: date("2026-10-14T12:00:00Z")) == nil)
        let midnight = UsagePace(limit: slow, now: date("2026-10-14T16:00:00Z"))!
        precondition(midnight.targetDate == date("2026-10-15T16:00:00Z"))
        let dstReset = date("2026-03-12T12:00:00Z")
        let dstLimit = UsageLimit(title: "Weekly", leftPercent: 50, resetText: "", windowMinutes: 10080, resetsAt: dstReset)
        let dst = UsagePace(limit: dstLimit, now: date("2026-03-08T05:00:00Z"), timeZone: TimeZone(identifier: "America/New_York")!)!
        precondition(dst.targetDate == date("2026-03-09T04:00:00Z"))
        let json = #"[{"provider":"codex","usage":{"primary":null,"secondary":{"usedPercent":34,"windowMinutes":10080,"resetsAt":"2026-10-20T06:00:00Z"},"providerCost":{"balance":62500}}}]"#
        let parsed = try CodexUsageTextParser.parseJSON(Data(json.utf8))
        precondition(!parsed.session.isAvailable && parsed.creditBalance == 62500)
        precondition(parsed.weekly.resetsAt == reset && parsed.weekly.windowMinutes == 10080)
        near(UsagePace(limit: parsed.weekly, now: date("2026-10-14T12:00:00Z"))!.usedPercent, 34)
        let missing = #"[{"provider":"codex","usage":{"secondary":{"windowMinutes":10080,"resetsAt":"2026-10-20T06:00:00Z"}}}]"#
        let m = try CodexUsageTextParser.parseJSON(Data(missing.utf8))
        precondition(!m.weekly.isAvailable)
        precondition(UsagePace(limit: m.weekly, now: date("2026-10-14T12:00:00Z")) == nil)
        if CommandLine.arguments.contains("--live") {
            let live = try CodexUsageService().fetch()
            let plan = UsagePace(limit: live.weekly, now: Date())
            precondition(live.weekly.isAvailable && plan != nil)
            print("LIVE remaining=\(live.weekly.clampedLeftPercent)% nowTarget=\(plan!.expectedNowPercent)% tonightTarget=\(plan!.targetTonightPercent)%")
        }
        print("PASS: quota parsing, weekly-only accounts, pacing, midnight, reset, missing data, and DST")
    }
}
