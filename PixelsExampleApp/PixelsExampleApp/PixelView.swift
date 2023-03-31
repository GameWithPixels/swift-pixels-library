//
//  PixelView.swift
//  Pixels Example
//
//  Created by Olivier on 28.03.23.
//

import SwiftUI
import PixelsLibrary

struct PixelView: View {
    @ObservedObject var pixel: Pixel
    @Binding var scannedPixel: ScannedPixel
    @State private var lastError: Error?
    
    var pixelInfo: PixelInfo {
        pixel.status != .disconnected ? pixel : scannedPixel
    }
    
    var body: some View {
        VStack {
            Text(pixel.name)
                .font(.largeTitle)
            HStack {
                if pixel.status == .disconnected {
                    Button("Connect") {
                        Task {
                            do {
                                try await pixel.connect()
                                try await pixel.reportRssi()
                            } catch {
                                lastError = error
                            }
                        }
                    }
                } else {
                    Button("Disconnect") {
                        Task {
                            do {
                                try await pixel.disconnect()
                            } catch {
                                lastError = error
                            }
                        }
                    }
                    Button("Blink") {
                        Task {
                            do {
                                try await pixel.blink(duration: 1, color: 0x101000, count: 3)
                            } catch {
                                lastError = error
                            }
                        }
                    }
                }
            }
            Text("Status: \(String(describing: pixel.status))")
            if let lastError {
                Text("Error: \(String(describing: lastError))").foregroundColor(.red)
                Button("Hide Error") {
                    self.lastError = nil
                }
            } else {
                Text("Battery: \(pixelInfo.batteryLevel)%, RSSI: \(pixelInfo.rssi) dBM")
                Text("Roll State: \(pixelInfo.currentFace) (\(String(describing: pixelInfo.rollState)))")
            }
        }
    }
}
