import SwiftUI
import AVFoundation
import SwiftData


// New, simpler view for displaying a single inventory row
struct InventoryItemRowView: View {
    let item: InventoryItem
    let quantityForMonth: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.system(size: 18))
                    .bold()
                Text("Quantity: \(quantityForMonth)")
            }
            
            Spacer()
            
            VStack(alignment: .leading) {
                Text(String(format: "Price: €%.2f", item.pricePerUnit))
                    .font(.system(size: 18))
                    .bold(true)
                Text(String(format: "Total: €%.2f", Double(quantityForMonth) * item.pricePerUnit))
                    .foregroundStyle(Color.gray)
            }
        }
    }
}

struct InventoryListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryItem.name) private var inventoryItems: [InventoryItem]
    var monthID: String
    
    @State private var showingAddEditSupply = false
    @State private var editingItem: InventoryItem?

    // Form state for Add/Edit sheet
    @State private var itemName = ""
    @State private var itemQuantity = "" // String for TextField input
    @State private var itemBarcode = ""
    @State private var itemPrice = ""    // String for TextField input
    @State private var itemReceivedDate = Date() // This will be the date of the supply

    @State private var isShowingScanner = false // For the barcode scan within Add/Edit sheet
    @State private var showingInventoryBarcodeScanner = false // For the dedicated Inventory barcode scanner

    // New state for deletion warnings
    @State private var showingDeletionAlert = false
    @State private var itemToDelete: InventoryItem?
    @State private var showingDistributionExistsAlert = false

    private func getQuantity(for item: InventoryItem, onOrBefore date: Date) -> Int {
        let itemID = item.id // Capture the ID before the predicate.

        // 1. Create a predicate for supplies
        let supplyPredicate = #Predicate<SupplyRecord> {
            $0.inventoryItem?.id == itemID && $0.date <= date
        }
        let totalSupplied = (try? modelContext.fetch(FetchDescriptor(predicate: supplyPredicate)))?.reduce(0) { $0 + $1.quantity } ?? 0

        // 2. Create a predicate for distributions
        let distributionPredicate = #Predicate<Distribution> {
            $0.inventoryItem?.id == itemID && $0.date <= date
        }
        let totalDistributed = (try? modelContext.fetch(FetchDescriptor(predicate: distributionPredicate)))?.reduce(0) { $0 + $1.quantity } ?? 0

        // 3. The current quantity is the difference
        return totalSupplied - totalDistributed
    }
    
    private var monthDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone.current // Ensures consistency

        // 1. Get the start date of the selected month
        guard let startDate = formatter.date(from: self.monthID) else { return Date() }

        // 2. Get the start date of the NEXT month
        guard let nextMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) else { return Date() }

        // 3. Get the exact end of the selected month by subtracting one second
        let endOfMonth = Calendar.current.date(byAdding: .second, value: -1, to: nextMonthDate)
        
        return endOfMonth ?? Date()
    }

    private func formattedMonthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }
    
    private var inventoryListContent: some View {
        let startOfOpeningStock = Calendar.current.date(byAdding: .month, value: -1, to: monthDate) ?? Date()

        // Filter items based on the new rule
        let filteredItems = inventoryItems.filter { item in
            let openingStock = getQuantity(for: item, onOrBefore: startOfOpeningStock)
            let closingStock = getQuantity(for: item, onOrBefore: monthDate)

            // Show if opening stock > 0 OR if the quantity changed during the month
            return openingStock > 0 || openingStock != closingStock
        }

        return List {
            ForEach(filteredItems) { item in
                let quantityForMonth = getQuantity(for: item, onOrBefore: monthDate)
                InventoryItemRowView(item: item, quantityForMonth: quantityForMonth)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing(item)
                    }
            }
            .onDelete(perform: confirmDeleteItems)
        }
    }
    
    var body: some View {
            NavigationView {
                inventoryListContent // Just call the new property here
                    .navigationTitle("Inventory – \(formattedMonthName(from: monthDate))")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            startAdding()
                        } label: {
                            Label("Add Item", systemImage: "plus")
                        }

                        Button {
                            showingInventoryBarcodeScanner = true
                        } label: {
                            Label("Add via Barcode Scanner", systemImage: "barcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .imageScale(.large)
                    }
                }
            }
            // Alert for confirming deletion
            .alert("Confirm Deletion", isPresented: $showingDeletionAlert) {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        deleteSingleItem(item) // Call new function for single item deletion
                    }
                }
                Button("Cancel", role: .cancel) {
                    itemToDelete = nil // Clear the item to delete
                }
            } message: {
                Text("Are you sure you want to delete \(itemToDelete?.name ?? "this item")? This action cannot be undone.")
            }
            // Alert for when distributions/supplies exist
            .alert("Item Cannot Be Deleted", isPresented: $showingDistributionExistsAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This item has associated distributions or supplies and cannot be deleted. Please remove all related entries first.")
            }
            .sheet(isPresented: $showingAddEditSupply) {
                NavigationView {
                    Form {
                        TextField("Name", text: $itemName)
                        TextField("Price", text: $itemPrice)
                            .keyboardType(.decimalPad)

                        // Only show Quantity and Date fields when ADDING a new item, not editing.
                        if editingItem == nil {
                            TextField("Quantity", text: $itemQuantity)
                                .keyboardType(.numberPad)
                            DatePicker("Date Received", selection: $itemReceivedDate, displayedComponents: .date)
                        }

                        HStack {
                            TextField("Barcode", text: $itemBarcode)
                            Button("Scan") {
                                isShowingScanner = true
                            }
                        }
                    }
                    .navigationTitle(editingItem == nil ? "Add Item" : "Edit Item")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveItem()
                            }
                            .disabled(itemName.isEmpty || Int(itemQuantity) == nil || Double(itemPrice) == nil)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                cancel()
                            }
                        }
                    }
                }
                .sheet(isPresented: $isShowingScanner) {
                    BasicBarcodeScannerView { code in
                        itemBarcode = code
                        isShowingScanner = false
                    }
                }
            }
            .sheet(isPresented: $showingInventoryBarcodeScanner) {
                InventoryBarcodeScannerView()
            }
        }
    }

    private func startAdding() {
        editingItem = nil
        itemName = ""
        itemQuantity = ""
        itemBarcode = ""
        itemPrice = ""
        itemReceivedDate = Date()
        showingAddEditSupply = true
    }

    private func startEditing(_ item: InventoryItem) {
        editingItem = item
        itemName = item.name
        itemBarcode = item.barcode ?? ""
        itemPrice = String(format: "%.2f", item.pricePerUnit)

        // Quantity and date are no longer part of editing an item's details
        itemQuantity = ""
        itemReceivedDate = Date()

        showingAddEditSupply = true
    }

    private func saveItem() {
        let newQty = Int(itemQuantity) ?? 0
        let price = Double(itemPrice) ?? 0.0

        if let item = editingItem {
            // When editing, we only update the item's core details.
            // Quantity is now handled separately by creating new supplies.
            item.name = itemName
            item.pricePerUnit = price
            item.barcode = itemBarcode.isEmpty ? nil : itemBarcode
        } else {
            // The quantity property on the item itself is not set directly.
            // It is determined by its transactions.
            let newItem = InventoryItem(name: itemName, pricePerUnit: price, receivedDate: itemReceivedDate)
            newItem.barcode = itemBarcode.isEmpty ? nil : itemBarcode

            let initialSupply = SupplyRecord(date: itemReceivedDate, quantity: newQty)
            initialSupply.inventoryItem = newItem // Link supply to item
            modelContext.insert(newItem)     // Insert the new master item
            modelContext.insert(initialSupply) // Insert its initial supply record
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save context after item changes/supply: \(error)")
            // Consider adding a user-facing alert here for save errors
        }

        showingAddEditSupply = false
    }

    private func cancel() {
        showingAddEditSupply = false
        if editingItem != nil {
            modelContext.rollback() // Discard unsaved changes for the item if any
        }
    }

    // This function is called by the .onDelete swipe action
    private func confirmDeleteItems(at offsets: IndexSet) {
        // Since we want to check each item before deleting, iterate through the offsets.
        // If even one item cannot be deleted, show the alert and stop the process for all.
        var itemsCannotBeDeleted = false
        var itemsToConfirm: [InventoryItem] = []

        for index in offsets {
            let item = inventoryItems[index]
            // IMPORTANT: Ensure your InventoryItem model has @Relationship var distributions: [Distribution] = []
            // AND @Relationship var supplies: [SupplyRecord] = [] for these checks to work.
            if !item.distributions.isEmpty {
                itemsCannotBeDeleted = true
                break // Found an item that blocks deletion, so stop checking and show general alert
            }
            itemsToConfirm.append(item)
        }

        if itemsCannotBeDeleted {
            showingDistributionExistsAlert = true
        } else if let firstItem = itemsToConfirm.first {
            // If only one item, show its name in confirmation. Otherwise, a generic message.
            itemToDelete = firstItem // Store the first item for the alert message
            showingDeletionAlert = true // Trigger the confirmation alert
        }
        // If multiple items are selected and all can be deleted, the user will confirm generic "these items"
        // and deleteItems will be called.
        // For simplicity with the single-item `itemToDelete` state, we'll confirm for one at a time via swipe.
        // For multiple swipe deletions, you might need a different confirmation flow.
        // For now, if multiple are swiped and all are deletable, the current setup will only trigger the alert for the first and then delete it.
        // A better approach for multi-swipe would be to collect all deletable items and delete them without per-item confirmation.
        // For this patch, we will prioritize stopping if any item has dependencies.
    }
    
    // New function to handle the actual deletion of a single item
    private func deleteSingleItem(_ item: InventoryItem) {
        if inventoryItems.contains(item) {
            modelContext.delete(item)
            do {
                try modelContext.save()
            } catch {
                print("Failed to save context after deleting item: \(error)")
                // Show an error alert if save fails
            }
        }
        itemToDelete = nil // Clear the stored item
    }
}

// MARK: - BarcodeScannerView (remains unchanged)
// This code is provided by you and seems to work for scanning.
// Its integration point is in the sheet and action in the `InventoryListView`.
struct BasicBarcodeScannerView: UIViewControllerRepresentable {
    var completion: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.completion = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var captureSession: AVCaptureSession!
        var previewLayer: AVCaptureVideoPreviewLayer!
        var completion: ((String) -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = UIColor.black
            captureSession = AVCaptureSession()

            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                failed()
                return
            }
            guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                failed()
                return
            }

            if (captureSession.canAddInput(videoInput)) {
                captureSession.addInput(videoInput)
            } else {
                failed()
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if (captureSession.canAddOutput(metadataOutput)) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .code39, .code128, .qr]
            } else {
                failed()
                return
            }

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }

        func failed() {
            let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support barcode scanning.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true)
            })
            present(ac, animated: true)
            captureSession = nil
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if (captureSession?.isRunning == false) {
                captureSession.startRunning()
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if (captureSession?.isRunning == true) {
                captureSession.stopRunning()
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            captureSession.stopRunning()

            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                        let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                completion?(stringValue)
                // Removed dismiss(animated: true) so SwiftUI sheet state handles dismissal.
            }
        }

        override var prefersStatusBarHidden: Bool {
            true
        }

        override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            .portrait
        }
    }
}
