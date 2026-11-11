//
//  CoreLocalization.swift
//  OBAKitCore
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation

internal func OBALoc(_ key: String, value: String, comment: String, language: String? = nil) -> String {
    let bundle = Bundle.module
    let targetLanguage = language ?? activeCoreLanguage(for: bundle)
    if let path = bundle.path(forResource: targetLanguage, ofType: "lproj"),
       let langBundle = Bundle(path: path) {
        return langBundle.localizedString(forKey: key, value: value, table: nil)
    }
    return bundle.localizedString(forKey: key, value: value, table: nil)
}

internal func activeCoreLanguage(for bundle: Bundle) -> String {
    let preferences: [String]
    if let appleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String], !appleLanguages.isEmpty {
        preferences = appleLanguages
    } else if !Bundle.main.preferredLocalizations.isEmpty {
        preferences = Bundle.main.preferredLocalizations
    } else {
        preferences = Locale.preferredLanguages
    }
    let matched = Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: preferences)
    return matched.first ?? bundle.developmentLocalization ?? "he"
}
