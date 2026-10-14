import SwiftUI

enum EdgeTabPresentationMode: Equatable {
    case collapsed
    case expanded
    case dragging
}

enum EdgeTabPresentation {
    static let collapsedSize = CGSize(width: 64, height: 16)
    static let expandedSize = CGSize(width: 180, height: 64)

    static func size(for mode: EdgeTabPresentationMode) -> CGSize {
        mode == .expanded ? expandedSize : collapsedSize
    }
}

@MainActor
final class EdgeTabPresentationState: ObservableObject {
    @Published var mode: EdgeTabPresentationMode = .collapsed
}

struct EdgeTabView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var presentation: EdgeTabPresentationState

    var body: some View {
        Group {
            if presentation.mode == .expanded {
                QuotaSummaryView(store: store)
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    collapsedSignal(now: context.date)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .background {
            if presentation.mode == .expanded {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
            } else {
                Capsule().fill(.regularMaterial)
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
            }
        }
    }

    private var size: CGSize { EdgeTabPresentation.size(for: presentation.mode) }

    private func collapsedSignal(now: Date) -> some View {
        let limit = store.snapshot.weekly
        let pace = UsagePace(limit: limit, now: now)
        let expired = limit.resetsAt.map { now >= $0 } ?? false
        let used = limit.isAvailable && !expired ? 100 - limit.clampedLeftPercent : nil
        return QuotaPaceBar(usedPercent: used, targetPercent: pace?.expectedNowPercent)
            .frame(height: 4)
            .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pace.map {
            "Codex 额度节奏，剩余 \(Int(limit.clampedLeftPercent.rounded()))%，已用 \(UsagePace.number($0.usedPercent))%，当前应到 \(UsagePace.number($0.expectedNowPercent))%，\($0.paceDescription)"
        } ?? "Codex 额度节奏，正在等待最新额度与目标")
    }
}

/// Both the small tab and the expanded card use cumulative used quota, left to right.
struct QuotaPaceBar: View {
    let usedPercent: Double?
    let targetPercent: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                    .frame(height: proxy.size.height)
                if let usedPercent {
                    Capsule()
                        .fill(QuotaPaceColors.green)
                        .frame(width: EdgeTabUsageBarLayout.fillWidth(for: usedPercent, in: proxy.size.width), height: proxy.size.height)
                }
                if let targetPercent {
                    RoundedRectangle(cornerRadius: 1).fill(QuotaPaceColors.orange)
                        .frame(width: 2, height: proxy.size.height + 4)
                        .offset(x: EdgeTabUsageBarLayout.markerOffset(for: targetPercent, in: proxy.size.width))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

enum QuotaPaceColors {
    static let green = Color(red: 7.0 / 255, green: 193.0 / 255, blue: 96.0 / 255)
    static let orange = Color(red: 1, green: 149.0 / 255, blue: 0)
}

enum EdgeTabUsageBarLayout {
    static func fillWidth(for usedPercent: Double, in width: CGFloat) -> CGFloat {
        guard usedPercent.isFinite, width > 0 else { return 0 }
        return width * min(max(usedPercent, 0), 100) / 100
    }

    static func markerOffset(for targetPercent: Double, in width: CGFloat) -> CGFloat {
        guard targetPercent.isFinite, width > 0 else { return 0 }
        return max(0, min(max(0, width - 2), width * min(max(targetPercent, 0), 100) / 100 - 1))
    }
}
