import SwiftUI
import SwiftData
import UIKit // Keep UIKit for ActivityViewController, though direct orientation handling is removed

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct InventoryReportItem: Identifiable {
    let id = UUID()
    let name: String
    let openingStock: Int
    let pricePerItem: Double
    let originalItemID: UUID

    // Store the actual transactions for the month
    let monthlySupplies: [SupplyRecord]
    let monthlyDistributions: [Distribution]

    // These are now computed from the transaction lists
    var suppliesReceived: Int {
        monthlySupplies.reduce(0) { $0 + $1.quantity }
    }
    var distributedStock: Int {
        monthlyDistributions.reduce(0) { $0 + $1.quantity }
    }
    var closingStock: Int {
        openingStock + suppliesReceived - distributedStock
    }
    var totalValue: Double {
        Double(closingStock) * pricePerItem
    }

    // Values for the new summary grid
    var openingValue: Double { Double(openingStock) * pricePerItem }
    var suppliedValue: Double {
        monthlySupplies.reduce(0) { $0 + (Double($1.quantity) * pricePerItem) }
    }
    var distributedValue: Double {
        monthlyDistributions.reduce(0) { $0 + (Double($1.quantity) * pricePerItem) }
    }
}

struct InventoryReportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState // Assuming AppState manages selectedMonthID

    @Query(sort: \InventoryItem.name) private var inventoryItems: [InventoryItem]

    @State private var finalReportItems: [InventoryReportItem] = []
    @State private var errorMessage: String?
    @State private var isLoadingReport = false
    @State private var csvFileURLWrapper: IdentifiableURL?
    @State private var expandedReportItemID: UUID? // For expandable rows

    // State for the new summary values
    @State private var totalOpeningValue: Double = 0
    @State private var totalSuppliedValue: Double = 0
    @State private var totalDistributedValue: Double = 0
    @State private var totalClosingValue: Double = 0

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
                    self.csvFileURLWrapper = IdentifiableURL(url: url)
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
            .padding(.bottom, 8)


            if isLoadingReport {
                ProgressView("Generating Report...")
                    .padding()
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)").foregroundColor(.red).padding()
            } else if appState.selectedMonthID == nil {
                Text("Please select a month to view the inventory report.").foregroundColor(.secondary).padding()
            } else {
                //======================== NEW SUMMARY GRID ========================
                VStack {
                    Text("Monthly Summary")
                        .font(.title2.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            SummaryCard(title: "Opening Value", value: totalOpeningValue, color: .black)
                            SummaryCard(title: "Supplied Value", value: totalSuppliedValue, color: .green, prefix: "+")
                        }
                        GridRow {
                            SummaryCard(title: "Distributed Value", value: totalDistributedValue, color: .red, prefix: "-")
                            SummaryCard(title: "Closing Value", value: totalClosingValue, color: .blue)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))

                //======================== DETAILED LIST HEADER ========================
                Text("Detailed List")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .top])
                    .padding(.bottom, 4)

                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        // The Header Row, now a Grid
                        // Reverted to an HStack with specific widths for manual tuning
                        HStack {
                            Text("Item Name")
                                .frame(width: 160, alignment: .leading)
                            Text("Open")
                                .frame(width: 50, alignment: .center)
                            Text("Close")
                                .frame(width: 50, alignment: .center)
                            Text("Total Value")
                                .frame(width: 100, alignment: .center)
                        }
                        .font(.headline)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)

                        Divider()

                        //======================== EXPANDABLE LIST ========================
                        ForEach(finalReportItems.sorted(by: { $0.name < $1.name })) { item in
                            VStack(spacing: 0) {
                                // Reverted to an HStack with specific widths for manual tuning
                                HStack {
                                    Image(systemName: expandedReportItemID == item.id ? "chevron.down" : "chevron.right")
                                        .font(.caption.weight(.bold))
                                    Text(item.name)
                                        .lineLimit(1)
                                        .frame(width: 140, alignment: .leading) // 140 to account for chevron
                                    Text("\(item.openingStock)")
                                        .frame(width: 50, alignment: .center)
                                    Text("\(item.closingStock)")
                                        .frame(width: 50, alignment: .center)
                                    Text(item.totalValue, format: .currency(code: "EUR"))
                                        .frame(width: 100, alignment: .center)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(expandedReportItemID == item.id ? Color.blue.opacity(0.1) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        if expandedReportItemID == item.id {
                                            expandedReportItemID = nil // Collapse
                                        } else {
                                            expandedReportItemID = item.id // Expand
                                        }
                                    }
                                }

                                // Expanded Detail View
                                if expandedReportItemID == item.id {
                                    ReportDetailRow(item: item)
                                        .padding(.leading, 30) // Indent the detail view
                                }
                            }
                            Divider()
                        }
                    }
                }
            }
            Spacer()
        }
        .navigationTitle("Inventory – \(formattedMonthName(from: selectedMonthDate))")
        .onAppear { generateReport() }
        .onChange(of: appState.selectedMonthID) { generateReport() }
        .sheet(item: $csvFileURLWrapper) { wrapper in
            ActivityViewController(activityItems: [wrapper.url])
        }
    }
    
    private func formattedMonthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL" // e.g., "July"
        return formatter.string(from: date)
    }
    
    // MARK: - CSV Export
    // The entire exportReportToCSV() function
    private func exportReportToCSV() -> URL? {
        // --- 1. Build the Summary Block ---
        let reportMonthString = formattedMonthYear(from: appState.selectedMonthID ?? "")
        let generationDateString = Date().formatted(date: .numeric, time: .shortened)

        var summaryContent: [String] = []
        summaryContent.append("\"Monthly Report Summary\"")
        summaryContent.append("\"Month:\",\"\(reportMonthString)\"")
        summaryContent.append("\"Report Generated:\",\"\(generationDateString)\"")
        summaryContent.append("\"Total Opening Value:\",\(totalOpeningValue)")
        summaryContent.append("\"Total Supplied Value:\",\(totalSuppliedValue)")
        summaryContent.append("\"Total Distributed Value:\",\(totalDistributedValue)")
        summaryContent.append("\"Total Closing Value:\",\(totalClosingValue)")

        // --- 2. Define the Header for the main data table ---
        let tableHeader = "\"Item Name\",\"Price Per Item\",\"Opening Stock\",\"Opening Value\",\"Supplies Received Qty\",\"Supplied Value\",\"Distributed Stock Qty\",\"Distributed Value\",\"Closing Stock\",\"Closing Value\""

        // --- 3. Build the Data Rows ---
        let dataRows = finalReportItems.map { item -> String in
            let name = item.name.replacingOccurrences(of: "\"", with: "\"\"") // Escape quotes in name
            return [
                "\"\(name)\"",
                "\(item.pricePerItem)",
                "\(item.openingStock)",
                "\(item.openingValue)",
                "\(item.suppliesReceived)",
                "\(item.suppliedValue)",
                "\(item.distributedStock)",
                "\(item.distributedValue)",
                "\(item.closingStock)",
                "\(item.totalValue)"
            ].joined(separator: ",")
        }

        // --- 4. Combine all parts ---
        let finalCSVString = summaryContent.joined(separator: "\n")
                            + "\n\n" // Blank line
                            + tableHeader + "\n"
                            + dataRows.joined(separator: "\n")

        // --- 5. Write to file (this part remains the same) ---
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("InventoryReport-\(appState.selectedMonthID ?? "export").csv")

        do {
            try finalCSVString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }

    private func generateReport() {
        isLoadingReport = true
        errorMessage = nil
        expandedReportItemID = nil // Collapse all rows on refresh

        Task { @MainActor in
            guard let monthID = appState.selectedMonthID else {
                finalReportItems = []
                isLoadingReport = false
                return
            }

            do {
                let (startOfMonth, endOfMonth) = try dateRange(forMonthID: monthID)
                let startOfOpeningStock = Calendar.current.date(byAdding: .second, value: -1, to: startOfMonth)!

                var newReportItems: [InventoryReportItem] = []

                for item in inventoryItems {
                    let openingStock = getQuantity(for: item, onOrBefore: startOfOpeningStock)

                    // Get the actual transaction records for the month
                    let monthlySupplies = item.supplies.filter { $0.date >= startOfMonth && $0.date < endOfMonth }
                    let monthlyDistributions = item.distributions.filter { $0.date >= startOfMonth && $0.date < endOfMonth }

                    let suppliesReceivedQty = monthlySupplies.reduce(0) { $0 + $1.quantity }
                    let distributedStockQty = monthlyDistributions.reduce(0) { $0 + $1.quantity }

                    // Only include items that were in stock or had activity this month
                    if openingStock > 0 || suppliesReceivedQty > 0 || distributedStockQty > 0 {
                        let reportItem = InventoryReportItem(
                            name: item.name,
                            openingStock: openingStock,
                            pricePerItem: item.pricePerUnit,
                            originalItemID: item.originalItemID ?? item.id,
                            monthlySupplies: monthlySupplies,
                            monthlyDistributions: monthlyDistributions
                        )
                        newReportItems.append(reportItem)
                    }
                }

                self.finalReportItems = newReportItems

                // Calculate the new summary totals
                self.totalOpeningValue = newReportItems.reduce(0) { $0 + $1.openingValue }
                self.totalSuppliedValue = newReportItems.reduce(0) { $0 + $1.suppliedValue }
                self.totalDistributedValue = newReportItems.reduce(0) { $0 + $1.distributedValue }
                self.totalClosingValue = newReportItems.reduce(0) { $0 + $1.totalValue }

            } catch {
                self.errorMessage = error.localizedDescription
            }

            self.isLoadingReport = false
        }
    }
    
    private func getQuantity(for item: InventoryItem, onOrBefore date: Date) -> Int {
        let itemID = item.id // Capture the ID before the predicate.

        // 1. Create a simpler predicate for supplies
        let supplyPredicate = #Predicate<SupplyRecord> {
            $0.inventoryItem?.id == itemID && $0.date <= date
        }
        let totalSupplied = (try? modelContext.fetch(FetchDescriptor(predicate: supplyPredicate)))?.reduce(0) { $0 + $1.quantity } ?? 0

        // 2. Create a simpler predicate for distributions
        let distributionPredicate = #Predicate<Distribution> {
            $0.inventoryItem?.id == itemID && $0.date <= date
        }
        let totalDistributed = (try? modelContext.fetch(FetchDescriptor(predicate: distributionPredicate)))?.reduce(0) { $0 + $1.quantity } ?? 0

        // 3. The current quantity is the difference
        return totalSupplied - totalDistributed
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

// Add these two new views at the end of your file

struct SummaryCard: View {
    let title: String
    let value: Double
    let color: Color
    var prefix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
            Text(prefix + (value.formatted(.currency(code: "EUR"))))
                .font(.title2.weight(.semibold))
                .foregroundColor(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .cornerRadius(12)
    }
}

// The entire ReportDetailRow struct at the bottom of the file
struct ReportDetailRow: View {
    let item: InventoryReportItem

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            // --- Price/Item Row ---
            GridRow(alignment: .firstTextBaseline) {
                Text("Price/Item:").font(.headline)
                EmptyView()
                EmptyView()
                Text(item.pricePerItem, format: .currency(code: "EUR"))
                    .gridColumnAlignment(.trailing)
            }
            // --- Opening Row ---
            GridRow(alignment: .firstTextBaseline) {
                Text("Opening:").font(.headline)
                EmptyView() // Spacer for the date column
                Text("\(item.openingStock) units")
                    .gridColumnAlignment(.trailing)
                Text(item.openingValue, format: .currency(code: "EUR"))
                    .gridColumnAlignment(.trailing)
            }

            // --- Supplies Rows ---
            if !item.monthlySupplies.isEmpty {
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow(alignment: .firstTextBaseline) {
                    Text("Supplies:").font(.headline)
                }
                ForEach(item.monthlySupplies) { supply in
                    GridRow(alignment: .firstTextBaseline) {
                        EmptyView() // Blank cell to indent
                        Text("\(supply.date, style: .date):")
                        Text("\(supply.quantity) units")
                            .gridColumnAlignment(.trailing)
                        Text("+\(Double(supply.quantity) * item.pricePerItem, format: .currency(code: "EUR"))")
                            .foregroundColor(.green)
                            .gridColumnAlignment(.trailing)
                    }
                }
            }

            // --- Distributions Total Row ---
            if item.distributedStock > 0 { // Only show the row if items were distributed
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow(alignment: .firstTextBaseline) {
                    Text("Distributions:").font(.headline)
                    EmptyView() // Spacer for the date column
                    Text("\(item.distributedStock) units")
                        .gridColumnAlignment(.trailing)
                    Text("-\(item.distributedValue, format: .currency(code: "EUR"))")
                        .foregroundColor(.red)
                        .gridColumnAlignment(.trailing)
                }
            }

            // --- Closing Row ---
            Divider().gridCellUnsizedAxes(.horizontal)
            GridRow(alignment: .firstTextBaseline) {
                Text("Closing:").font(.headline)
                EmptyView() // Spacer for the date column
                Text("\(item.closingStock) units").bold()
                    .gridColumnAlignment(.trailing)
                Text(item.totalValue, format: .currency(code: "EUR")).bold()
                    .gridColumnAlignment(.trailing)
            }
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.05))
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95))))
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
