import SwiftUI
import SwiftData

struct CrewDistributionReportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    @State private var seafarersForCurrentMonth: [Seafarer] = []

    var seafarersWithDistributions: [Seafarer] {
        seafarersForCurrentMonth.filter { $0.totalSpent > 0 }
    }

    var body: some View {
        List {
            if appState.selectedMonthID == nil {
                Text("Please select a month to view the report.")
                    .foregroundColor(.secondary)
            } else if seafarersForCurrentMonth.isEmpty {
                Text("No crew distribution data available for \(formattedMonthYear(from: appState.selectedMonthID ?? "")).")
                    .foregroundColor(.secondary)
            } else {
                ForEach(seafarersWithDistributions.sorted(using: SortDescriptor(\.displayID)), id: \.id) { seafarer in
                    Section { // The content of the section
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
                    } header: { // Define the header content using the 'header' label for clarity
                        // --- BEGIN FONT CHANGE HERE ---
                        Text("\(seafarer.displayID). \(seafarer.name)")
                            .font(.headline) // You can choose .title, .title2, .title3, .headline, .subheadline, etc.
                            .fontWeight(.bold) // You can use .bold, .semibold, .medium, etc.
                            .foregroundColor(.primary) // Or any color you prefer for contrast
                        // --- END FONT CHANGE HERE ---
                    }
                }
            }
        }
        .navigationTitle("Crew Distributions")
        .onAppear(perform: loadSeafarersForSelectedMonth)
        .onChange(of: appState.selectedMonthID) { _, _ in
            loadSeafarersForSelectedMonth()
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
