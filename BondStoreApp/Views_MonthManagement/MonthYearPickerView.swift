//
//  MonthYearPickerView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

import SwiftUI
import SwiftData

struct MonthYearPickerView: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int = 2025
    @State private var selectedMonth: Int = 6

    let years = Array(2025...2050)
    let months = Array(1...12)

    @State private var showDuplicateAlert = false

    @Query(sort: \MonthlyData.monthID) private var monthlyDataList: [MonthlyData]
    private var existingMonths: [String] {
        monthlyDataList.map { $0.monthID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                HStack(spacing: 20) {
                    Picker("Year", selection: $selectedYear) {
                        ForEach(years, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("Month", selection: $selectedMonth) {
                        ForEach(months, id: \.self) { month in
                            Text(String(format: "%02d", month)).tag(month)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 150)

                Text("Selected: \(formattedMonthYearString(from: String(format: "%04d-%02d", selectedYear, selectedMonth)))")
                    .font(.headline)
                    .foregroundColor(.blue)

                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            .navigationTitle("Select Month & Year")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        let monthString = String(format: "%04d-%02d", selectedYear, selectedMonth)
                        if existingMonths.contains(monthString) {
                            showDuplicateAlert = true
                        } else {
                            onSelect(monthString)
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Month Already Exists", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The month you are trying to create already exists. Please select a different one.")
            }
        }
    }
}

func formattedMonthYearString(from rawString: String) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM"

    guard let date = dateFormatter.date(from: rawString) else {
        return rawString
    }

    dateFormatter.dateFormat = "LLLL yyyy"
    return dateFormatter.string(from: date)
}
