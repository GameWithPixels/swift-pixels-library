//
//  PixelError.swift
//  PixelsLibrary
//
//  Created by Olivier on 24.03.23.
//

import Foundation

/// Errors that might occur when communicating with a Pixel.
/// - Remark: Other errors might be thrown such as those coming from CoreBluetooth.
public enum PixelError: Error, Sendable {
    /// Something unaccounted for happened
    case internalError
    /// Pixel service was not found.
    case missingService
    /// Pixel write characteristic was not found.
    case missingWriteCharacteristic
    /// Pixel notify characteristic was not found.
    case missingNotifyCharacteristic
    /// Pixel is either disconnected or not yet ready to start operations.
    case notReady
    /// Connection to the Pixel was interrupted.
    case connectionCanceled
    /// Waiting on response from the Pixel timed out.
    case responseTimeout
}

