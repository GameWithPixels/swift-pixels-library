//
//  MessageType.swift
//  PixelsLibrary
//
//  Created by Olivier on 23.03.23.
//

import Foundation

/// Lists all the Pixel dice message types.
/// The value is used for the first byte of data in a Pixel message to identify it's type.
/// These message identifiers have to match up with the ones on the firmware.
public enum MessageType : UInt8, Codable, Sendable {
    case none
    case whoAreYou
    case iAmADie
    case rollState
    case telemetry
    case bulkSetup
    case bulkSetupAck
    case bulkData
    case bulkDataAck
    case transferAnimationSet
    case transferAnimationSetAck
    case transferAnimationSetFinished
    case transferSettings
    case transferSettingsAck
    case transferSettingsFinished
    case transferTestAnimationSet
    case transferTestAnimationSetAck
    case transferTestAnimationSetFinished
    case debugLog
    case playAnimation
    case playAnimationEvent
    case stopAnimation
    case remoteAction
    case requestRollState
    case requestAnimationSet
    case requestSettings
    case requestTelemetry
    case programDefaultAnimationSet
    case programDefaultAnimationSetFinished
    case blink
    case blinkAck
    case requestDefaultAnimationSetColor
    case defaultAnimationSetColor
    case requestBatteryLevel
    case batteryLevel
    case requestRssi
    case rssi
    case calibrate
    case calibrateFace
    case notifyUser
    case notifyUserAck
    case testHardware
    case testLEDLoopback
    case ledLoopback
    case setTopLevelState
    case programDefaultParameters
    case programDefaultParametersFinished
    case setDesignAndColor
    case setDesignAndColorAck
    case setCurrentBehavior
    case setCurrentBehaviorAck
    case setName
    case setNameAck
    case sleep
    case exitValidation
    case transferInstantAnimationSet
    case transferInstantAnimationSetAck
    case transferInstantAnimationSetFinished
    case playInstantAnimation
    case stopAllAnimations
    case requestTemperature
    case temperature
    case enableCharging
    case disableCharging
    case discharge
};
