//
//  PixelBleUuids.swift
//  PixelsLibrary
//
//  Created by Olivier on 20.03.23.
//

import CoreBluetooth

/// Bluetooth UUIDs related to Pixels peripherals.
public enum PixelBleUuids {
    /// Pixel dice service UUID.
    public static let service = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")

    /// Pixel dice notify characteristic UUID.
    public static let notifyCharacteristic = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")

    /// Pixel dice write characteristic UUID.
    public static let writeCharacteristic = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
}
