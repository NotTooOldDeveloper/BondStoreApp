//
//  DateRangeHelper.swift
//  BondStoreApp
//
//  Created by Valentyn on 07.07.25.
//

import Foundation

// MARK: - Date Range Helper

struct DateRangeHelper {
    /// Creates a tuple with the start and end dates for a given "yyyy-MM" string.
    static func dateRange(forMonthID monthID: String) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone.current // Use current time zone for consistency

        guard let startDate = formatter.date(from: monthID),
              let nextMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate),
              let endDate = Calendar.current.date(byAdding: .second, value: -1, to: nextMonthDate) else {
            return nil
        }
        return (startDate, endDate)
    }
}

// MARK: - Date Extension

extension Date {
    /// Calculates the first moment of the month for this date.
    var startOfMonth: Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)
    }

    /// Calculates the last moment of the month for this date.
    var endOfMonth: Date? {
        guard let startOfNextMonth = self.startOfNextMonth else { return nil }
        return Calendar.current.date(byAdding: .second, value: -1, to: startOfNextMonth)
    }
    
    /// Helper to get the start of the next month.
    private var startOfNextMonth: Date? {
        guard let startOfMonth = self.startOfMonth else { return nil }
        return Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)
    }
}
