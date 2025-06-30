//
//  BarcodeScannerView.swift
//  BondStoreApp
//
//  Created by Valentyn on 30.06.25.
//

import SwiftUI
import AVFoundation



// Model representing scanned item before adding as distribution
struct ScannedItem: Identifiable, Equatable {
    let id = UUID()
    let inventoryItem: InventoryItem
    var quantity: Int
    var date: Date
}

struct BarcodeScannerView: View {
    @Binding var dismissBoth: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let inventoryItems: [InventoryItem]
    let onAddDistributions: ([Distribution]) -> Void

    @State private var scannedItems: [ScannedItem] = []
    @State private var isShowingItemDetail = false
    @State private var currentScannedItem: InventoryItem?
    
    var body: some View {
        NavigationView {
            VStack {
                ScannerPreview(scannedCodeHandler: handleScan)
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
                            HStack {
                                Text(item.inventoryItem.name)
                                    .font(.title3)
                                Spacer()
                                Text("Qty: \(item.quantity)")
                                    .font(.headline)
                                Text(item.date, style: .date)
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 10)
                        }
                        .onDelete(perform: deleteScannedItem)
                    }
                    .listStyle(PlainListStyle())
                }

                Spacer()

                Button(action: {
                    finalizeDistributions()
                }) {
                    Text("Add items to distribution list")
                        .frame(maxWidth: .infinity, minHeight: 50) // 👈 Sets height properly here
                }
                .disabled(scannedItems.isEmpty)
                .buttonStyle(.borderedProminent)
                .padding(.vertical, 24)
                .padding(.horizontal)

                
            }
            .navigationTitle("Barcode Scanner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingItemDetail) {
                if let currentItem = currentScannedItem {
                    ScannedItemDetailView(
                        scannedItem: bindingFor(item: currentItem),
                        onAdd: updateScannedItem
                    )
                }
            }
        }
    }

    private func bindingFor(item: InventoryItem) -> Binding<ScannedItem> {
        guard let index = scannedItems.firstIndex(where: { $0.inventoryItem.id == item.id }) else {
            fatalError("Scanned item not found")
        }
        return $scannedItems[index]
    }

    private func handleScan(code: String) {
        // Lookup inventory item by barcode (assuming barcode stored in `barcode` property)
        guard let foundItem = inventoryItems.first(where: { $0.barcode == code }) else {
            // Optionally show alert "Item not found"
            return
        }

        // If already scanned, open edit modal
        if let index = scannedItems.firstIndex(where: { $0.inventoryItem.id == foundItem.id }) {
            currentScannedItem = scannedItems[index].inventoryItem
            isShowingItemDetail = true
        } else {
            // Add new scanned item and show modal
            let newScannedItem = ScannedItem(inventoryItem: foundItem, quantity: 1, date: Date())
            scannedItems.append(newScannedItem)
            currentScannedItem = foundItem
            isShowingItemDetail = true
        }
    }

    private func updateScannedItem(_ updatedItem: ScannedItem) {
        if let index = scannedItems.firstIndex(where: { $0.inventoryItem.id == updatedItem.inventoryItem.id }) {
            scannedItems[index] = updatedItem
        }
        isShowingItemDetail = false
    }

    private func deleteScannedItem(at offsets: IndexSet) {
        scannedItems.remove(atOffsets: offsets)
    }

    private func finalizeDistributions() {
        var distributions: [Distribution] = []
        for scanned in scannedItems {
            let dist = Distribution(
                date: scanned.date,
                itemName: scanned.inventoryItem.name,
                quantity: scanned.quantity,
                unitPrice: scanned.inventoryItem.pricePerUnit,
                seafarer: nil, // Set by caller later
                inventoryItem: scanned.inventoryItem
            )
            modelContext.insert(dist)
            scanned.inventoryItem.quantity -= scanned.quantity
            distributions.append(dist)
        }
        onAddDistributions(distributions)
        dismiss()
        dismissBoth = false
    }
}

struct ScannedItemDetailView: View {
    @Binding var scannedItem: ScannedItem
    var onAdd: (ScannedItem) -> Void

    var body: some View {
        NavigationView {
            Form {
                Text(scannedItem.inventoryItem.name)
                    .font(.headline)
                DatePicker("Date", selection: $scannedItem.date, displayedComponents: .date)
                HStack {
                    Text("Quantity:")
                        .font(.body)
                    Spacer()
                    Picker("", selection: $scannedItem.quantity) {
                        ForEach(1..<101) { i in
                            Text("\(i)").tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100, height: 50)
                    .clipped()
                }
            }
            .navigationTitle("Add Scanned Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(scannedItem)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onAdd(scannedItem)
                    }
                }
            }
        }
    }
}


struct ScannerPreview: UIViewControllerRepresentable {
    var scannedCodeHandler: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCodeScanned = scannedCodeHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onCodeScanned: ((String) -> Void)?
    private var isCodeScanned = false

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

        captureSession.startRunning()
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

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if isCodeScanned { return }
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            isCodeScanned = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            captureSession.stopRunning()
            onCodeScanned?(stringValue)
            // Allow scanning again after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isCodeScanned = false
                DispatchQueue.global(qos: .userInitiated).async {
                    if !(self?.captureSession.isRunning ?? true) {
                        self?.captureSession.startRunning()
                    }
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
}
