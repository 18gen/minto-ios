//
//  DateHeaderFormatter.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import Foundation

enum DateHeaderFormatter {
    static let header: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    static func string(_ date: Date) -> String { header.string(from: date) }
}
