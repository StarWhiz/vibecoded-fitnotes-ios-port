//
//  Plate.swift
//  FitNotes iOS
//
//  Plate model as defined in technical_architecture.md section 4.12
//  Maps to SQLite `Plate` table
//

import Foundation
import SwiftData
import SwiftUI

@Model final class Plate {
    var weightKg: Double
    var count: Int
    var colourARGB: Int32
    var widthMm: Double?
    var diameterMm: Double?
    var isAvailable: Bool    // whether the plate is in the current loadout
    var legacyID: Int

    var color: Color {
        let unsigned = UInt32(bitPattern: colourARGB)
        let a = Double((unsigned >> 24) & 0xFF) / 255.0
        let r = Double((unsigned >> 16) & 0xFF) / 255.0
        let g = Double((unsigned >>  8) & 0xFF) / 255.0
        let b = Double((unsigned      ) & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    init(weightKg: Double = 0, count: Int = 0, colourARGB: Int32 = 0,
         widthMm: Double? = nil, diameterMm: Double? = nil,
         isAvailable: Bool = true, legacyID: Int = 0) {
        self.weightKg       = weightKg
        self.count          = count
        self.colourARGB     = colourARGB
        self.widthMm        = widthMm
        self.diameterMm     = diameterMm
        self.isAvailable    = isAvailable
        self.legacyID       = legacyID
    }
}