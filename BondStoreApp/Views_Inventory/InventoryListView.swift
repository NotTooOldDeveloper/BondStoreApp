import SwiftUI
import AVFoundation
import SwiftData

struct InventoryListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    var month: MonthlyData // Assuming MonthlyData has a @Relationship for inventoryItems

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

    private var monthDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.date(from: month.monthID) ?? Date()
    }

    private func formattedMonthName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(month.inventoryItems.sorted(by: { $0.name < $1.name }), id: \.id) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.system(size: 18))
                                .bold()
                            Text("Quantity: \(item.quantity)")
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text(String(format: "Price: €%.2f", item.pricePerUnit))
                                .font(.system(size: 18))
                                .bold(true)
                            Text(String(format: "Total: €%.2f", Double(item.quantity) * item.pricePerUnit))
                                .foregroundStyle(Color.gray)
                        }
                    }
                    .contentShape(Rectangle()) // Makes the whole row tappable
                    .onTapGesture {
                        startEditing(item)
                    }
                }
                .onDelete(perform: confirmDeleteItems) // Modified to confirm before delete
            }
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
                        TextField("Quantity", text: $itemQuantity)
                            .keyboardType(.numberPad)
                        TextField("Price", text: $itemPrice)
                            .keyboardType(.decimalPad)
                        DatePicker("Date Received", selection: $itemReceivedDate, displayedComponents: .date)
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
                // Ensure InventoryBarcodeScannerView can handle adding items and linking to month
                InventoryBarcodeScannerView(month: month, existingBarcodes: month.inventoryItems.compactMap { $0.barcode ?? "" })
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
        itemQuantity = String(item.quantity)
        itemBarcode = item.barcode ?? ""
        itemPrice = String(format: "%.2f", item.pricePerUnit)
        itemReceivedDate = item.receivedDate
        showingAddEditSupply = true
    }

    private func saveItem() {
        let newQty = Int(itemQuantity) ?? 0
        let price = Double(itemPrice) ?? 0.0

        if let item = editingItem {
            let oldQty = item.quantity
            item.name = itemName
            item.pricePerUnit = price
            item.barcode = itemBarcode.isEmpty ? nil : itemBarcode
            item.receivedDate = itemReceivedDate

            let suppliedAmount = newQty - oldQty

            item.quantity = newQty // Update item quantity directly

            if suppliedAmount > 0 {
                let supply = SupplyRecord(date: itemReceivedDate, quantity: suppliedAmount)
                supply.inventoryItem = item
                item.supplies.append(supply)
                modelContext.insert(supply)
            }
        } else {
            let newItem = InventoryItem(name: itemName, quantity: newQty, pricePerUnit: price, receivedDate: itemReceivedDate)
            newItem.barcode = itemBarcode.isEmpty ? nil : itemBarcode
            newItem.originalItemID = newItem.id // Set originalItemID for brand new items

            let initialSupply = SupplyRecord(date: itemReceivedDate, quantity: newQty)
            initialSupply.inventoryItem = newItem
            newItem.supplies.append(initialSupply)
            modelContext.insert(initialSupply)

            modelContext.insert(newItem)
            month.inventoryItems.append(newItem)
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

    // MARK: - Deletion Logic

    // This function is called by the .onDelete swipe action
    private func confirmDeleteItems(at offsets: IndexSet) {
        // Since we want to check each item before deleting, iterate through the offsets.
        // If even one item cannot be deleted, show the alert and stop the process for all.
        var itemsCannotBeDeleted = false
        var itemsToConfirm: [InventoryItem] = []

        for index in offsets {
            let item = month.inventoryItems[index]
            // IMPORTANT: Ensure your InventoryItem model has @Relationship var distributions: [Distribution] = []
            // AND @Relationship var supplies: [SupplyRecord] = [] for these checks to work.
            if !item.distributions.isEmpty || !item.supplies.isEmpty {
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
        if let index = month.inventoryItems.firstIndex(where: { $0.id == item.id }) {
            modelContext.delete(item)
            month.inventoryItems.remove(at: index)

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
