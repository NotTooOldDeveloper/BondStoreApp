import SwiftUI
import SwiftData

struct CrewDistributionReportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @State private var seafarersForCurrentMonth: [Seafarer] = []
    @State private var csvFileURLWrapper: IdentifiableURL?

    var seafarersWithDistributions: [Seafarer] {
        seafarersForCurrentMonth.filter { $0.totalSpent > 0 }
    }

    var body: some View {
        VStack {
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
                                    Text(String(format: "€%.2f", Double(dist.quantity) * dist.unitPrice))
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
        }
        .navigationTitle("Crew Distributions")
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
                let totalPrice = Double(dist.quantity) * dist.unitPrice
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
