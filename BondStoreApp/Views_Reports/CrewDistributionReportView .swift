import SwiftUI
import SwiftData

struct CrewDistributionReportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @State private var seafarersForCurrentMonth: [Seafarer] = []
    @State private var csvFileURLWrapper: IdentifiableURL?

    func priceWithTax(for seafarer: Seafarer, basePrice: Double) -> Double {
        seafarer.isRepresentative ? basePrice : basePrice * 1.10
    }

    var seafarersWithDistributions: [Seafarer] {
        seafarersForCurrentMonth.filter { $0.totalSpent > 0 }
    }
    var totalSpentAllSeafarers: Double {
        seafarersWithDistributions.reduce(0) { $0 + $1.totalSpent }
    }
    private var selectedMonthDate: Date? {
        guard let monthID = appState.selectedMonthID else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: monthID)
    }

    private func formattedMonthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                if let url = exportReportToCSV() {
                    print("CSV file URL: \(url.path)")
                    csvFileURLWrapper = IdentifiableURL(url: url)
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
            .padding(.top, 8)

            List {
                if appState.selectedMonthID == nil {
                    Text("Please select a month to view the report.")
                        .foregroundColor(.secondary)
                } else if seafarersForCurrentMonth.isEmpty {
                    Text("No crew distribution data available for \(formattedMonthYear(from: appState.selectedMonthID ?? "")).")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(seafarersWithDistributions.sorted(using: SortDescriptor(\.displayID)), id: \.id) { seafarer in
                        Section {
                            ForEach(seafarer.distributions.sorted(using: SortDescriptor(\.date)), id: \.id) { dist in
                                HStack {
                                    Text(dist.date, style: .date)
                                        .frame(width: 100, alignment: .leading)
                                    Text(dist.itemName)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(dist.quantity)")
                                        .frame(width: 50, alignment: .center)
                                    Text(String(format: "€%.2f", Double(dist.quantity) * priceWithTax(for: seafarer, basePrice: dist.unitPrice)))
                                        .frame(width: 80, alignment: .trailing)
                                }
                            }
                            HStack {
                                Spacer()
                                Text("Total spent: ")
                                Text(String(format: "€%.2f", seafarer.totalSpent))
                                    .bold()
                            }
                        } header: {
                            Text("\(seafarer.displayID). \(seafarer.name)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .frame(maxHeight: .infinity)

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.3))
                .overlay(
                    HStack {
                        Text("Total Spent")
                            .font(.title3.bold())
                            .foregroundColor(Color("Name1"))
                        Spacer()
                        Text("€\(totalSpentAllSeafarers, specifier: "%.2f")")
                            .font(.title3.bold())
                            .foregroundColor(Color("Sum"))
                    }
                    .padding(.horizontal)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal)
                .padding(.bottom, 35)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationTitle(selectedMonthDate.map { "Crew Distributions – \(formattedMonthYear(from: $0))" } ?? "Crew Distributions")
        .onAppear(perform: loadSeafarersForSelectedMonth)
        .onChange(of: appState.selectedMonthID) { _, _ in
            loadSeafarersForSelectedMonth()
        }
        .sheet(item: $csvFileURLWrapper) { (wrapper: IdentifiableURL) in
            ActivityViewController(activityItems: [wrapper.url])
        }
    }
    private func exportReportToCSV() -> URL? {
        // CSV Header
        var csvString = "Seafarer ID,Seafarer Name,Date,Item Name,Quantity,Unit Price,Total Price\n"

        for seafarer in seafarersWithDistributions.sorted(by: { $0.displayID < $1.displayID }) {
            for dist in seafarer.distributions.sorted(by: { $0.date < $1.date }) {
                let totalPrice = Double(dist.quantity) * self.priceWithTax(for: seafarer, basePrice: dist.unitPrice)
                let line = "\(seafarer.displayID),\"\(seafarer.name)\",\(dist.date.formatted(date: .numeric, time: .omitted)),\"\(dist.itemName)\",\(dist.quantity),\(String(format: "%.2f", dist.unitPrice)),\(String(format: "%.2f", totalPrice))\n"
                csvString.append(line)
            }
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("CrewDistributionReport.csv")

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

    private func loadSeafarersForSelectedMonth() {
        guard let monthID = appState.selectedMonthID else {
            seafarersForCurrentMonth = []
            return
        }

        Task {
            do {
                let fetchDescriptor = FetchDescriptor<MonthlyData>(
                    predicate: #Predicate { $0.monthID == monthID }
                )
                let monthlyData = try modelContext.fetch(fetchDescriptor)

                if let currentMonthData = monthlyData.first {
                    self.seafarersForCurrentMonth = currentMonthData.seafarers.sorted(using: SortDescriptor(\.displayID))
                } else {
                    self.seafarersForCurrentMonth = []
                }
            } catch {
                print("Failed to fetch monthly data for report: \(error)")
                self.seafarersForCurrentMonth = []
            }
        }
    }

    func formattedMonthYear(from rawString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"

        guard let date = dateFormatter.date(from: rawString) else {
            return rawString
        }

        dateFormatter.dateFormat = "LLLL yyyy"
        return dateFormatter.string(from: date)
    }
}
