//
//  ContentView.swift
//  Pixels Example
//
//  Created by Olivier on 17.03.23.
//

import SwiftUI
import PixelsLibrary

struct ContentView: View {
    // Our Pixel scanner
    @ObservedObject private var scanner: PixelScanner = PixelScanner.shared
    // Our list of scanned Pixels
    @State var scannedPixels: [ScannedPixel] = []

    var body: some View {
        VStack {
            // Check if Bluetooth is on and authorized by user
            if !scanner.isBluetoothOn {
                Text("Turn on and authorize Bluetooth to scan For Pixels")
            } else {
                // Show start/stop scan button
                Button(scanner.isScanning ? "Stop Pixels Scan" : "Start Pixels Scan") {
                    if !scanner.isScanning {
                        scanner.start()
                    } else {
                        scanner.stop()
                    }
                }
                .buttonStyle(ButtonWithBorder())
            }
            if scannedPixels.count == 0 {
                Text("No Pixels found so far")
            } else {
                Button("Clear List") {
                    scanner.clear()
                }
                .buttonStyle(ButtonWithBorder())
            }
            // List of Pixels
            ScrollView {
                ForEach($scannedPixels, id: \.systemId) { $scannedPixel in
                    PixelView(pixel: scanner.getPixel(scannedPixel), scannedPixel: $scannedPixel)
                        .padding()
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentColor, lineWidth: 4)
                        )
                }
            }
        }
        .padding()
        .onReceive(scanner.$scannedPixels) {
            // Update our internal scanned Pixels state
            scannedPixels = $0
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
