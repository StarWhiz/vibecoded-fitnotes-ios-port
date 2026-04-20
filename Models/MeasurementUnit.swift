//
//  MeasurementUnit.swift
//  FitNotes iOS
//
//  MeasurementUnit model as defined in technical_architecture.md section 4.11
//  Maps to SQLite `MeasurementUnit` table
//

import Foundation
import SwiftData

@Model final class MeasurementUnit {
    var typeRaw: Int           // 0=none, 1=weight, 2=length, 3=percent
    var longName: String
    var shortName: String
    var isCustom: Bool         // iOS addition — gap fix: MeasurementUnit had no custom flag
    var legacyID: Int

    init(typeRaw: Int = 0, longName: String = "", shortName: String = "",
         isCustom: Bool = false, legacyID: Int = 0) {
        self.typeRaw   = typeRaw
        self.longName  = longName
        self.shortName = shortName
        self.isCustom  = isCustom
        self.legacyID  = legacyID
    }
}