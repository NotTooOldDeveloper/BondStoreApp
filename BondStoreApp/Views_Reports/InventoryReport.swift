import SwiftUI
import SwiftData
import UIKit // Keep UIKit for ActivityViewController, though direct orientation handling is removed

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
    let pricePerItem: Double // New: Price per item
    let totalValue: Double   // New: Total value for the closing stock
    let originalItemID: UUID
}

struct InventoryReportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState // Assuming AppState manages selectedMonthID

    @Query<MonthlyData>(filter: nil, sort: []) private var allMonthlyData: [MonthlyData]
    
    private var monthlyDataForReport: [MonthlyData] {
        guard let selectedMonthID = appState.selectedMonthID else { return [] }
        return allMonthlyData.filter { $0.monthID == selectedMonthID }
    }

    @State private var finalReportItems: [InventoryReportItem] = []
    @State private var errorMessage: String?
    @State private var isLoadingReport = false
    @State private var csvFileURLWrapper: IdentifiableURL?

    // Computed property for selected month as Date
    private var selectedMonthDate: Date {
        guard let selectedMonthID = appState.selectedMonthID else {
            return Date()
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: selectedMonthID) ?? Date()
    }

    var body: some View {
        VStack(spacing: 0) {
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

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
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
                        HStack {
                            Text("Item Name")
                                .font(.headline)
                                .frame(width: 150, alignment: .leading)
                            Text("Open")
                                .font(.headline)
                                .frame(width: 60, alignment: .trailing)
                            Text("Supplied")
                                .font(.headline)
                                .frame(width: 80, alignment: .trailing)
                            Text("Dist.")
                                .font(.headline)
                                .frame(width: 60, alignment: .trailing)
                            Text("Close")
                                .font(.headline)
                                .frame(width: 60, alignment: .trailing)
                            Text("Price/Item")
                                .font(.headline)
                                .frame(width: 90, alignment: .trailing)
                            Text("Total Value")
                                .font(.headline)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)

                        Divider()

                        List {
                            ForEach(finalReportItems.sorted(by: { $0.name < $1.name })) { item in
                                HStack {
                                    Text(item.name)
                                        .frame(width: 150, alignment: .leading)
                                    Text("\(item.openingStock)")
                                        .frame(width: 60, alignment: .trailing)
                                    Text("\(item.suppliesReceived)")
                                        .frame(width: 80, alignment: .trailing)
                                    Text("\(item.distributedStock)")
                                        .frame(width: 60, alignment: .trailing)
                                    Text("\(item.closingStock)")
                                        .frame(width: 60, alignment: .trailing)
                                    Text(item.pricePerItem, format: .currency(code: "EUR"))
                                        .frame(width: 90, alignment: .trailing)
                                    Text(item.totalValue, format: .currency(code: "EUR"))
                                        .frame(width: 100, alignment: .trailing)
                                }
                                .padding(.horizontal, 10)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.3))
                .overlay(
                    HStack {
                        Text("Total value in \(formattedMonthName(from: Date()))")
                            .font(.title3.bold())
                            .foregroundColor(Color("Name1"))
                        Spacer()
                        Text("$\(finalReportItems.reduce(0) { $0 + $1.totalValue }, specifier: "%.2f")")
                            .font(.title3.bold())
                            .foregroundColor(Color("Sum"))
                    }
                    .padding(.horizontal)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .navigationTitle("Inventory – \(formattedMonthName(from: selectedMonthDate))")
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
        // Updated CSV Header to include new columns
        let csvHeader = "Item Name,Open,Supplied,Dist.,Close,Price/Item,Total Value\n"
        let csvRows = finalReportItems.map { item in
            // Ensure numbers are formatted without commas for CSV parsing
            "\"\(item.name)\",\(item.openingStock),\(item.suppliesReceived),\(item.distributedStock),\(item.closingStock),\(item.pricePerItem),\(item.totalValue)"
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

        Task { @MainActor in
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
                
                if let prevID = previousMonthID {
                    let previousMonthFetch = FetchDescriptor<MonthlyData>(
                        predicate: #Predicate { $0.monthID == prevID }
                    )
                    previousMonthlyData = try modelContext.fetch(previousMonthFetch).first
                }
                
                var currentMonthInventoryMap: [UUID: Int] = [:]
                var previousMonthInventoryMap: [UUID: Int] = [:]
                var currentMonthDistributionsMap: [UUID: Int] = [:]
                var currentMonthSuppliesMap: [UUID: Int] = [:]
                var itemNameMap: [UUID: String] = [:]
                var itemPriceMap: [UUID: Double] = [:] // New: Store item prices

                // Populate previousMonthInventoryMap and itemPriceMap
                previousMonthlyData?.inventoryItems.forEach { item in
                    let originalID = item.originalItemID ?? item.id
                    previousMonthInventoryMap[originalID] = item.quantity
                    if itemNameMap[originalID] == nil {
                        itemNameMap[originalID] = item.name
                    }
                    itemPriceMap[originalID] = item.pricePerUnit // Assuming InventoryItem has a 'price' property
                }

                currentMonthlyData.inventoryItems.forEach { item in
                    let originalID = item.originalItemID ?? item.id
                    currentMonthInventoryMap[originalID] = item.quantity
                    itemNameMap[originalID] = item.name
                    itemPriceMap[originalID] = item.pricePerUnit // Assuming InventoryItem has a 'price' property

                    item.supplies.forEach { supply in
                        if supply.date >= currentMonthStartDate && supply.date < currentMonthEndDate {
                            currentMonthSuppliesMap[originalID, default: 0] += supply.quantity
                        }
                    }
                }

                currentMonthlyData.seafarers.flatMap { $0.distributions }.forEach { dist in
                    if let originalID = dist.inventoryItem?.originalItemID ?? dist.inventoryItem?.id {
                        if dist.date >= currentMonthStartDate && dist.date < currentMonthEndDate {
                            currentMonthDistributionsMap[originalID, default: 0] += dist.quantity
                        }
                    }
                }

                let allOriginalItemIDs: Set<UUID> = Set(currentMonthInventoryMap.keys)

                var newReportItems: [InventoryReportItem] = []
                for originalID in allOriginalItemIDs {
                    let itemName = itemNameMap[originalID] ?? "Unknown Item"
                    let openingStock = previousMonthInventoryMap[originalID] ?? 0
                    let suppliesReceived = currentMonthSuppliesMap[originalID] ?? 0
                    let distributedStock = currentMonthDistributionsMap[originalID] ?? 0
                    let closingStock = openingStock + suppliesReceived - distributedStock
                    
                    let pricePerItem = itemPriceMap[originalID] ?? 0.0 // Default to 0.0 if no price
                    let totalValue = Double(closingStock) * pricePerItem // Calculate total value

                    newReportItems.append(InventoryReportItem(
                        name: itemName,
                        openingStock: openingStock,
                        suppliesReceived: suppliesReceived,
                        distributedStock: distributedStock,
                        closingStock: closingStock,
                        pricePerItem: pricePerItem,
                        totalValue: totalValue,
                        originalItemID: originalID
                    ))
                }
                
                self.finalReportItems = newReportItems
                self.isLoadingReport = false

            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoadingReport = false
                print("Error generating report: \(error)")
            }
        }
    }

    // MARK: - Helper Functions
    // (These helper functions remain the same as your original code)

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

    private func formattedMonthYear(from monthID: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = dateFormatter.date(from: monthID) else { return monthID }
        
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: date)
    }

    private func dateRange(forMonthID monthID: String) throws -> (Date, Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current // Important for consistent date range

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


// ActivityViewController (remains unchanged)
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

    private func formattedMonthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
