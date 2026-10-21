//
//  OriginalFormatterDependencies.swift
//  OBAKitCore
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import OSLog

// MARK: - MeasurementFormatter

public extension MeasurementFormatter {
    /// Converts `temperature` in the specified `unit` to `locale` without displaying a resulting unit.
    ///
    /// For example, converts 32ºF -> "0º" for Celsius locale, or 0ºC -> "32º" for Fahrenheit locale.
    /// - Parameter temperature: The temperature
    /// - Parameter unit: The unit for `temperature`
    /// - Parameter locale: The target locale
    class func unitlessConversion(temperature: Double, unit: UnitTemperature, to locale: Locale) -> String {
        let temp = Measurement(value: temperature, unit: unit)
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.numberFormatter.maximumFractionDigits = 0

        var formattedTemp = formatter.string(from: temp)

        if formattedTemp.hasSuffix("C") || formattedTemp.hasSuffix("F") {
            formattedTemp.removeLast()
        }

        return formattedTemp
    }
}

// MARK: - Logger

public enum Logger {
    private static let logger = os.Logger(subsystem: "com.davidpovarsky.Zmanim", category: "weather")

    public static func warn(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

// MARK: - Strings

public enum Strings {
    public static var close: String {
        OBALoc("common.close", value: "Close", comment: "The verb 'to close'.")
    }
}
