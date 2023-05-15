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

/// A protocol that provides updates on the use of a Pixels die.
public protocol PixelScannerDelegate: AnyObject {
    /// Tells the delegate that the scanner bluetooth state changed.
    /// Be sure to wait for the state to be ``.poweredOn`` before initiating a scan.
    func scanner(_ scanner: PixelScanner, didChangeBluetoothState state: CBManagerState)

    /// Tells the delegate that the scanner either started or stopped scanning for Pixels dice.
    func scanner(_ scanner: PixelScanner, didChangeScanningState isScanning: Bool)

    /// Tells the delegate that the scanner discovered a new Pixels die.
    /// - Remark: ``scanner(_:didUpdateScannedPixel:)`` is also invoked on such an event.
    func scanner(_ scanner: PixelScanner, didDiscoverPixel scannedPixel: ScannedPixel)

    /// Tells the delegate that the scanner either discovered a new Pixels die or got new information about an already discovered one.
    func scanner(_ scanner: PixelScanner, didUpdateScannedPixel scannedPixel: ScannedPixel)
}

public extension PixelScannerDelegate {
    func scanner(_ scanner: PixelScanner, didChangeBluetoothState state: CBManagerState) {}
    func scanner(_ scanner: PixelScanner, didChangeScanningState isScanning: Bool) {}
    func scanner(_ scanner: PixelScanner, didDiscoverPixel scannedPixel: ScannedPixel) {}
    func scanner(_ scanner: PixelScanner, didUpdateScannedPixel scannedPixel: ScannedPixel) {}
}

/// Represents a Bluetooth scanner for Pixels dice.
///
/// Call ``startScan(keepPrevious:)`` to initiate a scan and
/// ``stopScan()`` to interrupt it.
/// All Pixels dice that are turned on, within range and not yet connected
/// should appear in the ``scannedPixels`` array after scanning for a few seconds.
/// Be sure to wait for the scanner to have ``isBluetoothReady`` set to true before initiating a scan.
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
    // Our Central instance to access BLE.
    private var _central: SGBleCentralManagerDelegate
    
    /// The delegate object specified to receive property change events.
    public weak var delegate: PixelScannerDelegate?;

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

    /// The shared singleton object.
    public static let shared = PixelScanner()

    /// Initialize the instance.
    private init() {
        weak var weakSelf: PixelScanner? = nil
        _central = SGBleCentralManagerDelegate(stateUpdateHandler: { state in
            Task { @MainActor in
                if let self = weakSelf {
                    self.bluetoothState = state
                    self.delegate?.scanner(self, didChangeBluetoothState: state)
                    self.setIsScanning(self._central.centralManager.isScanning)
                }
            }
        })
        bluetoothState = _central.centralManager.state
        weakSelf = self;
        _central.peripheralDiscoveryHandler = { peripheral, advertisementData, rssi in
            Task { @MainActor [weak self] in
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
                            // Notify the delegate
                            self.delegate?.scanner(self, didUpdateScannedPixel: scannedPixel);
                        } else {
                            // Add new Pixel to list
                            self.scannedPixels.append(scannedPixel)
                            // Notify the delegate
                            self.delegate?.scanner(self, didDiscoverPixel: scannedPixel);
                            self.delegate?.scanner(self, didUpdateScannedPixel: scannedPixel);
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
        setIsScanning(_central.centralManager.isScanning)
    }
    
    /// Stops scanning for Pixels.
    @MainActor
    public func stopScan() {
        _central.centralManager.stopScan()
        setIsScanning(false);
    }
    
    /// Clear the list of ``scannedPixels``.
    @MainActor
    public func clear() {
        scannedPixels.removeAll();
    }
    
    /// Update "IsScanning" property and notify delegate
    private func setIsScanning(_ isScanning: Bool) {
        Task { @MainActor [weak self] in
            if let self, self.isScanning != isScanning {
                self.isScanning = isScanning
                self.delegate?.scanner(self, didChangeScanningState: isScanning)
            }
        }
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
