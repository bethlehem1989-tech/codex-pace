import SwiftUI

struct WidgetView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        QuotaSummaryView(store: store)
            .frame(minWidth: 324, minHeight: 312)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.08)))
            }
    }
}
