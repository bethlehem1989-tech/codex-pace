import SwiftUI

struct QuotaSummaryView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            summary(now: context.date)
        }
    }

    private func summary(now: Date) -> some View {
        let limit = store.snapshot.weekly
        let pace = UsagePace(limit: limit, now: now)
        let expired = limit.resetsAt.map { now >= $0 } ?? false
        let stale = now.timeIntervalSince(store.snapshot.updatedAt) > 300 || store.errorMessage != nil
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Codex Pace · 本周额度").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(expired ? "等待重置更新" : (stale ? "上次数据" : "每分钟更新"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(limit.isAvailable && !expired ? "\(Int(limit.clampedLeftPercent.rounded()))%" : "—")
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("剩余").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if limit.isAvailable && !expired {
                    Text("已用 \(UsagePace.number(100 - limit.clampedLeftPercent))%")
                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
            }

            if let pace {
                progress(pace)
                VStack(spacing: 7) {
                    valueRow("按当前时间应累计用到", value: "\(UsagePace.number(pace.expectedNowPercent))%")
                    valueRow(pace.targetIsReset ? "今天重置前累计目标" : "今晚 24:00 累计目标",
                             value: "\(UsagePace.number(pace.targetTonightPercent))%", emphasized: true)
                }
                Text(pace.advice)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(pace.gapToTonight < -0.5 ? Color.orange : Color.accentColor)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(pace.countdown)
                    Spacer()
                    Text(resetDateText(pace.resetsAt))
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text(expired ? "额度周期已结束，正在等待最新余额" : "等待完整的额度周期数据，暂不估算进度")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                if let credits = store.snapshot.creditBalance {
                    Text("Credits \(credits.formatted(.number.precision(.fractionLength(0...2))))")
                }
                Spacer()
                if store.snapshot.session.isAvailable {
                    Text("短期剩余 \(Int(store.snapshot.session.clampedLeftPercent.rounded()))%")
                }
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)
            Text(stale ? "刷新暂未成功，以上为上次读数" : "按周期匀速分配 · 中国时间 · 额度百分比")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    private func valueRow(_ label: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value).fontWeight(emphasized ? .semibold : .medium).monospacedDigit()
        }
        .font(.system(size: 12))
    }

    private func progress(_ pace: UsagePace) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            QuotaPaceBar(usedPercent: pace.usedPercent, targetPercent: pace.targetTonightPercent)
            .frame(height: 7)
            HStack {
                Text("蓝绿：累计已用")
                Spacer()
                Text("橙线：今日目标 \(UsagePace.number(pace.targetTonightPercent))%")
            }
            .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .accessibilityLabel("实际已用 \(UsagePace.number(pace.usedPercent))%，今日目标 \(UsagePace.number(pace.targetTonightPercent))%")
    }

    private func resetDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
