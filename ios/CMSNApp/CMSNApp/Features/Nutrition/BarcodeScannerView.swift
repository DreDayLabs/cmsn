import SwiftUI
import VisionKit

/// Live barcode scanner backed by VisionKit's `DataScannerViewController`
/// (iOS 16+; deployment target is 17). On hardware the camera feed opens
/// and the first recognized barcode is returned; in the Simulator — which
/// has no camera — the fallback lets you type a barcode so the whole flow
/// stays testable end-to-end.
struct BarcodeScannerView: View {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var manualBarcode = ""

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack {
            CMSNColor.offBlack.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    EyebrowLabel(text: "Scan Barcode")
                    Spacer()
                    Button("Close") { dismiss() }.buttonStyle(.cmsnText)
                }
                .padding(.top, 20)

                if scannerAvailable {
                    DataScannerRepresentable { code in
                        onScanned(code)
                        dismiss()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CMSNSurfaceStyle.cornerRadius, style: .continuous))
                    Text("Point the camera at the product's barcode.")
                        .font(CMSNTypography.bodyQuiet())
                        .foregroundStyle(CMSNColor.Semantic.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Camera scanning isn't available on this device — enter the barcode number from the label instead.")
                            .font(CMSNTypography.body())
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                        TextField("e.g. 0016000275270", text: $manualBarcode)
                            .keyboardType(.numberPad)
                            .foregroundStyle(CMSNColor.Semantic.textPrimary)
                            .padding(12)
                            .cmsnChip(isSelected: false)
                        Button("Look Up") {
                            let code = manualBarcode.trimmingCharacters(in: .whitespaces)
                            guard !code.isEmpty else { return }
                            onScanned(code)
                            dismiss()
                        }
                        .buttonStyle(.cmsnPrimary)
                    }
                    .padding(20)
                    .cmsnCard()
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScanned: (String) -> Void
        private var delivered = false

        init(onScanned: @escaping (String) -> Void) { self.onScanned = onScanned }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !delivered else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    delivered = true
                    dataScanner.stopScanning()
                    onScanned(value)
                    return
                }
            }
        }
    }
}
