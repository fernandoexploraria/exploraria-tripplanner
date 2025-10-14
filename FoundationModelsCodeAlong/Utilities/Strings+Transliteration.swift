import Foundation

extension String {
    /// Returns a basic Latin/ASCII transliteration of the string by first attempting
    /// ICU-based transliteration to Latin, then removing diacritics and keeping only
    /// ASCII scalars. If ICU yields an empty ASCII result (e.g., emoji-only input),
    /// falls back to a minimal decomposition-based approach. This is intentionally
    /// lossy and aims to be safe for model consumption.
    var transliteratedLatinSafe: String {
        // First, try ICU-based transliteration to Latin
        let mutable = NSMutableString(string: self)
        // Convert to Latin script where possible (e.g., Москва -> Moskva)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        // Strip diacritics (e.g., Café -> Cafe)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        // Keep only ASCII scalars to be extra safe for model consumption
        let icuAsciiScalars = String(mutable).unicodeScalars.filter { $0.isASCII }
        let icuResult = String(String.UnicodeScalarView(icuAsciiScalars))
        if !icuResult.isEmpty {
            return icuResult
        }
        // Fallback: original minimal approach (decompose + drop diacritics + ASCII-only)
        let decomposed = self.decomposedStringWithCanonicalMapping
        let noDiacriticsScalars = decomposed.unicodeScalars.filter { !$0.properties.isDiacritic }
        let asciiScalars = noDiacriticsScalars.filter { $0.isASCII }
        return String(String.UnicodeScalarView(asciiScalars))
    }
}

