//
//  Utlities.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/7/25.
//

import Foundation


func formatHeight(_ height: String?) -> String? {
    guard let heightString = height, let totalInches = Int(heightString) else { return nil }
    let feet = totalInches / 12
    let inches = totalInches % 12
    return "\(feet)'\(inches)\""
}
