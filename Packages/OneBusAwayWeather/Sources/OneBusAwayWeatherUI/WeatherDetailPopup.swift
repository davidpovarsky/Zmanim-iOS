//
//  WeatherDetailPopup.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import SwiftUI
import OneBusAwayWeatherCore

/// In-SwiftUI weather card for overlay presentations.
/// Adapts responsively to actual container width and available height.
/// Interactive body (the hourly strip scrolls horizontally) and dismisses
/// via background tap or the prominent close button.
public struct WeatherDetailPopup: View {
    public let display: WeatherDisplay?
    @Binding public var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(display: WeatherDisplay?, isPresented: Binding<Bool>) {
        self.display = display
        self._isPresented = isPresented
    }

    private let cardShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    private var isShowing: Bool { isPresented && display != nil }

    public var body: some View {
        ZStack {
            if let current = display, isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismiss() }
                    .accessibilityHidden(true)

                GeometryReader { proxy in
                    let containerWidth = proxy.size.width
                    let containerHeight = proxy.size.height
                    let isCompactHeight = containerHeight < 550
                    let cardWidth = min(500, max(280, containerWidth - 32))
                    let maxCardHeight = max(260, containerHeight - 64)

                    ZStack {
                        if isCompactHeight {
                            HStack(alignment: .center, spacing: 16) {
                                WeatherCard(display: current, shape: cardShape, maxHeight: maxCardHeight)
                                    .frame(width: min(cardWidth, containerWidth - 80))
                                closeButton
                            }
                        } else {
                            VStack(spacing: 16) {
                                WeatherCard(display: current, shape: cardShape, maxHeight: maxCardHeight)
                                    .frame(width: cardWidth)
                                closeButton
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.94).combined(with: .opacity)
                )
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { dismiss() }
            }
        }
        .animation(.smooth(duration: 0.25), value: isShowing)
        .onChange(of: display) { _, newValue in
            if newValue == nil && isPresented {
                isPresented = false
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
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Strings.close))
        .background(.ultraThinMaterial, in: Circle())
        .clearGlassEffectIfAvailable(in: Circle())
    }

    private func dismiss() {
        isPresented = false
    }
}

// MARK: - Card

private struct WeatherCard: View {
    let display: WeatherDisplay
    let shape: RoundedRectangle
    var maxHeight: CGFloat = 520

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                HeaderRow(header: display.header)
                    .padding(16)

                Divider()

                HourlyStrip(entries: display.hourly)
                    .padding(.vertical, 12)

                Divider()

                StatsRow(stats: display.stats)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                if let attribution = display.sourceAttribution {
                    Text(attribution)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
        .frame(maxHeight: maxHeight)
        .background(.ultraThinMaterial, in: shape)
        .clearGlassEffectIfAvailable(in: shape)
    }
}

// MARK: - Header

private struct HeaderRow: View {
    let header: WeatherDisplay.Header

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WeatherIcon(iconName: header.iconName, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(header.regionName)
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                    .lineLimit(1)
                Text(header.conditionSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(header.chanceOfRainText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(header.currentTemp)
                    .font(.system(size: 34, weight: .semibold))
                    .layoutPriority(1)
                if let hilo = header.highLowText {
                    Text(hilo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .layoutPriority(1)
                }
            }
        }
    }
}

// MARK: - Hourly Strip

private struct HourlyStrip: View {
    let entries: [HourlyEntry]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 18) {
                ForEach(entries) { entry in
                    HourlyCell(entry: entry)
                }
            }
            .padding(.horizontal, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HourlyCell: View {
    let entry: HourlyEntry

    var body: some View {
        VStack(spacing: 6) {
            Text(entry.timeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)

            WeatherIcon(iconName: entry.iconName, size: 24)

            Text(entry.tempLabel)
                .font(.subheadline.weight(.medium))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stats Row

private struct StatsRow: View {
    let stats: WeatherDisplay.Stats

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatSlot(
                title: Strings.feelsLike,
                value: stats.feelsLikeTemp,
                iconName: "thermometer.medium"
            )

            Divider()

            StatSlot(
                title: Strings.humidity,
                value: stats.humidityPercent,
                iconName: "humidity.fill"
            )

            Divider()

            StatSlot(
                title: Strings.wind,
                value: stats.windSpeed,
                iconName: "wind"
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatSlot: View {
    let title: String
    let value: String
    let iconName: String

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct WeatherIcon: View {
    let iconName: String
    let size: CGFloat

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size))
            .frame(width: size, height: size)
    }
}

private enum Strings {
    static var close: String {
        OBALoc.string("close", value: "סגור", comment: "Close button")
    }
    static var feelsLike: String {
        OBALoc.string("weather.feels_like", value: "מרגיש כמו", comment: "Feels like")
    }
    static var humidity: String {
        OBALoc.string("weather.humidity", value: "לחות", comment: "Humidity")
    }
    static var wind: String {
        OBALoc.string("weather.wind", value: "רוח", comment: "Wind")
    }
}
