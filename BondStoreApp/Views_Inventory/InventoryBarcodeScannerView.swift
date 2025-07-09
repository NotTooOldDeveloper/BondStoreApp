//
//  InventoryBarcodeScannerView.swift
//  BondStoreApp
//
//  Created by Valentyn on 30.06.25.
//

//
//  InventoryBarcodeScannerView.swift
//  BondStoreApp
//
//  Created by Valentyn on 30.06.25.
//

import SwiftUI
import AVFoundation
import AudioToolbox
import SwiftData

// Model for scanned inventory item before adding
struct ScannedInventoryItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    let barcode: String // The main scanned barcode
    var quantity: Int
    var dateReceived: Date
    var pricePerUnit: Double
    var additionalBarcodes: [String] = Array(repeating: "", count: 4) // For the 4 extra fields
}

struct IdentifiableBarcode: Identifiable, Equatable {
    let id = UUID()
    let code: String
}

struct InventoryBarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var inventoryItems: [InventoryItem]

    // Date range for the current month
    let startOfMonth: Date
    let endOfMonth: Date

    @State private var scannedItems: [ScannedInventoryItem] = []
    @State private var itemBeingEdited: ScannedInventoryItem?
    @State private var sheetIsPresented = false
    @State private var showDuplicateAlert = false
    @State private var duplicateBarcode: String?
    @State private var scannerController: InventoryScannerViewController?
    
    var body: some View {
        NavigationView {
            VStack {
                InventoryScannerPreview(
                    scannedCodeHandler: handleScan,
                    onRestartScan: {
                        scannerController?.restartCaptureSession()
                    },
                    scannerController: $scannerController
                )
                .frame(height: 220)
                .cornerRadius(12)
                .padding()
                
                if scannedItems.isEmpty {
                    Text("No items scanned yet")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(scannedItems) { item in
                            VStack(alignment: .leading) {
                                Text(item.name.isEmpty ? "(No Name)" : item.name)
                                    .font(.title3)
                                Text("Barcode: \(item.barcode)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text("Qty: \(item.quantity)")
                                    Spacer()
                                    Text(item.dateReceived, style: .date)
                                }
                                .font(.headline)
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: deleteScannedItem)
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
                
                Button("Add items to inventory") {
                    finalizeAdding()
                }
                .disabled(scannedItems.isEmpty)
                .buttonStyle(.borderedProminent)
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .navigationTitle("Inventory Barcode Scanner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Duplicate Barcode", isPresented: $showDuplicateAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                Text("This barcode already exists in your inventory.")
            })
            .onChange(of: showDuplicateAlert) { newValue, _ in
                if !newValue {
                    scannerController?.restartCaptureSession()
                }
            }
            .sheet(isPresented: $sheetIsPresented) {
                // This is the correct way to get a binding from an optional state for a sheet
                if let binding = Binding($itemBeingEdited) {
                    InventoryItemDetailView(
                        item: binding,
                        onAdd: {
                            addScannedItem()
                            sheetIsPresented = false
                        },
                        onCancel: {
                            sheetIsPresented = false
                        },
                        startOfMonth: startOfMonth,
                        endOfMonth: endOfMonth
                    )
                }
            }
            .onChange(of: sheetIsPresented) {
                // If the sheet was just dismissed, restart the camera session.
                if !sheetIsPresented {
                    scannerController?.restartCaptureSession()
                }
            }
        }
    }
    private func handleScan(code: String) {
        if inventoryItems.contains(where: { $0.barcodes.contains(code) }) {
            duplicateBarcode = code
            showDuplicateAlert = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            return
        }

        let today = Date()
        let defaultDate = (today >= startOfMonth && today <= endOfMonth) ? today : startOfMonth

        itemBeingEdited = ScannedInventoryItem(
            name: "",
            barcode: code,
            quantity: 1,
            dateReceived: defaultDate,
            pricePerUnit: 0.0
        )

        sheetIsPresented = true
    }

    private func addScannedItem() {
        guard let itemToAdd = itemBeingEdited else { return }

        if let index = scannedItems.firstIndex(where: { $0.barcode == itemToAdd.barcode }) {
            scannedItems[index] = itemToAdd
        } else {
            scannedItems.append(itemToAdd)
        }
    }

    private func deleteScannedItem(at offsets: IndexSet) {
        scannedItems.remove(atOffsets: offsets)
    }

    private func finalizeAdding() {
        // The loop inside the finalizeAdding() function
        for item in scannedItems {
            let allBarcodes = [item.barcode] + item.additionalBarcodes.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            let newInventoryItem = InventoryItem(
                name: item.name,
                pricePerUnit: item.pricePerUnit,
                barcodes: allBarcodes,
                receivedDate: item.dateReceived
            )
            
            // Create the FIRST supply transaction for this item
            let initialSupply = SupplyRecord(date: item.dateReceived, quantity: item.quantity)
            initialSupply.inventoryItem = newInventoryItem // Link the supply to the item
            
            // Insert both into the database
            modelContext.insert(newInventoryItem)
            modelContext.insert(initialSupply)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save inventory items: \(error)")
        }
        dismiss()
    }
}


struct InventoryItemDetailView: View {
    struct ScanIndex: Identifiable {
        var id: Int { index }
        let index: Int
    }

        @Binding var item: ScannedInventoryItem
    var onAdd: () -> Void
    var onCancel: () -> Void

    let startOfMonth: Date
    let endOfMonth: Date

    @State private var scanningTarget: ScanIndex?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("Enter item name", text: $item.name)
                }
                Section(header: Text("Quantity")) {
                    TextField("Enter quantity", value: $item.quantity, format: .number)
                        .keyboardType(.numberPad)
                }
                Section(header: Text("Price Per Unit")) {
                    TextField("Enter price", value: $item.pricePerUnit, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section(header: Text("Date Received")) {
                    DatePicker("Date Received", selection: $item.dateReceived, in: startOfMonth...endOfMonth, displayedComponents: .date)
                }
                Section(header: Text("Scanned Barcode")) {
                    Text(item.barcode)
                        .foregroundColor(.secondary)
                }
                Section(header: Text("Additional Barcodes (Optional)")) {
                    ForEach(0..<4, id: \.self) { index in
                        HStack {
                            TextField("Barcode \(index + 2)", text: $item.additionalBarcodes[index])
                            Button("Scan") {
                                self.scanningTarget = ScanIndex(index: index)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Item Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Add") { onAdd() } }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
            }
            .sheet(item: $scanningTarget) { target in
                BasicBarcodeScannerView { code in
                    let index = target.index
                    if index < item.additionalBarcodes.count {
                        item.additionalBarcodes[index] = code
                    }
                    scanningTarget = nil // Dismiss scanner
                }
            }
        }
    }
}

// UIViewRepresentable for camera preview and barcode scanning

struct InventoryScannerPreview: UIViewControllerRepresentable {
    var scannedCodeHandler: (String) -> Void
    var onRestartScan: (() -> Void)?
    @Binding var scannerController: InventoryScannerViewController?

    init(
        scannedCodeHandler: @escaping (String) -> Void,
        onRestartScan: (() -> Void)? = nil,
        scannerController: Binding<InventoryScannerViewController?>
    ) {
        self.scannedCodeHandler = scannedCodeHandler
        self.onRestartScan = onRestartScan
        self._scannerController = scannerController
    }

    func makeUIViewController(context: Context) -> InventoryScannerViewController {
        let controller = InventoryScannerViewController()
        controller.onCodeScanned = scannedCodeHandler
        context.coordinator.controller = controller
        context.coordinator.parent.scannerController = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: InventoryScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: InventoryScannerPreview
        var controller: InventoryScannerViewController?

        init(_ parent: InventoryScannerPreview) {
            self.parent = parent
        }
    }
}

class InventoryScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onCodeScanned: ((String) -> Void)?
    private var hasScanned = false


    override func viewDidLoad() {
        super.viewDidLoad()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupCaptureSession()
                    } else {
                        self.showPermissionDeniedAlert()
                    }
                }
            }
        default:
            showPermissionDeniedAlert()
        }
    }

    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .code128, .qr]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        captureSession.stopRunning()

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.onCodeScanned?(stringValue)
            }
        }

        // Reset hasScanned in a short delay to allow re-scanning if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.hasScanned = false
        }
    }


    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    func showPermissionDeniedAlert() {
        let alert = UIAlertController(title: "Camera Access Denied",
                                      message: "Please enable camera access in Settings to scan barcodes.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }
    
    func restartCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
}
