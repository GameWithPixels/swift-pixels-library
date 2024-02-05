//
//  PixelInfo.swift
//  PixelsLibrary
//
//  Created by Olivier on 23.03.23.
//

import Foundation

/// Common accessible values between Pixel advertised data and a connected Pixel.
@MainActor
public protocol PixelInfo {
    /// The unique id assigned by the OS to Pixel Bluetooth peripheral.
    var systemId: UUID { get }
    
    /// The unique Pixel id of the device.
    var pixelId: UInt32 { get }
    
    /// The Pixel name.
    var name: String { get }
    
    /// The number of LEDs of the Pixel.
    var ledCount: Int { get }
    
    /// The die color.
    var colorway: PixelColorway { get }
    
    /// The type of die.
    var dieType: PixelDieType { get }
    
    /// The firmware build date of the Pixel.
    var firmwareDate: Date { get }
    
    /// The last RSSI value measured by the Pixel.
    var rssi: Int { get }
    
    /// The Pixel battery level (percentage).
    var batteryLevel: Int { get }
    
    /// Whether the Pixel battery is charging or not.
    /// Set to 'true' if fully charged but still on charger.
    var isCharging: Bool { get }
    
    /// The Pixel roll state.
    var rollState: PixelRollState { get }
    
    /// The Pixel face value that is currently facing up.
    var currentFace: Int { get }
}
