//
//  Pixel.swift
//  Pixels Example
//
//  Created by Olivier on 17.03.23.
//

import Foundation
import Combine
import CoreBluetooth
import Bridging

/// The different possible connection statuses of a Pixels die.
public enum PixelStatus {
    case disconnected
    case connecting
    case identifying
    case ready
    case disconnecting
}

fileprivate typealias VCC = CheckedContinuation<Void, Error>
fileprivate typealias MessageHandler = (Pixel, PixelMessage, MessageSubscription) -> Void

fileprivate struct MessageSubscription {
    let id: Int
    let type: MessageType
    let handler: MessageHandler
}

/// Represents a Pixels die.
///
/// Most of its methods require the instance to be connected to the Pixel device.
/// Call the ``connect()`` method to initiate a connection.
/// - Remark: The class properties are updated asynchronously on the main thread
///           and its methods should be called on the main thread too.
@MainActor
public class Pixel: PixelInfo, ObservableObject {
    // The underlying peripheral for the die
    private let _peripheral: SGBlePeripheralQueue

    // Pixel Bluetooth characteristics
    private var _notifyCharacteristic: CBCharacteristic?
    private var _writeCharacteristic: CBCharacteristic?

    // A published for received messages
    private let _messagesPublisher = PassthroughSubject<PixelMessage, PixelError>()

    /// Gets the Pixel last known connection status.
    @Published
    public private(set) var status: PixelStatus

    /// Shorthand property that indicates if the Pixel status is "ready".
    public var isReady: Bool {
        status == .ready
    }

    // PixelInfo implementation
    @Published
    public private(set) var systemId: UUID
    @Published
    public private(set) var pixelId: UInt32
    @Published
    public private(set) var name: String
    @Published
    public private(set) var ledCount: Int
    @Published
    public private(set) var designAndColor: PixelDesignAndColor
    @Published
    public private(set) var firmwareDate: Date
    @Published
    public private(set) var rssi: Int
    @Published
    public private(set) var batteryLevel: Int
    @Published
    public private(set) var isCharging: Bool
    @Published
    public private(set) var rollState: PixelRollState
    @Published
    public private(set) var currentFace: Int
    
    /// Initialize the instance.
    ///
    /// - Parameters:
    ///   - scannedPixel: The scan information for the Pixel.
    ///   - central: The central manager that discovered the Bluetooth peripheral.
    init(scannedPixel: ScannedPixel, central: SGBleCentralManagerDelegate) {
        // Initialize properties
        status = .disconnected
        systemId = scannedPixel.systemId
        pixelId = scannedPixel.pixelId
        name = scannedPixel.name
        ledCount = scannedPixel.ledCount
        designAndColor = scannedPixel.designAndColor
        firmwareDate = scannedPixel.firmwareDate
        rssi = scannedPixel.rssi
        batteryLevel = scannedPixel.batteryLevel
        isCharging = scannedPixel.isCharging
        rollState = scannedPixel.rollState
        currentFace = scannedPixel.currentFace

        // Create peripheral queue for communicating with Pixels die over Bluetooth
        _peripheral = SGBlePeripheralQueue(peripheral: scannedPixel.peripheral, centralManagerDelegate: central)

        // Subscribe to peripheral connection events
        _peripheral.connectionEventHandler = { ev, reason in
            Task { @MainActor [weak self] in
                await self?.onConnectionEvent(ev, reason: reason)
            }
        }
    }
    
    /// Asynchronously tries to connect to the Pixel. Throws on connection error.
    public func connect() async throws {
        // TODO add timeout
        // First connect to die
        try await withCheckedThrowingContinuation { (cont: VCC) in
            _peripheral.queueConnect(withServices: [PixelBleUuids.service]) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
        // And then setup communications
        do {
            try await internalSetup()
            if status == .identifying {
                _ = try await self.sendMessage(ofType: .whoAreYou, andWaitForResponse: .iAmADie)
            }
        } catch {
            try? await disconnect()
            throw error
        }
        // Finally update status
        if status == .identifying {
            print("Pixel \(name) is ready")
            status = .ready
        } else {
            throw PixelError.connectionCanceled
        }
    }
    
    /// Cancel all on-going requests and immediately disconnects the Pixel.
    public func disconnect() async throws {
        try await withCheckedThrowingContinuation { (cont: VCC) in
            // Cancel on-going requests
            _peripheral.cancel()
            // And the disconnect
            _peripheral.queueDisconnect() { [weak self] error in
                if let error {
                    print("Pixel \(self?.name ?? "deallocated") error: on disconnection, got \(error)")
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }
    
    /// Waits for a message from the Pixel.
    ///
    /// - Parameters:
    ///   - type: Type of the message to expect.
    ///   - timeout: Timeout in seconds before aborting the wait.
    /// - Returns: The received message data.
    ///
    /// - Remark: The function will throw on timeout.
    public func waitForMessage(ofType type: MessageType, timeout: Double = Constants.ackMessageTimeout) async throws -> PixelMessage {
        // Publisher with timeout that only keeps messages of the request type
        let pub = _messagesPublisher
            .filter { $0.type == type }
            .timeout(.seconds(timeout), scheduler: DispatchQueue.main, customError: { .responseTimeout })
        // Wait for first message and returns it
        var subscription: AnyCancellable? // This is to keep the subscription alive
        var gotMessage = false
        return try await withCheckedThrowingContinuation { cont in
            subscription = pub.first().sink {
                switch $0 {
                case .finished:
                    if !gotMessage {
                        // We didn't get any message, which shouldn't happen as the above
                        // for loop waits indefinitely until it gets a value
                        cont.resume(throwing: PixelError.internalError)
                    }
                    break
                case let .failure(error):
                    cont.resume(throwing: error)
                    break
                }
            } receiveValue: { msg in
                gotMessage = true
                cont.resume(returning: msg)
            }
            // Because of compiler warning
            _ = subscription
        }
        // -- Requires iOS >= 15 --
        // for try await msg in pub.values {
        //     return msg
        // }
        // We didn't get any message, which shouldn't happen as the above
        // for loop waits indefinitely until it gets a value
        // throw PixelError.internalError
    }
    
    /// Sends a message to the Pixel.
    ///
    /// - Parameters:
    ///   - message: Message object with the data to send.
    ///   - withoutAck: Whether to request a confirmation that the message was received.
    public func sendMessage(_ message: PixelMessage, withoutAck: Bool = false) async throws {
        if let data = try? BinaryEncoder.encode(message) {
            try await send(data, withoutAck: withoutAck)
        }
    }
    
    /// Sends a message to the Pixel and wait for a specific response.
    ///
    /// - Parameters:
    ///   - message: Message object with the data to send.
    ///   - responseType: Type of the response to expect.
    ///   - timeout: Timeout in seconds before aborting waiting for the response.
    /// - Returns: The data of the response message.
    ///
    /// - Remark: The function will throw on timeout.
    public func sendMessage(_ message: PixelMessage, andWaitForResponse responseType: MessageType, timeout: Double = Constants.ackMessageTimeout) async throws -> PixelMessage {
        let data = try BinaryEncoder.encode(message)
        return try await send(data, andWaitFor: responseType, timeout: timeout)
    }
    
    /// Sends a message to the Pixel.
    ///
    /// - Parameter:
    ///   - type: Type of data less message to send.
    ///   - withoutAck: Whether to request a confirmation that the message was received.
    public func sendMessage(ofType type: MessageType, withoutAck: Bool = false) async throws {
        try await send(Data([type.rawValue]), withoutAck: withoutAck)
    }
    
    /// Sends a message to the Pixel and wait for a specific reply.
    ///
    /// - Parameters:
    ///   - type: Type of data less message to send.
    ///   - responseType: Type of the response to expect.
    ///   - timeout: Timeout in seconds before aborting waiting for the response.
    /// - Returns: The data of the response message.
    ///
    /// - Remark: The function will throw on timeout.
    public func sendMessage(ofType type: MessageType, andWaitForResponse responseType: MessageType, timeout: Double = Constants.ackMessageTimeout) async throws -> PixelMessage {
        return try await send(Data([type.rawValue]), andWaitFor: responseType, timeout: timeout)
    }
    
    /// Requests Pixel to regularly send its measured RSSI value.
    ///
    /// - Parameters:
    ///   - activate: Whether to turn or turn off this feature.
    ///   - minimumInterval: The minimum time interval in seconds
    ///                      between two RSSI updates.
    public func reportRssi(activate: Bool = true, minimumInterval: Int = 5000) async throws {
        try await sendMessage(RequestRssi(requestMode: activate ? .automatic : .off, minInterval: UInt16(minimumInterval)))
    }
    
    /// Requests Pixel to turn itself off.
    public func turnOff() async throws {
        try await sendMessage(ofType: .sleep, withoutAck: true)
    }
    
    /// Requests Pixel to blink and wait for a confirmation.
    ///
    /// - Parameters:
    ///   - duration: Total duration of the animation in seconds.
    ///   - color: Blink color.
    ///   - count: Number of blinks.
    ///   - fade: Amount of in and out fading, 0: sharp transition, 1: maximum fading.
    public func blink(duration: Double, color: Int, count: Int = 1, fade: Double = 1) async throws {
        let blink = Blink(
            count: UInt8(count),
            duration: UInt16(duration * 1000),
            color: UInt32(color),
            fade: UInt8(255 * fade))
        _ = try await sendMessage(blink, andWaitForResponse: .blinkAck)
    }

    /// Process peripheral connection events.
    ///
    /// - Parameters:
    ///   - connEvent: Connection event type.
    ///   - reason: Reason of that caused the event.
    private func onConnectionEvent(_ connEvent: SGBleConnectionEvent, reason: SGBleConnectionEventReason) async {
        switch connEvent {
        case .connecting:
            status = .connecting
            break
        case .connected:
            break
        case .ready:
            status = .identifying
            break
        case .disconnecting:
            status = .disconnecting
            break
        case .failedToConnect:
            print("Pixel \(name) error: failed to connect with reason \(reason)")
            fallthrough
        case .disconnected:
            print("Pixel \(name) disconnected")
            status = .disconnected
            break
        @unknown default:
            fatalError()
        }
    }
    
    /// Prepare the instance for communicating with peripheral
    private func internalSetup() async throws {
        // Get Pixel service and characteristics
        let service = _peripheral.peripheral.services?.first(where: { $0.uuid == PixelBleUuids.service })
        let notify = service?.characteristics?.first(where: { $0.uuid == PixelBleUuids.notifyCharacteristic })
        let write = service?.characteristics?.first(where: { $0.uuid == PixelBleUuids.writeCharacteristic })
        
        if let notify, let write {
            _notifyCharacteristic = notify
            _writeCharacteristic = write

            // Subscribe to notify characteristic
            try await withCheckedThrowingContinuation { (cont: VCC) in
                _peripheral.queueSetNotifyValue(for: notify) { [weak self] characteristic, error in
                    if let error {
                        print("Pixel \(self?.name ?? "deallocated") error: on notified value, got \(error)")
                    } else if let data = characteristic.value {
                        Task { @MainActor [weak self] in
                            await self?.processMessage(data: data)
                        }
                    }
                } completionHandler: { error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                       cont.resume()
                   }
                }
            }
        } else if service == nil {
            throw PixelError.missingService
        } else if notify == nil {
            throw PixelError.missingNotifyCharacteristic
        } else {
            throw PixelError.missingWriteCharacteristic
        }
    }
    
    /// Send data to the Pixel.
    ///
    /// - Parameters:
    ///   - data: The raw data to send.
    ///   - withoutAck: Whether to request a confirmation that the message was received.
    private func send(_ data: Data, withoutAck: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (cont: VCC) in
            if let characteristic = _writeCharacteristic {
                let type: CBCharacteristicWriteType = withoutAck ? .withoutResponse : .withResponse
                _peripheral.queueWriteValue(data, for: characteristic, type: type) { error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume()
                    }
                }
            } else {
                cont.resume(throwing: PixelError.notReady)
            }
        }
    }
    
    /// Send data to the Pixel.
    ///
    /// - Parameters:
    ///   - data: The raw data to send.
    ///   - responseType: Type of the response to expect.
    ///   - timeout: Timeout in seconds before aborting waiting for the response.
    /// - Returns: The data of the response message.
    ///
    /// - Remark: The function will throw on timeout.
    private func send(_ data: Data, andWaitFor responseType: MessageType, timeout: Double) async throws -> PixelMessage {
        // We start listening to the response first
        // to be sure to not miss it in case of a race condition
        async let msg = waitForMessage(ofType: responseType)
        // Send data
        try await self.send(data)
        // And wait for the expected response
        return try await msg
    }
    
    /// Decode the given data as a message and process its information.
    ///
    /// - Parameter data: The raw data of the message.
    private func processMessage(data: Data) async {
        if data.count > 0 {
            if data.count == 1 {
                let type = MessageType(rawValue: data[0])
                if let type, let msg = GenericMessage(type: type) {
                    _messagesPublisher.send(msg)
                } else {
                    print("Pixel \(name) error: unknown message type is \(data[0])")
                }
            }
            else if let msg = Pixel.decodeMessage(data: data) {
                switch (msg){
                case let iAmADie as IAmADie:
                    self.pixelId = iAmADie.pixelId
                    self.ledCount = Int(iAmADie.ledCount)
                    self.designAndColor = iAmADie.designAndColor
                    self.firmwareDate = Date(timeIntervalSince1970: TimeInterval(iAmADie.buildTimestamp))
                    break
                case let roll as RollState:
                    self.currentFace = Int(roll.faceIndex) + 1
                    self.rollState = roll.state
                case let battery as BatteryLevel:
                    self.batteryLevel = Int(battery.levelPercent)
                    self.isCharging = battery.state == .charging || battery.state == .trickleCharge || battery.state == .done
                    break
                case let rssi as Rssi:
                    self.rssi = Int(rssi.value)
                    break
                default:
                    // Nothing to do
                    break
                }
                self._messagesPublisher.send(msg)
            } else {
                print("Pixel error: failed to decode message of type \(data[0])")
            }
        }
    }

    /// Decode the message data.
    /// 
    /// - Parameter data: Message data.
    /// - Returns: The decoded message or nil.
    private static func decodeMessage(data: Data) -> PixelMessage? {
        if data.count > 0, let type = MessageType(rawValue: Array(data)[0]) {
            if let metaType = getMessageClass(fromType: type)  {
                return try? BinaryDecoder.decode(metaType, data: data)
            }
        }
        return nil
    }
}
