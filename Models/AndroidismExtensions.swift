//
//  AndroidismExtensions.swift
//  FitNotes iOS
//
//  Helper extensions for handling Android-specific data formats
//  as defined in technical_architecture.md section 5
//

import Foundation
import SwiftUI

// MARK: - Color Decoding (Android ARGB int32 → SwiftUI Color)
extension Int32 {
    /// Converts an Android signed ARGB int to a SwiftUI Color.
    var swiftUIColor: Color {
        // Reinterpret sign bits as unsigned without changing the bit pattern
        let unsigned = UInt32(bitPattern: self)
        let a = Double((unsigned >> 24) & 0xFF) / 255.0
        let r = Double((unsigned >> 16) & 0xFF) / 255.0
        let g = Double((unsigned >>  8) & 0xFF) / 255.0
        let b = Double( unsigned        & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Date Parsing (ISO-8601 strings → Date)
extension String {
    static let fitnotesDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat    = "yyyy-MM-dd"
        f.timeZone      = TimeZone(identifier: "UTC")
        f.locale        = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let fitnotesDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat    = "yyyy-MM-dd HH:mm:ss"
        f.timeZone      = TimeZone(identifier: "UTC")
        f.locale        = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var fitnotesDate: Date? {
        Self.fitnotesDateFormatter.date(from: self)
    }

    var fitnotesDateTime: Date? {
        Self.fitnotesDateTimeFormatter.date(from: self)
    }
}