//
//  Messages.swift
//  PixelsLibrary
//
//  Created by Olivier on 23.03.23.
//

import Foundation

/// Base type for all Pixel messages.
public protocol PixelMessage: Codable, Sendable {
    /// Type of the message.
    var type: MessageType { get }
}

/// Type that can represent any message with no data.
public struct GenericMessage: PixelMessage {
    public internal(set) var type: MessageType
    
    init?(type: MessageType) {
        if type == .none {
            return nil
        }
        self.type = type
    }
}

/// Message send by a Pixel after receiving a "WhoAmI" message.
public struct IAmADie: PixelMessage {
    public internal(set) var type = MessageType.iAmADie;
    
    /// Number of LEDs.
    public var ledCount: UInt8 = 0
    
    /// Die look.
    public var designAndColor = PixelDesignAndColor.generic;
    
    internal var _padding: UInt8 = 0
    
    /// Hash of the uploaded profile.
    public var dataSetHash: UInt32 = 0
    
    /// The Pixel id.
    public var pixelId: UInt32 = 0
    
    /// Amount of available flash.
    public var availableFlashSize: UInt16 = 0
    
    /// Unix timestamp for the date of the firmware.
    public var buildTimestamp: UInt32 = 0
    
    // Roll state
    
    /// Current roll state.
    public var rollState = PixelRollState.unknown
    
    /// Face index (if applicable), starts at 0.
    public var currentFaceIndex: UInt8 = 0
    
    // Battery level
    
    /// The battery charge level in percent.
    public var batteryLevelPercent: UInt8 = 0
    
    /// The charging state of the battery.
    public var batteryState = PixelBatteryState.unknown
}

/// Message send by a Pixel to notify of its rolling state.
public struct RollState: PixelMessage {
    public internal(set) var type = MessageType.rollState;
    
    /// Current roll state.
    public var state = PixelRollState.unknown;
    
    /// Index of the face facing up (if applicable).
    public var faceIndex: UInt8 = 0;
}

/// Message send to a Pixel to have it blink its LEDs.
public struct Blink: PixelMessage {
    public internal(set) var type = MessageType.blink;
    
    /// Number of flashes.
    public var count: UInt8 = 0;
    
    /// Total duration in milliseconds.
    public var duration: UInt16 = 0;
    
    /// Color to blink.
    public var color: UInt32 = 0;
    
    /// Select which faces to light up.
    public var faceMask: UInt32 = Constants.faceMaskAllLEDs;
    
    /// Amount of in and out fading, 0: sharp transition, 255: max fading.
    public var fade: UInt8 = 0;
    
    /// Whether to indefinitely loop the animation.
    public var loop = false;
}

/// Available modes for telemetry requests.
public enum TelemetryRequestMode: UInt8, Codable, Sendable, CustomStringConvertible {
    /// Request Pixel to stop automatically sending telemetry updates.
    case off
    
    /// Request Pixel to immediately send a single telemetry update.
    case once
    
    /// Request Pixel to automatically send telemetry updates.
    case automatic
    
    public var description : String {
        switch self {
        case .off: return "off"
        case .once: return "once"
        case .automatic: return "automatic"
        }
    }
}

/// Message send by a Pixel to notify of its battery level and state.
public struct BatteryLevel: PixelMessage {
    public internal(set) var type = MessageType.batteryLevel;
    
    /// The battery charge level in percent.
    public var levelPercent: UInt8 = 0;
    
    /// The charging state of the battery.
    public var state = PixelBatteryState.unknown;
}

/// Message send to a Pixel to configure RSSI reporting.
public struct RequestRSSI: PixelMessage {
    public internal(set) var type = MessageType.requestRssi;
    
    /// Telemetry mode used for sending the RSSI update(s).
    public var requestMode = TelemetryRequestMode.off;
    
    /// Minimum interval in milliseconds between two updates.
    /// (0 for no cap on rate)
    public var minInterval: UInt16 = 0
}

/// Message send by a Pixel to notify of its measured RSSI.
public struct RSSI: PixelMessage {
    public internal(set) var type = MessageType.rssi;
    
    /// The RSSI value, in dBm.
    public var value: Int8 = 0;
}

/// Returns the metatype of the struct type representing a given message type.
func getMessageClass(fromType messageType: MessageType) -> PixelMessage.Type? {
    switch (messageType) {
    case .iAmADie:
        return IAmADie.self
    case .rollState:
        return RollState.self
    case .blink:
        return Blink.self
    case .batteryLevel:
        return BatteryLevel.self
    case .requestRssi:
        return RequestRSSI.self
    case .rssi:
        return RSSI.self
    default:
        return nil
    }
}
