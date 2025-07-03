// InventoryReportView.swift

import SwiftUI
import SwiftData

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// Helper struct to hold the data for each row in the report
struct InventoryReportItem: Identifiable {
    let id = UUID()
    let name: String
    let openingStock: Int
    let suppliesReceived: Int
    let distributedStock: Int
    let closingStock: Int
    let originalItemID: UUID
}

struct InventoryReportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @Query<MonthlyData>(filter: nil, sort: []) private var allMonthlyData: [MonthlyData]
    
    private var monthlyDataForReport: [MonthlyData] {
        guard let selectedMonthID = appState.selectedMonthID else { return [] }
        return allMonthlyData.filter { $0.monthID == selectedMonthID }
    }

    @State private var finalReportItems: [InventoryReportItem] = []
    @State private var errorMessage: String?
    @State private var isLoadingReport = false
    @State private var csvFileURLWrapper: IdentifiableURL?

    var body: some View {
        VStack {
            Button(action: {
                if let url = exportReportToCSV() {
                    print("CSV file URL: \(url.path)")
                    self.csvFileURLWrapper = IdentifiableURL(url: url)
                } else {
                    print("Failed to create CSV file")
                }
            }) {
                Text("Export CSV")
                    .font(.headline)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            List {
                if isLoadingReport {
                    ProgressView("Generating Report...")
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if appState.selectedMonthID == nil {
                    Text("Please select a month to view the inventory report.")
                        .foregroundColor(.secondary)
                        .padding()
                } else if monthlyDataForReport.isEmpty {
                     Text("No monthly data found for \(formattedMonthYear(from: appState.selectedMonthID ?? "")). Please ensure data exists for this month.")
                        .foregroundColor(.secondary)
                        .padding()
                } else if finalReportItems.isEmpty {
                    Text("No relevant inventory activity found for \(formattedMonthYear(from: appState.selectedMonthID ?? "")).")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Header Row
                    Section {
                        HStack {
                            Text("Item Name")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Text("Open")
                                .font(.headline)
                                .frame(width: 50, alignment: .trailing)
                            Text("Supplied")
                                .font(.headline)
                                .frame(width: 70, alignment: .trailing)
                            Text("Dist.")
                                .font(.headline)
                                .frame(width: 50, alignment: .trailing)
                            Text("Close")
                                .font(.headline)
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                    }

                    // Data Rows
                    ForEach(finalReportItems.sorted(by: { $0.name < $1.name })) { item in
                        HStack {
                            Text(item.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                            Text("\(item.openingStock)")
                                .frame(width: 50, alignment: .trailing)
                            Text("\(item.suppliesReceived)")
                                .frame(width: 70, alignment: .trailing)
                            Text("\(item.distributedStock)")
                                .frame(width: 50, alignment: .trailing)
                            Text("\(item.closingStock)")
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .navigationTitle("Inventory Stock Flow")
        .onAppear {
            generateReport()
        }
        .onChange(of: appState.selectedMonthID) {
            generateReport()
        }
        .onChange(of: allMonthlyData) {
            generateReport()
        }
        .sheet(item: $csvFileURLWrapper) { wrapper in
            ActivityViewController(activityItems: [wrapper.url])
        }
    }
    // MARK: - CSV Export
    private func exportReportToCSV() -> URL? {
        let csvHeader = "Item Name,Open,Supplied,Dist.,Close\n"
        let csvRows = finalReportItems.map { item in
            "\"\(item.name)\",\(item.openingStock),\(item.suppliesReceived),\(item.distributedStock),\(item.closingStock)"
        }
        let csvString = csvHeader + csvRows.joined(separator: "\n")

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("InventoryReport.csv")

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
            let fileSize: UInt64
            if fileExists {
                let attr = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                fileSize = attr[FileAttributeKey.size] as? UInt64 ?? 0
            } else {
                fileSize = 0
            }
            print("File exists after writing: \(fileExists), size: \(fileSize) bytes")
            if fileExists && fileSize > 0 {
                return fileURL
            } else {
                print("File is missing or empty, returning nil")
                return nil
            }
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }

    // MARK: - Report Generation Logic
    private func generateReport() {
        isLoadingReport = true
        errorMessage = nil

        Task {
            do {
                guard let currentMonthID = appState.selectedMonthID else {
                    finalReportItems = []
                    isLoadingReport = false
                    return
                }

                guard let currentMonthlyData = monthlyDataForReport.first else {
                    finalReportItems = []
                    isLoadingReport = false
                    return
                }

                let currentMonthStartDate: Date
                let currentMonthEndDate: Date
                (currentMonthStartDate, currentMonthEndDate) = try dateRange(forMonthID: currentMonthID)

                var previousMonthlyData: MonthlyData? = nil
                let previousMonthID = try calculatePreviousMonthID(from: currentMonthID)

                // --- DEBUGGING PRINTS FOR OPENING STOCK ---
                print("\n--- Starting Opening Stock Debug ---")
                print("Current Month ID: \(currentMonthID)")
                print("Calculated Previous Month ID: \(String(describing: previousMonthID))") // Modified line
                
                if let prevID = previousMonthID {
                    let previousMonthFetch = FetchDescriptor<MonthlyData>(
                        predicate: #Predicate { $0.monthID == prevID }
                    )
                    previousMonthlyData = try modelContext.fetch(previousMonthFetch).first
                    
                    if let prevData = previousMonthlyData {
                        print("  ✅ Previous Monthly Data found for ID: \(prevData.monthID)")
                        print("  Number of inventory items in previous month's data: \(prevData.inventoryItems.count)")
                        if prevData.inventoryItems.isEmpty {
                            print("    WARNING: Previous month's inventoryItems array is EMPTY.")
                        }
                        prevData.inventoryItems.forEach { item in
                            print("    - Prev Month Item: \(item.name), Quantity: \(item.quantity), OriginalID: \(item.originalItemID ?? item.id)")                        }
                    } else {
                        print("  ❌ No Previous Monthly Data found for ID: \(prevID). Opening stock will be 0.")
                    }
                } else {
                    print("  Previous Month ID could not be calculated (likely current month is the first month in record). Opening stock will be 0.")
                }
                print("--- Finished Opening Stock Debug ---")
                // --- END DEBUGGING PRINTS FOR OPENING STOCK ---
                
                var currentMonthInventoryMap: [UUID: Int] = [:]
                var previousMonthInventoryMap: [UUID: Int] = [:]
                var currentMonthDistributionsMap: [UUID: Int] = [:]
                var currentMonthSuppliesMap: [UUID: Int] = [:]
                var itemNameMap: [UUID: String] = [:]

                // Populate previousMonthInventoryMap
                previousMonthlyData?.inventoryItems.forEach { item in
                    let originalID = item.originalItemID ?? item.id
                    previousMonthInventoryMap[originalID] = item.quantity
                    if itemNameMap[originalID] == nil {
                        itemNameMap[originalID] = item.name
                    }
                }


                // --- DEBUGGING PRINTS FOR SUPPLIES (from previous iteration, still useful if dates are off) ---
                print("\n--- Starting Supply Calculation Debug (Current Month: \(currentMonthID)) ---")
                print("Current Month Start Date: \(currentMonthStartDate) (TimeZone: \(TimeZone.current.identifier))")
                print("Current Month End Date: \(currentMonthEndDate) (TimeZone: \(TimeZone.current.identifier))")


                currentMonthlyData.inventoryItems.forEach { item in
                    let originalID = item.originalItemID ?? item.id
                    currentMonthInventoryMap[originalID] = item.quantity
                    itemNameMap[originalID] = item.name

                    print("  Processing InventoryItem: \(item.name) (ID: \(item.id), OriginalID: \(originalID))")
                    print("  Number of supplies linked to this item: \(item.supplies.count)")


                    item.supplies.forEach { supply in
                        print("    - Checking Supply: Quantity = \(supply.quantity), Date = \(supply.date)")
                        if supply.date >= currentMonthStartDate && supply.date < currentMonthEndDate {
                            currentMonthSuppliesMap[originalID, default: 0] += supply.quantity
                            print("      ✅ Supply Date IN RANGE. Accumulated for \(item.name): \(currentMonthSuppliesMap[originalID] ?? 0)")
                        } else {
                            print("      ❌ Supply Date OUT OF RANGE. Supply date: \(supply.date), Range: [\(currentMonthStartDate) to \(currentMonthEndDate))")
                        }
                    }
                }
                print("--- Finished Supply Calculation Debug ---")
                // --- END DEBUGGING PRINTS FOR SUPPLIES ---


                currentMonthlyData.seafarers.flatMap { $0.distributions }.forEach { dist in
                    if let originalID = dist.inventoryItem?.originalItemID ?? dist.inventoryItem?.id {
                        // Assuming Distribution has a 'date' property too for range checking
                        if dist.date >= currentMonthStartDate && dist.date < currentMonthEndDate {
                            currentMonthDistributionsMap[originalID, default: 0] += dist.quantity
                        } else {
                            print("  ❌ Distribution Date OUT OF RANGE. Distribution date: \(dist.date), Item: \(dist.inventoryItem?.name ?? "Unknown")")
                        }
                    } else {
                        print("Warning: Distribution found with no linked inventory item.")
                    }
                }

                let allOriginalItemIDs: Set<UUID> = Set(currentMonthInventoryMap.keys)


                var newReportItems: [InventoryReportItem] = []
                for originalID in allOriginalItemIDs {
                    let itemName = itemNameMap[originalID] ?? "Unknown Item"
                    let openingStock = previousMonthInventoryMap[originalID] ?? 0 // Get opening stock from previous month's closing
                    let suppliesReceived = currentMonthSuppliesMap[originalID] ?? 0
                    let distributedStock = currentMonthDistributionsMap[originalID] ?? 0
                    let closingStock = openingStock + suppliesReceived - distributedStock

                    print("Final Report Item Calculation: \(itemName), OriginalID: \(originalID)")
                    print("  Opening Stock: \(openingStock)")
                    print("  Supplies Received: \(suppliesReceived)")
                    print("  Distributed Stock: \(distributedStock)")
                    print("  Calculated Closing Stock: \(closingStock)")

                    newReportItems.append(InventoryReportItem(
                        name: itemName,
                        openingStock: openingStock,
                        suppliesReceived: suppliesReceived,
                        distributedStock: distributedStock,
                        closingStock: closingStock,
                        originalItemID: originalID
                    ))
                }
                
                await MainActor.run {
                    self.finalReportItems = newReportItems
                    self.isLoadingReport = false
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoadingReport = false
                }
                print("Error generating report: \(error)")
            }
        }
    }

    // MARK: - Helper Functions (remain unchanged, ensure accessible)

    private func calculatePreviousMonthID(from monthID: String) throws -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = dateFormatter.date(from: monthID) else {
            throw ReportError.invalidMonthIDFormat
        }

        guard let previousMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: date) else {
            throw ReportError.dateCalculationFailed
        }

        return dateFormatter.string(from: previousMonthDate)
    }

    private func dateRange(forMonthID monthID: String) throws -> (Date, Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current

        guard let startDate = dateFormatter.date(from: monthID) else {
            throw ReportError.invalidMonthIDFormat
        }

        guard let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) else {
            throw ReportError.dateCalculationFailed
        }

        return (startDate, endDate)
    }
}


// Custom Error (remains unchanged)
enum ReportError: LocalizedError {
    case invalidMonthIDFormat
    case dateCalculationFailed

    var errorDescription: String? {
        switch self {
        case .invalidMonthIDFormat: return "Invalid month ID format. Expected YYYY-MM."
        case .dateCalculationFailed: return "Could not calculate month date range."
        }
    }
}


import UIKit
import SwiftUI

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


