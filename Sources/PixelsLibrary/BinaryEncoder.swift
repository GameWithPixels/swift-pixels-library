//
//  BinaryEncoder.swift
//  PixelsLibrary
//
//  Created by Olivier on 23.03.23.
//

import Foundation

/// Binary encoder.
/// Inspired by https://www.mikeash.com/pyblog/friday-qa-2017-07-28-a-binary-coder-for-swift.html
class BinaryEncoder: Encoder {
    var data = Data()

    /// Convenience function for creating an encoder, encoding a value, and
    /// extracting the resulting data.
    static func encode(_ value: Encodable) throws -> Data {
        let encoder = BinaryEncoder()
        try value.encode(to: encoder)
        return encoder.data
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        var v = value;
        withUnsafeBytes(of: &v) {
            let p = $0.assumingMemoryBound(to: T.self)
            data.append(p)
        }
    }

    // Encoder protocol
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]

    func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        return KeyedEncodingContainer<Key>(KeyedContainer<Key>(encoder: self))
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return UnkeyedContainer(encoder: self)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UnkeyedContainer(encoder: self)
    }
}

fileprivate struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var encoder: BinaryEncoder
    var codingPath: [CodingKey] { return [] }

    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        try encoder.encode(value)
    }

    func encodeNil(forKey key: Key) throws {}

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
     -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        return encoder.container(keyedBy: keyType)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return encoder.unkeyedContainer()
    }

    func superEncoder() -> Encoder {
        return encoder
    }

    func superEncoder(forKey key: Key) -> Encoder {
        return encoder
    }
}

fileprivate struct UnkeyedContainer: UnkeyedEncodingContainer, SingleValueEncodingContainer {
    var encoder: BinaryEncoder
    var codingPath: [CodingKey] { return [] }
    var count: Int { return 0 }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
     -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        return encoder.container(keyedBy: keyType)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return self
    }

    func superEncoder() -> Encoder {
        return encoder
    }

    func encodeNil() throws {}

    func encode<T>(_ value: T) throws where T : Encodable {
        try encoder.encode(value)
    }
}
