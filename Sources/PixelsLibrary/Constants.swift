//
//  Constants.swift
//  PixelsLibrary
//
//  Created by Olivier on 31.03.23.
//

import Foundation

/// Constants used across this library.
public struct Constants {
    /// The default timeout value (in seconds) for requests made to a Pixel.
    public static let defaultRequestTimeout = 10.0
    
    /// The default timeout value (in seconds) for waiting on a Pixel to reply.
    public static let ackMessageTimeout = 5.0
    
    /// The maximum size of messages send to a Pixel.
    public static let maxMessageSize = 100
    
    /// Mask value for turning all LEDs on.
    public static let faceMaskAllLEDs: UInt32 = 0xffffffff
}
