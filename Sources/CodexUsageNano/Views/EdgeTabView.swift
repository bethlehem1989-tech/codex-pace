import SwiftUI

enum EdgeTabPresentationMode: Equatable {
    case collapsed
    case expanded
    case dragging
}

enum EdgeTabPresentation {
    static let collapsedSize = CGSize(width: 128, height: 24)
    static let expandedSize = CGSize(width: 324, height: 312)

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
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.08)))
                    }
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    collapsedSignal(now: context.date)
                }
                .background {
                    LiquidGlassSurface(shape: Capsule(), tint: .cyan, intensity: .tabCollapsed)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var size: CGSize { EdgeTabPresentation.size(for: presentation.mode) }

    private func collapsedSignal(now: Date) -> some View {
        let limit = store.snapshot.weekly
        let pace = UsagePace(limit: limit, now: now)
        let expired = limit.resetsAt.map { now >= $0 } ?? false
        let used = limit.isAvailable && !expired ? 100 - limit.clampedLeftPercent : nil
        return HStack(spacing: 6) {
            QuotaPaceBar(usedPercent: used, targetPercent: pace?.targetTonightPercent)
                .frame(height: 6)
            Text(pace.map { "今\(UsagePace.number($0.targetTonightPercent))%" } ?? "目标—")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit().fixedSize()
                .foregroundStyle(pace == nil ? Color.secondary : Color.orange)
        }
        .padding(.horizontal, 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pace.map {
            "Codex 额度节奏，剩余 \(Int(limit.clampedLeftPercent.rounded()))%，已用 \(UsagePace.number($0.usedPercent))%，今日累计目标 \(UsagePace.number($0.targetTonightPercent))%，\($0.advice)"
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
                Capsule().fill(Color.primary.opacity(0.15))
                if let usedPercent {
                    Capsule()
                        .fill(Color(red: 0.05, green: 0.61, blue: 0.76))
                        .frame(width: EdgeTabUsageBarLayout.fillWidth(for: usedPercent, in: proxy.size.width))
                }
                if let targetPercent {
                    RoundedRectangle(cornerRadius: 1).fill(Color.orange)
                        .frame(width: 2, height: 12)
                        .offset(x: EdgeTabUsageBarLayout.markerOffset(for: targetPercent, in: proxy.size.width))
                }
            }
        }
    }
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
