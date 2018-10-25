/*
 Copyright (c) 2018 Bell App Lab <apps@bellapplab.com>

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import Foundation


struct OrderedDictionary<Key: Hashable, Value>: ExpressibleByDictionaryLiteral
{
    fileprivate var objects: [Key: Value] = [:]
    fileprivate var indices: [Int: Key] = [:]
    
    init() {}
    
    init(dictionaryLiteral elements: (Key, Value)...) {
        elements.enumerated().forEach {
            objects[$0.element.0] = $0.element.1
            indices[$0.offset] = $0.element.0
        }
    }
    
    fileprivate init(objects: [Key: Value], indices: [Int: Key]) {
        self.init()
        self.objects = objects
        self.indices = indices
    }

    fileprivate init(objects: [(Key, Value)], indices: [(Int, Key)]) {
        self.init()
        objects.forEach { self.objects[$0] = $1 }
        indices.forEach { self.indices[$0] = $1 }
    }
    
    mutating func set(_ value: Value, for key: Key) {
        guard objects[key] == nil else {
            objects[key] = value
            return
        }
        
        objects[key] = value
        indices[indices.count] = key
    }
    
    func key(at index: Int) -> Key? {
        return indices[index]
    }
    
    func indexOf(key: Key) -> Int? {
        return first(where: { $0.key == key })?.index
    }
    
    func value(for key: Key) -> Value? {
        return objects[key]
    }
    
    func value(at index: Int) -> Value? {
        precondition(index < count, "Index should be smaller than object count")
        precondition(index >= 0, "Index should be greater than 0")
        
        guard let key = indices[index] else {
            preconditionFailure("Index does not correspond to any keys in the dictionary")
        }
        
        return objects[key]
    }
    
    subscript(index: Int) -> Value? {
        return value(at: index)
    }
    
    mutating func updateValue(for key: Key, _ updating: (Value?) -> Value) {
        set(updating(value(for: key)), for: key)
    }
}


extension OrderedDictionary
{
    var count: Int { return objects.count }
    
    var isEmpty: Bool { return objects.isEmpty }
}


extension OrderedDictionary
{
    mutating func subtract(_ other: OrderedDictionary<Key, Value>) {
        self = subtracting(other)
    }
    
    func subtracting(_ other: OrderedDictionary<Key, Value>) -> OrderedDictionary<Key, Value> {
        let otherKeys = other.objects.keys
        let otherIndices = other.indices.keys
        return OrderedDictionary(objects: objects.filter { !otherKeys.contains($0.key) },
                                 indices: indices.filter { !otherIndices.contains($0.key) })
    }
}


extension OrderedDictionary
{
    typealias Iterator = (index: Int, key: Key, value: Value)

    func map<T>(_ iterator: (Iterator) -> T) -> [T] {
        return indices.lazy.sorted(by: { $0.key < $1.key }).map { iterator(($0.key, $0.value, objects[$0.value]!)) }
    }

    func compactMap<T>(_ iterator: (Iterator) -> T?) -> [T] {
        return indices.lazy.sorted(by: { $0.key < $1.key }).compactMap { iterator(($0.key, $0.value, objects[$0.value]!)) }
    }
    
    func first(where iterator: (Iterator) -> Bool) -> Iterator? {
        let sortedIndices = indices.lazy.sorted(by: { $0.key < $1.key })
        guard let (index, key) = sortedIndices.first(where: { iterator(($0.key, $0.value, objects[$0.value]!)) }) else { return nil }
        return (index, key, objects[key]!)
    }
    
    func loop(_ shouldContinueIterator: (Iterator) -> Bool) {
        for item in indices.lazy.sorted(by: { $0.key < $1.key }) {
            if !shouldContinueIterator((item.key, item.value, objects[item.value]!)) {
                break
            }
        }
    }
    
    func contains(where iterator: ((Iterator)) -> Bool) -> Bool {
        return first(where: iterator) != nil
    }
}
