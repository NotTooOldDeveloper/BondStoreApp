// InventoryListView.swift

import SwiftUI
import AVFoundation
import SwiftData

struct InventoryListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    var month: MonthlyData

    @State private var showingAddEditSupply = false
    @State private var editingItem: InventoryItem?

    // Form state
    @State private var itemName = ""
    @State private var itemQuantity = "" // String for TextField input
    @State private var itemBarcode = ""
    @State private var itemPrice = ""   // String for TextField input
    @State private var itemReceivedDate = Date() // This will be the date of the supply

    @State private var isShowingScanner = false
    @State private var showingInventoryBarcodeScanner = false

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
                ForEach(month.inventoryItems.sorted(by: { $0.name < $1.name }), id: \.id) { item in // Added sorting for consistent display
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing(item)
                    }
                }
                .onDelete(perform: deleteItems)

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
            .sheet(isPresented: $showingAddEditSupply) {
                NavigationView {
                    Form {
                        TextField("Name", text: $itemName)
                        TextField("Quantity", text: $itemQuantity)
                            .keyboardType(.numberPad)
                        TextField("Price", text: $itemPrice)
                            .keyboardType(.decimalPad)
                        // It's crucial that this date reflects the *date of the supply*
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
                // You might need to update InventoryBarcodeScannerView as well if it adds items directly
                InventoryBarcodeScannerView(month: month, existingBarcodes: month.inventoryItems.compactMap { $0.barcode ?? "" })
            }
        }
    }

    // private func itemBarcodeFor(_ item: InventoryItem) -> String { ... } // Not used in this context, can be removed if not needed elsewhere

    private func startAdding() {
        editingItem = nil
        itemName = ""
        itemQuantity = ""
        itemBarcode = ""
        itemPrice = ""
        itemReceivedDate = Date() // Initialize to current date for new supplies
        showingAddEditSupply = true
    }

    private func startEditing(_ item: InventoryItem) {
        editingItem = item
        itemName = item.name
        itemQuantity = String(item.quantity)
        itemBarcode = item.barcode ?? ""
        itemPrice = String(format: "%.2f", item.pricePerUnit)
        // When editing, the date field should represent the *most recent supply date* if possible,
        // or just the current date if this is for a new supply. For simplicity, we'll
        // load the existing item's receivedDate, but if the user *adds* more stock, they should
        // change this to the new supply date.
        itemReceivedDate = item.receivedDate
        showingAddEditSupply = true
    }

    private func saveItem() {
        let newQty = Int(itemQuantity) ?? 0
        let price = Double(itemPrice) ?? 0.0

        if let item = editingItem {
            // --- Logic for UPDATING an existing item ---
            let oldQty = item.quantity
            item.name = itemName
            item.pricePerUnit = price
            item.barcode = itemBarcode.isEmpty ? nil : itemBarcode
            item.receivedDate = itemReceivedDate // Update item's overall received date

            // Calculate the quantity that was *supplied* in this transaction
            let suppliedAmount = newQty - oldQty

            // Update item quantity *before* creating supply record, so the supply record is based on the difference
            item.quantity = newQty

            // Only create a SupplyRecord if the quantity *increased*
            if suppliedAmount > 0 {
                let supply = SupplyRecord(date: itemReceivedDate, quantity: suppliedAmount)
                supply.inventoryItem = item // Link the SupplyRecord to the InventoryItem
                item.supplies.append(supply) // Add to the relationship in InventoryItem
                modelContext.insert(supply)  // Insert the SupplyRecord into the context
            }
            // If quantity decreased or stayed same, it's not a supply, so no SupplyRecord needed here.
            // Other operations (like distributions) would handle decreases.

        } else {
            // --- Logic for ADDING a NEW item ---
            let newItem = InventoryItem(name: itemName, quantity: newQty, pricePerUnit: price, receivedDate: itemReceivedDate)
            newItem.barcode = itemBarcode.isEmpty ? nil : itemBarcode
            newItem.originalItemID = newItem.id // Set originalItemID for brand new items

            // Create a SupplyRecord for the initial quantity of the new item
            let initialSupply = SupplyRecord(date: itemReceivedDate, quantity: newQty)
            initialSupply.inventoryItem = newItem // Link the SupplyRecord to the new InventoryItem
            newItem.supplies.append(initialSupply) // Add to the relationship in InventoryItem
            modelContext.insert(initialSupply) // Insert the SupplyRecord into the context

            modelContext.insert(newItem)
            month.inventoryItems.append(newItem)
        }

        // Always save the context after changes
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context after item changes/supply: \(error)")
            // Potentially show an alert to the user
        }

        showingAddEditSupply = false
    }

    private func cancel() {
        showingAddEditSupply = false
        // If editingItem was set, ensure any pending changes are reverted or cancelled
        if editingItem != nil  {
            modelContext.rollback() // Discard unsaved changes for the item if any
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        // ... (this function remains the same, it correctly deletes items from the month and context)
        DispatchQueue.main.async {
            for index in offsets {
                let item = month.inventoryItems[index]
                modelContext.delete(item)
            }
            month.inventoryItems.remove(atOffsets: offsets)

            do {
                try modelContext.save()
            } catch {
                print("Failed to save context after deleting items: \(error)")
            }
        }
    }
}

// MARK: - BarcodeScannerView (remains unchanged)
// This code is provided by you and seems to work for scanning.
// Its integration point is in the sheet and action in the `InventoryListView`.
struct BasicBarcodeScannerView: UIViewControllerRepresentable {
    // ... (rest of the code is the same)
    var completion: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.completion = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        // ... (rest of the code is the same)
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
