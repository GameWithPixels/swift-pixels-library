//
//  File.swift
//  
//
//  Created by Olivier on 11.09.23.
//

import Foundation

/// The different types of dice.
public enum PixelDieType: UInt8, Codable, Sendable, CustomStringConvertible {
    case unknown
    case d4
    case d6
    case d8
    case d10
    case d00
    case d12
    case d20
    case d6pipped
    case d6fudge
    
    public var description : String {
        switch self {
        case .unknown: return "unknown"
        case .d4: return "d4"
        case .d6: return "d6"
        case .d8: return "d8"
        case .d10: return "d10"
        case .d00: return "d00"
        case .d12: return "d12"
        case .d20: return "d20"
        case .d6pipped: return "d6pipped"
        case .d6fudge: return "d6fudge"
        }
    }
}

/// Available Pixels dice colorways.
public enum PixelColorway: UInt8, Codable, Sendable, CustomStringConvertible {
    case unknown
    case onyxBlack
    case hematiteGrey
    case midnightGalaxy
    case auroraSky
    case clear
    case custom = 0xff

    public var description : String {
        switch self {
        case .unknown: return "unknown"
        case .onyxBlack: return "onyxBlack"
        case .hematiteGrey: return "hematiteGrey"
        case .midnightGalaxy: return "midnightGalaxy"
        case .auroraSky: return "auroraSky"
        case .clear: return "clear"
        case .custom: return "custom"
        }
    }
}

/// Pixel roll states.
public enum PixelRollState: UInt8, Codable, Sendable, CustomStringConvertible {
    /// The Pixel roll state could not be determined.
    case unknown
    
    /// The Pixel is resting in a position with a face up.
    case onFace
    
    /// The Pixel is being handled.
    case handling
    
    /// The Pixel is rolling.
    case rolling
    
    /// The Pixel is resting in a crooked position.
    case crooked
    
    public var description : String {
        switch self {
        case .unknown: return "unknown"
        case .onFace: return "onFace"
        case .handling: return "handling"
        case .rolling: return "rolling"
        case .crooked: return "crooked"
        }
    }
}

/// The different possible battery charging states.
public enum PixelBatteryState: UInt8, Codable, Sendable, CustomStringConvertible {
    case unknown
    
    /// Battery looks fine, nothing is happening.
    case ok
    
    /// Battery level is low, notify user they should recharge.
    case low
    
    /// Coil voltage is bad, but we don't know yet if that's because we removed
    /// the die and the coil cap is still discharging, or if indeed the die is
    /// incorrectly positioned.
    case transition
    
    /// Coil voltage is bad, die is probably positioned incorrectly.
    /// Note that currently this state is triggered during transition between
    /// charging and not charging...
    case badCharging
    
    /// Charge state doesn't make sense (charging but no coil voltage detected
    /// for instance).
    case error
    
    /// Battery is currently recharging.
    case charging
    
    /// Battery is almost full.
    case trickleCharge
    
    /// Battery is full and finished charging.
    case done
    
    /// Battery is too cold
    case lowTemp
    
    /// Battery is too hot
    case highTemp
    
    public var description : String {
        switch self {
        case .unknown: return "unknown"
        case .ok: return "ok"
        case .low: return "low"
        case .transition: return "transition"
        case .badCharging: return "badCharging"
        case .error: return "error"
        case .charging: return "charging"
        case .trickleCharge: return "trickleCharge"
        case .done: return "done"
        case .lowTemp: return "lowTemp"
        case .highTemp: return "highTemp"
        }
    }
}
