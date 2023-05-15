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
}

fileprivate typealias VCC = CheckedContinuation<Void, Error>
fileprivate typealias MessageHandler = (Pixel, PixelMessage, MessageSubscription) -> Void

fileprivate struct MessageSubscription {
    let id: Int
    let type: MessageType
    let handler: MessageHandler
}

/// A protocol that provides updates on the use of a Pixels die.
public protocol PixelDelegate: AnyObject {
    /// Tells the delegate that the connection status of the Pixels die changed.
    func pixel(_ pixel: Pixel, didChangeStatus status: PixelStatus)

    /// Tells the delegate that the Pixels die got a new firmware
    func pixel(_ pixel: Pixel, didChangeFirmwareDate firmwareDate: Date)

    /// Tells the delegate that the measured RSSI with the Pixels die changed.
    /// - Remark: Call ``Pixel/reportRSSI(activate:minimumInterval:)`` to start monitoring RSSI.
    func pixel(_ pixel: Pixel, didChangeRSSI rssi: Int)

    /// Tells the delegate that the Pixels die battery level changed.
    func pixel(_ pixel: Pixel, didChangeBatteryLevel batteryLevel: Int)

    /// Tells the delegate that the Pixels die charging status changed.
    func pixel(_ pixel: Pixel, didChangeChargingState isCharging: Bool)

    /// Tells the delegate that the Pixels die roll state or the current face changed.
    func pixel(_ pixel: Pixel, didChangeRollState rollState: PixelRollState, withFace face: Int)

    /// Tells the delegate that the Pixels die completed a roll.
    func pixel(_ pixel: Pixel, didRollOnFace face: Int)

    /// Tells the delegate that the Pixels die instance received a message.
    /// In other words the message was send by the actual die and received by the Pixel object.
    func pixel(_ pixel: Pixel, didReceiveMessage message: PixelMessage)
}

public extension PixelDelegate {
    func pixel(_ pixel: Pixel, didChangeStatus status: PixelStatus) {}
    func pixel(_ pixel: Pixel, didChangeFirmwareDate firmwareDate: Date) {}
    func pixel(_ pixel: Pixel, didChangeRSSI rssi: Int) {}
    func pixel(_ pixel: Pixel, didChangeBatteryLevel batteryLevel: Int) {}
    func pixel(_ pixel: Pixel, didChangeChargingState isCharging: Bool) {}
    func pixel(_ pixel: Pixel, didChangeRollState rollState: PixelRollState, withFace face: Int) {}
    func pixel(_ pixel: Pixel, didRollOnFace face: Int) {}
    func pixel(_ pixel: Pixel, didReceiveMessage message: PixelMessage) {}
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
    
    /// The delegate object specified to receive property change events.
    public weak var delegate: PixelDelegate?;

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
    /// - Remark: Call ``reportRssi(activate:minimumInterval:)`` to start monitoring RSSI.
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
        // TODO implement connection timeout
        // First connect to the peripheral
        try await withCheckedThrowingContinuation { (cont: VCC) in
            _peripheral.queueConnect(withServices: [PixelBleUuids.service]) { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }

        // Then prepare our instance for communications with the Pixel
        if status == .connecting {
            // Notify we're connected and proceeding to die identification
            setStatus(.identifying)

            do {
                // Setup our instance
                try await internalSetup()

                // Contact Pixel to retreive info
                _ = try await sendMessage(ofType: .whoAreYou, andWaitForResponse: .iAmADie)

                // Update status
                if status == .identifying {
                    print("Pixel \(name) is connected and ready")
                    setStatus(.ready)
                }
            } catch {
                // Disconnect but ignore any error
                try? await disconnect()
                throw error
            }
        } else if status == .identifying {
            // TODO connection timeout + subscribe to status changes instead of polling
            while true {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                if status != .identifying {
                    break
                }
            }
        }
        
        // Check if a status change occurred during the connection process
        if status != .ready {
            throw PixelError.connectionCanceled
        }
    }
    
    /// Cancel all on-going requests and immediately disconnects the Pixel.
    public func disconnect() async throws {
        let pixelName = name
        try await withCheckedThrowingContinuation { (cont: VCC) in
            // Cancel on-going requests
            _peripheral.cancelAll()
            // And disconnect
            _peripheral.queueDisconnect() { error in
                if let error {
                    print("Pixel \(pixelName) error: on disconnection, got \(error)")
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
    public func reportRSSI(activate: Bool = true, minimumInterval: Int = 5000) async throws {
        try await sendMessage(RequestRSSI(requestMode: activate ? .automatic : .off, minInterval: UInt16(minimumInterval)))
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
            setStatus(.connecting)
            break
        case .connected:
            fallthrough
        case .ready:
            // The setup is done directly in the connect() function since
            // we don't have an auto-reconnect feature (yet)
            break
        case .failedToConnect:
            print("Pixel \(name) error: failed to connect with reason \(reason)")
            fallthrough
        case .disconnecting:
            fallthrough
        case .disconnected:
            print("Pixel \(name) disconnected")
            setStatus(.disconnected)
            break
        @unknown default:
            fatalError()
        }
    }
    
    /// Update status property and notify delegate
    private func setStatus(_ status: PixelStatus) {
        if self.status != status {
            // Update status
            self.status = status
            // And notify delegate
            delegate?.pixel(self, didChangeStatus: status)
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
            let pixelName = name
            try await withCheckedThrowingContinuation { (cont: VCC) in
                _peripheral.queueSetNotifyValue(for: notify) { [weak self] characteristic, error in
                    if let error {
                        print("Pixel \(pixelName) error: on notified value, got \(error)")
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
        try await send(data)
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
                    // Send message to pub
                    _messagesPublisher.send(msg)
                    // And notify delegate
                    delegate?.pixel(self, didReceiveMessage: msg)
                } else {
                    print("Pixel \(name) error: unknown message type is \(data[0])")
                }
            }
            else if let msg = Pixel.decodeMessage(data: data) {
                switch (msg){
                case let iAmADie as IAmADie:
                    let newFwDate = Date(timeIntervalSince1970: TimeInterval(iAmADie.buildTimestamp))
                    let dateChanged = firmwareDate != newFwDate
                    let levelChanged = batteryLevel != iAmADie.batteryLevelPercent
                    let newIsCharging = Pixel.isChargingOrDone(iAmADie.batteryState)
                    let chargingChanged = isCharging != newIsCharging
                    // Update properties
                    pixelId = iAmADie.pixelId
                    ledCount = Int(iAmADie.ledCount)
                    designAndColor = iAmADie.designAndColor
                    firmwareDate = newFwDate
                    batteryLevel = Int(iAmADie.batteryLevelPercent)
                    isCharging = Pixel.isChargingOrDone(iAmADie.batteryState)
                    rollState = iAmADie.rollState
                    currentFace = Int(iAmADie.currentFaceIndex + 1)
                    // And notify delegate
                    if dateChanged {
                        delegate?.pixel(self, didChangeFirmwareDate: firmwareDate)
                    }
                    if levelChanged {
                        delegate?.pixel(self, didChangeBatteryLevel: batteryLevel)
                    }
                    if chargingChanged {
                        delegate?.pixel(self, didChangeChargingState: isCharging)
                    }
                    // Skip sending roll state to delegate as we didn't get the data
                    // from an actual roll event
                    break
                case let roll as RollState:
                    // Update properties
                    currentFace = Int(roll.faceIndex) + 1
                    rollState = roll.state
                    // And always notify delegate of roll events
                    delegate?.pixel(self, didChangeRollState: rollState, withFace: currentFace)
                    if rollState == .onFace {
                        delegate?.pixel(self, didRollOnFace: currentFace)
                    }
                case let battery as BatteryLevel:
                    let levelChanged = batteryLevel != battery.levelPercent
                    let newIsCharging = Pixel.isChargingOrDone(battery.state)
                    let chargingChanged = isCharging != newIsCharging
                    // Update properties
                    batteryLevel = Int(battery.levelPercent)
                    isCharging = newIsCharging
                    // And notify delegate
                    if levelChanged {
                        delegate?.pixel(self, didChangeBatteryLevel: batteryLevel)
                    }
                    if chargingChanged {
                        delegate?.pixel(self, didChangeChargingState: isCharging)
                    }
                    break
                case let rssiMsg as RSSI:
                    let changed = rssi != rssiMsg.value
                    // Update properties
                    rssi = Int(rssiMsg.value)
                    // And notify delegate
                    if changed {
                        delegate?.pixel(self, didChangeRSSI: rssi)
                    }
                    break
                default:
                    // Nothing to do
                    break
                }
                // Send message to pub
                _messagesPublisher.send(msg)
                // And notify delegate
                delegate?.pixel(self, didReceiveMessage: msg)
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
    
    private static func isChargingOrDone(_ state:PixelBatteryState) -> Bool {
       return state == .charging || state == .trickleCharge || state == .done
    }
}
