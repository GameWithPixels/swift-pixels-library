//
//  BinaryDecoder.swift
//  PixelsLibrary
//
//  Created by Olivier on 23.03.23.
//

import Foundation

/// Binary decoder.
/// Inspired by https://www.mikeash.com/pyblog/friday-qa-2017-07-28-a-binary-coder-for-swift.html
class BinaryDecoder: Decoder {
    private let data: Data
    private var offset = 0

    /// Convenience function for creating an decoder, decoding some data, and
    /// populating a value of the given type.
    static func decode<T: Decodable>(_ type: T.Type, data: Data) throws -> T {
        return try BinaryDecoder(data: data).decode(T.self)
    }

    init(data: Data) {
        self.data = data
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
      switch type {
        case is Bool.Type:
          return read(false) as! T
        case is Int8.Type:
          return read(0 as Int8) as! T
        case is Int16.Type:
          return read(0 as Int16) as! T
        case is Int32.Type:
          return read(0 as Int32) as! T
        case is Int64.Type:
          return read(0 as Int64) as! T
        case is UInt8.Type:
          return read(0 as UInt8) as! T
        case is UInt16.Type:
          return read(0 as UInt16) as! T
        case is UInt32.Type:
          return read(0 as UInt32) as! T
        case is UInt64.Type:
          return read(0 as UInt64) as! T
        case is Float32.Type:
          return read(0 as Float32) as! T
        case is Float64.Type:
          return read(0 as Float64) as! T
        default:
          return try type.init(from: self)
      }
    }

    private func read<T: Decodable>(_ value: T) -> T {
      var v = value
      offset += withUnsafeMutableBytes(of: &v) { data.copyBytes(to: $0, from: offset..<data.count)}
      return v
    }

    // Decoder protocol
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]

    func container<Key>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer<Key>(KeyedContainer<Key>(decoder: self))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return UnkeyedContainer(decoder: self)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UnkeyedContainer(decoder: self)
    }
}

fileprivate struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    var decoder: BinaryDecoder
    var codingPath: [CodingKey] { return [] }
    var allKeys: [Key] { return [] }

    func contains(_ key: Key) -> Bool {
        return true
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        return try decoder.decode(T.self)
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        return true
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        return try decoder.container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try decoder.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        return decoder
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        return decoder
    }
}

fileprivate struct UnkeyedContainer: UnkeyedDecodingContainer, SingleValueDecodingContainer {
    var decoder: BinaryDecoder
    var codingPath: [CodingKey] { return [] }
    var count: Int? { return nil }
    var currentIndex: Int { return 0 }
    var isAtEnd: Bool { return false }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        return try decoder.decode(type)
    }

    func decodeNil() -> Bool {
        return true
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        return try decoder.container(keyedBy: type)
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return self
    }

    func superDecoder() throws -> Decoder {
        return decoder
    }
}
