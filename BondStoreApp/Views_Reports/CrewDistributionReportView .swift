import SwiftUI
import SwiftData

struct CrewDistributionReportView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState // Ensure AppState is available

    // Use a @State property to hold the seafarers for the current month
    // We will populate this array based on appState.selectedMonthID
    @State private var seafarersForCurrentMonth: [Seafarer] = []

    // A computed property to filter seafarers who have distributions
    var seafarersWithDistributions: [Seafarer] {
        seafarersForCurrentMonth.filter { $0.totalSpent > 0 }
    }

    var body: some View {
        List {
            // Display a message if no month is selected or no data for the month
            if appState.selectedMonthID == nil {
                Text("Please select a month to view the report.")
                    .foregroundColor(.secondary)
            } else if seafarersForCurrentMonth.isEmpty {
                Text("No crew distribution data available for \(formattedMonthYear(from: appState.selectedMonthID ?? "")).")
                    .foregroundColor(.secondary)
            } else {
                ForEach(seafarersWithDistributions, id: \.id) { seafarer in
                    Section(header: Text(seafarer.name)) {
                        ForEach(seafarer.distributions, id: \.id) { dist in
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
                    }
                }
            }
        }
        .navigationTitle("Crew Distributions")
        // Load data whenever the view appears or the selected month changes
        .onAppear(perform: loadSeafarersForSelectedMonth)
        .onChange(of: appState.selectedMonthID) { _, _ in // New syntax for onChange
            loadSeafarersForSelectedMonth()
        }
    }

    // Helper function to load seafarers based on the selected month
    private func loadSeafarersForSelectedMonth() {
        guard let monthID = appState.selectedMonthID else {
            seafarersForCurrentMonth = [] // Clear data if no month is selected
            return
        }

        Task { // Perform data fetching asynchronously
            do {
                let fetchDescriptor = FetchDescriptor<MonthlyData>(
                    predicate: #Predicate { $0.monthID == monthID }
                )
                let monthlyData = try modelContext.fetch(fetchDescriptor)

                // If MonthlyData for the selected month exists, use its seafarers
                if let currentMonthData = monthlyData.first {
                    // Sort seafarers by name for consistent display
                    self.seafarersForCurrentMonth = currentMonthData.seafarers.sorted(using: SortDescriptor(\.name))
                } else {
                    self.seafarersForCurrentMonth = [] // No data for this month
                }
            } catch {
                print("Failed to fetch monthly data for report: \(error)")
                self.seafarersForCurrentMonth = []
            }
        }
    }

    // You might already have this, but including for completeness
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
