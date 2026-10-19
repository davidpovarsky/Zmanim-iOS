import SwiftUI

public struct WeatherDetailPopup: View {
    public let presentation: WeatherPresentation?
    @Binding public var isPresented: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let cardShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    public init(presentation: WeatherPresentation?, isPresented: Binding<Bool>) {
        self.presentation = presentation
        self._isPresented = isPresented
    }

    private var stackLayout: AnyLayout {
        verticalSizeClass == .compact
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            : AnyLayout(VStackLayout(spacing: 16))
    }

    public var body: some View {
        ZStack {
            if let current = presentation, isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        dismiss()
                    }
                    .accessibilityHidden(true)

                stackLayout {
                    cardContent(for: current)
                    closeButton
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) {
                    dismiss()
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: isPresented)
    }

    private func cardContent(for current: WeatherPresentation) -> some View {
        VStack(spacing: 0) {
            headerRow(for: current.header)
                .padding(18)

            Divider()

            WeatherHourlyStrip(entries: current.hourly)
                .padding(.vertical, 14)

            Divider()

            WeatherStatsRow(stats: current.stats)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            Text(current.attribution)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial, in: cardShape)
        .overlay(
            cardShape
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
    }

    private func headerRow(for header: WeatherPresentation.Header) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: METSymbolMapper.systemImageName(for: header.iconName))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 44))
                .foregroundStyle(Color.zmanOrange)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(header.regionName)
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(header.conditionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let rainText = header.chanceOfRainText {
                    Text(rainText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(header.currentTemp)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                if let hilo = header.highLowText {
                    Text(hilo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("סגור כרטיס מזג אוויר")
    }

    private func dismiss() {
        isPresented = false
    }
}
