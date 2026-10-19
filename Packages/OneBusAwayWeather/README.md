# OneBusAwayWeather

Local Swift package porting the original, authoritative weather UI, display models, and formatting from **OneBusAway Israel** (`onebusaway-ios`) into Zmanim iOS.

## Source Provenance & Baseline Manifest

- **Reference Repository:** [davidpovarsky/onebusaway-ios](https://github.com/davidpovarsky/onebusaway-ios)
- **Reference Branch:** `fix/israel-runtime-region-search-weather`
- **Pinned Reference Commit SHA:** `6b8d381979da52b2fbed9f24e9f569da805e5c72`

### Original File Hashes (Git Blob SHA)

| Ported Component | Source File in `onebusaway-ios` | Git Blob SHA | Purpose |
|---|---|---|---|
| `WeatherDetailPopup.swift` | `OBAKit/Sheet/Root/WeatherDetailPopup.swift` | `857103936a195afba51e544233ed3758b38b1751` | Authoritative visual popup, card, header, 24h hourly strip, 3-slot stats, icon palette |
| `WeatherDisplay.swift` | `OBAKit/ViewModels/MapViewModel/WeatherDisplay.swift` | `fb1263ddc7649c4446cd9b7aa6e440c28566f9c4` | Authoritative display model (`Header`, `Stats`, `HourlyEntry`, `init?(locationForecast:...)`) |
| `WeatherFormatter.swift` | `OBAKitCore/Weather/WeatherFormatter.swift` | `7290513457c28956ef5d353ecbbbb6fbb650e39f` | Authoritative formatters, condition names, icon mapping, template `"j"` hour format |
| `MOTLocationWeatherModels.swift` | `IsraelMOT/Weather/MOTLocationWeatherService.swift` | `7461e47f3c60289809ea360b4698d8b333f7b06e` | Sourced data models (`MOTLocationWeatherSnapshot`, `MOTLocationWeatherHour`) |
| `WeatherForecast.swift` | `OBAKitCore/Models/Obaco/WeatherForecast.swift` | `f3da2aee69edec20032a1e85d9d222265b18bf05` | Minimal compatibility model for alternate Obaco initializer in `WeatherDisplay` |
| `Localization.swift` | `OBAKit/Strings/Localization.swift` | `fddf4358b71fa8309c5048bc58de99f2891705e4` | UI `OBALoc` lookup adapter via `Bundle.module` |
| `CoreLocalization.swift` | `OBAKitCore/Strings/CoreLocalization.swift` | `6c29696890fd837100b22ff58d7f8eb8f11dcbdd` | Core `OBALoc` lookup adapter via `Bundle.module` |
| `Localizable.strings (UI he)` | `OBAKit/Strings/he.lproj/Localizable.strings` | `d455d28f7edbeb603b440a401edc5fccb6d22307` | Hebrew translations for weather keys |
| `Localizable.strings (UI en)` | `OBAKit/Strings/en.lproj/Localizable.strings` | `b617f3831d54af7f53dc6cb64bfbed8a6f81ab89` | English fallback translations for weather keys |
| `Localizable.strings (Core he)` | `OBAKitCore/Strings/he.lproj/Localizable.strings` | `bd1526dacdc93c8aaa00444015ec90b614216eba` | Hebrew condition strings (`weather.condition.*`) |
| `Localizable.strings (Core en)` | `OBAKitCore/Strings/en.lproj/Localizable.strings` | `5d3161554ddd2ef714dc2281c6b9e7080a6ccde5` | English condition strings (`weather.condition.*`) |

A pristine byte-for-byte baseline copy of every referenced file is preserved in `.baseline/`.

## Audited Alterations vs Baseline

All modifications from the pristine baseline are strictly categorized into the permitted classes:

1. **`import/build glue`**:
   - Updated package imports (`import OneBusAwayWeatherCore` instead of `import OBAKitCore`).
   - Adapted `OBALoc` in `Localization.swift` and `CoreLocalization.swift` to resolve from `Bundle.module` in Swift Package Manager.
   - Declared `public` visibility on `WeatherDetailPopup`, `WeatherDisplay`, and `WeatherIconPalette` so they are accessible from the host app target.
2. **`localization`**:
   - Completed previously untranslated English weather strings in `OneBusAwayWeatherUI/Resources/he.lproj/Localizable.strings` (e.g. `weather.now = "עכשיו"`, `weather.chance_of_rain_format = "סיכוי לגשם: %d%%"`, `weather.stat.feels_like = "מרגיש כמו"`, `weather.stat.wind = "מהירות רוח"`, `weather.stat.precip = "סיכוי למשקעים"`).
3. **`time-zone/data adapter`**:
   - Added optional `timeZone: TimeZone? = nil` parameter to `WeatherDisplay.init?(locationForecast:...)` and `WeatherFormatter.formatTime(_:locale:timeZone:)` to ensure the short hour label reflects the selected city's time zone when fixed abroad.
4. **`API availability`**:
   - `OriginalGlassCompatibility.swift` provides iOS 17-compatible fallback (`Color(uiColor: .secondarySystemBackground)` and `.regularMaterial`) for `.clearGlassEffectIfAvailable` and `.regularGlassEffectIfAvailable`.
5. **`proven correctness regression fix`**:
   - In `METLocationWeatherConverter.iconKey(from:)`, `snow` and `sleet` checks precede `showers`/`rain` to ensure `snowshowers_day` / `snowshowers_night` map to `"snow"` rather than `"rain"`.

## License & Attribution

Copyright © Open Transit Software Foundation.
Licensed under the Apache License, Version 2.0 (see `LICENSE`).
Weather data provided by Norwegian Meteorological Institute (MET Norway), licensed under CC BY 4.0.
