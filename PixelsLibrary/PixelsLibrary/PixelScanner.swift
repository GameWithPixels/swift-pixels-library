//
//  PixelScanner.swift
//  PixelsLibrary
//
//  Created by Olivier on 17.03.23.
//

import Foundation
import Bridging

fileprivate struct ManufacturerData: Codable, Sendable {
    var companyId: UInt16 = 0
    var ledCount: UInt8 = 0
    var designAndColor: PixelDesignAndColor
    var rollState: PixelRollState
    var faceIndex: UInt8 = 0
    var battery: UInt8 = 0
}

fileprivate struct ServiceData: Codable, Sendable {
    var pixelId: UInt32 = 0
    var firmwareDate: UInt32 = 0
}

/// Represents a Bluetooth scanner for Pixels dice.
///
/// Call ``startScan(keepPrevious:)`` to initiate a scan and
/// ``stopScan()`` to interrupt it.
/// All Pixels dice that are turned on, within range and not yet connected
/// should appear in the ``scannedPixels`` array after scanning for a few seconds.
///
/// Because scanning for Bluetooth devices can impact battery life,
/// it is recommended to only turn on scanning when necessary.
///
/// All the functionalities are accessed through the class ``shared`` singleton object.
///
/// - Remark: The class properties are updated asynchronously on the main thread
///           and its methods should be called on the main thread too.
@MainActor
public class PixelScanner: ObservableObject {
    /// The shared singleton object.
    public static let shared = PixelScanner()

    private var _central: SGBleCentralManagerDelegate

    /// Indicates the state of the CoreBluetooth manager.
    ///
    /// - Remark: It is recommended to observe this value and update the
    ///           app accordingly.
    @Published public private(set) var bluetoothState: CBManagerState

    /// Shorthand that indicates if Bluetooth is turned on and available for use.
    public var isBluetoothOn: Bool {
        bluetoothState == .poweredOn
    }

    /// Indicates whether a scan for Pixels dice is currently running.
    @Published public private(set) var isScanning: Bool = false

    /// The list of discovered Pixels during scans.
    @Published public private(set) var scannedPixels: [ScannedPixel] = []
    
    /// Initialize the instance.
    private init() {
        weak var weakSelf: PixelScanner? = nil
        _central = SGBleCentralManagerDelegate(stateUpdateHandler: { state in
            DispatchQueue.main.async {
                weakSelf?.bluetoothState = state
            }
        })
        bluetoothState = _central.centralManager.state
        weakSelf = self
        _central.peripheralDiscoveryHandler = { peripheral, advertisementData, rssi in
            DispatchQueue.main.async {  [weak self] in
                let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
                let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
                let servicesData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID:Data]
                // let txPowerLevel = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Number
                if let self, let manufacturerData, let pixelServiceData = servicesData?.values.first {
                    do {
                        let manuf = try BinaryDecoder.decode(ManufacturerData.self, data: manufacturerData)
                        let serv = try BinaryDecoder.decode(ServiceData.self, data: pixelServiceData)
                        let scannedPixel = ScannedPixel(
                            peripheral: peripheral,
                            pixelId: serv.pixelId,
                            name: localName ?? "",
                            ledCount: Int(manuf.ledCount),
                            designAndColor: manuf.designAndColor,
                            firmwareDate: Date(timeIntervalSince1970: TimeInterval(serv.firmwareDate)),
                            rssi: Int(truncating: rssi),
                            batteryLevel: Int(manuf.battery & 0x7f),
                            isCharging: (manuf.battery & 0x80) > 0,
                            rollState: manuf.rollState,
                            currentFace: Int(manuf.faceIndex) + 1)
                        if let index = self.scannedPixels.firstIndex(where: { s in
                            s.pixelId == scannedPixel.pixelId
                        }) {
                            // Update known Pixel
                            self.scannedPixels[index] = scannedPixel
                        } else {
                            // Add new Pixel to list
                            self.scannedPixels.append(scannedPixel)
                        }
                    } catch {
                        print("Error reading Pixel advertisement data: \(error)")
                    }
                } else {
                    print("Got advertisement data with unexpected content")
                }
            }
        }
    }
    
    /// Starts a Bluetooth scan for Pixels.
    ///
    /// - Parameters:
    ///   - keepPrevious: Whether to keep the results of the previous scan.
    ///                   When set to false (the default), the ``scannedPixels`` array
    ///                   is cleared.
    ///
    /// - Remarks: The scan may fail to start for several reasons such as Bluetooth
    ///            being turned off, the user not having authorized the app to access
    ///            Bluetooth, etc.
    @MainActor
    public func startScan(keepPrevious: Bool = false) {
        if !keepPrevious {
            clear()
        }
        _central.centralManager.scanForPeripherals(withServices: [PixelBleUuids.service]);
        let isScanning = _central.centralManager.isScanning
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = isScanning
        }
    }
    
    /// Stops scanning for Pixels.
    @MainActor
    public func stopScan() {
        _central.centralManager.stopScan()
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = false
        }
    }
    
    /// Clear the list of ``scannedPixels``.
    @MainActor
    public func clear() {
        scannedPixels.removeAll();
    }

    //
    // Pixel management
    //
    
    private var _pixels: [UInt32: Pixel] = [:]
    
    /// Returns the ``Pixel`` instance for a given die.
    ///
    /// - Parameter scannedPixel: Information about the die for which to get
    ///                           the ``Pixel`` instance.
    /// - Returns: The ``Pixel`` instance of the die.
    @MainActor
    public func getPixel(_ scannedPixel: ScannedPixel) -> Pixel {
        return _pixels[scannedPixel.pixelId] ?? makePixel(scannedPixel)
    }
    
    // Creates and store a new Pixel instance.
    @MainActor
    private func makePixel(_ scannedPixel: ScannedPixel) -> Pixel {
        let pixel = Pixel(scannedPixel: scannedPixel, central: _central)
        _pixels[scannedPixel.pixelId] = pixel
        return pixel
    }
}
