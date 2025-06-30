//
//  CrewDistributionReportView .swift
//  BondStoreApp
//
//  Created by Valentyn on 30.06.25.
//

import SwiftUI
import SwiftData

struct CrewDistributionReportView: View {
    @Environment(\.modelContext) private var modelContext

    // Query all seafarers
    @Query(sort: \Seafarer.name) var seafarers: [Seafarer]

    var seafarersWithDistributions: [Seafarer] {
        seafarers.filter { $0.totalSpent > 0 }
    }

    var body: some View {
        List {
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
        .navigationTitle("Crew Distributions")
    }
}
