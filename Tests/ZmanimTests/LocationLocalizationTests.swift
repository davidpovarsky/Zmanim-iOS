import XCTest
@testable import Zmanim

final class LocationLocalizationTests: XCTestCase {

    func testMandatoryLocationKeysExistInBothHebrewAndEnglish() throws {
        let bundle = Bundle.moduleBundleOrMain

        guard let hePath = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "he") ??
                Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "he.lproj"),
              let enPath = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en") ??
                Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "en.lproj") else {
            // Alternatively test from relative bundle paths
            return
        }

        let heDict = NSDictionary(contentsOfFile: hePath) as? [String: String] ?? [:]
        let enDict = NSDictionary(contentsOfFile: enPath) as? [String: String] ?? [:]

        let mandatoryKeys = [
            "location.locating",
            "location.updating",
            "location.unavailable",
            "location.permission_required",
            "location.services_disabled",
            "location.geocode_failed",
            "location.current",
            "location.default",
            "location.add_city",
            "location.saved_cities",
            "location.set_default",
            "location.remove_city",
            "location.city_removed_widget",
            "widget.location_option.app_default",
            "widget.location_option.current",
            "widget.location_option.saved_city",
            "widget.location_label",
            "widget.page.next",
            "widget.page.previous",
            "widget.day.tomorrow"
        ]

        for key in mandatoryKeys {
            XCTAssertNotNil(heDict[key], "Missing key '\(key)' in he.lproj/Localizable.strings")
            XCTAssertNotNil(enDict[key], "Missing key '\(key)' in en.lproj/Localizable.strings")

            // Ensure English translations do not contain Hebrew characters
            if let enValue = enDict[key] {
                let hebrewCharSet = CharacterSet(charactersIn: "\u{0590}"..."\u{05FF}")
                XCTAssertNil(enValue.rangeOfCharacter(from: hebrewCharSet), "English string for key '\(key)' contains Hebrew characters: \(enValue)")
            }
        }
    }
}

private extension Bundle {
    static var moduleBundleOrMain: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: LocationLocalizationTests.self)
        #endif
    }
}
