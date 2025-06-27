//
//  MonthYearPickerView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import SwiftUI

struct MonthYearPickerView: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int = 2025
    @State private var selectedMonth: Int = 6

    let years = Array(2025...2050)
    let months = Array(1...12)

    var body: some View {
        NavigationView {
            Form {
                Picker("Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text("\(year)").tag(year)
                    }
                }
                Picker("Month", selection: $selectedMonth) {
                    ForEach(months, id: \.self) { month in
                        Text(String(format: "%02d", month)).tag(month)
                    }
                }
            }
            .navigationTitle("Select Month & Year")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        let monthString = String(format: "%04d-%02d", selectedYear, selectedMonth)
                        onSelect(monthString)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
