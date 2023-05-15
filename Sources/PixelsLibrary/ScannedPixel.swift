//
//  ScannedPixel.swift
//  PixelsLibrary
//
//  Created by Olivier on 20.03.23.
//

import Foundation
import CoreBluetooth

/// Data periodically emitted by a Pixel when not connected to a device.
public struct ScannedPixel: PixelInfo {
    internal let peripheral: CBPeripheral
    public var systemId: UUID { peripheral.identifier }
    public var pixelId: UInt32
    public var name: String
    public var ledCount: Int
    public var designAndColor: PixelDesignAndColor
    public var firmwareDate: Date
    public var rssi: Int
    public var batteryLevel: Int
    public var isCharging: Bool
    public var rollState: PixelRollState
    public var currentFace: Int
}
