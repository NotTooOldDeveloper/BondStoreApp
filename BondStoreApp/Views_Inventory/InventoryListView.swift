//
//  InventoryListView.swift
//  BondStoreApp
//
//  Created by Valentyn on 26.06.25.
//

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
    @State private var itemQuantity = ""
    @State private var itemBarcode = ""
    @State private var itemPrice = ""

    @State private var isShowingScanner = false

    var body: some View {
        NavigationView {
            List {
                ForEach(month.inventoryItems) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            Text("Quantity: \(item.quantity)")
                        }
                        Spacer()
                        Text(String(format: "Price: €%.2f", item.pricePerUnit))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing(item)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Inventory")
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        startAdding()
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Item")
                        }
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
        }
    }

    private func itemBarcodeFor(_ item: InventoryItem) -> String {
        item.barcode ?? "N/A"
    }

    private func startAdding() {
        editingItem = nil
        itemName = ""
        itemQuantity = ""
        itemBarcode = ""
        itemPrice = ""
        showingAddEditSupply = true
    }

    private func startEditing(_ item: InventoryItem) {
        editingItem = item
        itemName = item.name
        itemQuantity = String(item.quantity)
        itemBarcode = item.barcode ?? ""
        itemPrice = String(format: "%.2f", item.pricePerUnit)
        showingAddEditSupply = true
    }

    private func saveItem() {
        let qty = Int(itemQuantity) ?? 0
        let price = Double(itemPrice) ?? 0.0
        if let item = editingItem {
            item.name = itemName
            item.quantity = qty
            item.pricePerUnit = price
            item.barcode = itemBarcode.isEmpty ? nil : itemBarcode
        } else {
            let newItem = InventoryItem(name: itemName, quantity: qty, pricePerUnit: price)
            newItem.barcode = itemBarcode.isEmpty ? nil : itemBarcode
            modelContext.insert(newItem)
            month.inventoryItems.append(newItem)
        }
        showingAddEditSupply = false
    }

    private func cancel() {
        showingAddEditSupply = false
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = month.inventoryItems[index]
            modelContext.delete(item)
        }
    }
}



// MARK: - BarcodeScannerView

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
