import SwiftUI

struct QuotaSummaryView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let limit = store.snapshot.weekly
            let pace = UsagePace(limit: limit, now: context.date)
            VStack(spacing: 10) {
                if let pace {
                    HStack {
                        Text("已用 \(UsagePace.number(pace.usedPercent))%")
                            .foregroundStyle(QuotaPaceColors.green)
                        Spacer(minLength: 8)
                        Text("应到 \(UsagePace.number(pace.expectedNowPercent))%")
                            .foregroundStyle(QuotaPaceColors.orange)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    QuotaPaceBar(usedPercent: pace.usedPercent, targetPercent: pace.expectedNowPercent)
                        .frame(height: 4)
                    if store.errorMessage != nil || context.date.timeIntervalSince(store.snapshot.updatedAt) > 300 {
                        Text("上次读数").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                } else {
                    Text("等待最新额度").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
