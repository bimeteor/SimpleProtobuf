//
//  InputStream.swift
//  Tan_ProtocolBuffer
//
//  Created by WG on 2018/4/27.
//  Copyright © 2018年 mac001. All rights reserved.
//

import Foundation

@objcMembers
public final class PBUtils: NSObject{
    fileprivate enum Format: Int{
        case varint, bit64, bytes, start, stop, bit32
        fileprivate var description: String{
            switch self {
            case .varint: return "varint"
            case .bit32: return "bit32"
            case .bit64: return "bit64"
            case .bytes: return "bytes"
            default: return "error"
            }
        }
    }
    @inline(__always)
    fileprivate static func varintEncode<T: FixedWidthInteger & BinaryInteger>(_ value: T)->Data{
        let val: UInt
        switch value{
        case is Int, is Int64: val = UInt(bitPattern: Int(value))
        case is Int32: val = UInt(UInt32(bitPattern: value as! Int32))
        default: val = UInt(value)
        }
        let low = UInt(0x7f)
        let high = UInt.max - low
        var offset = UInt(0)
        var next = val & (high << (offset * 7)) > 0
        var data = Data([UInt8(((val & (low << (offset * 7))) >> (offset * 7)) | (next ? 0x80 : 0))])
        while next {
            offset += 1
            next = val & (high << (offset * 7)) > 0
            data.append(UInt8(((val & (low << (offset * 7))) >> (offset * 7)) | (next ? 0x80 : 0)))
        }
        return data
    }
    @inline(__always)
    fileprivate static func varintDecode(_ data: Data)->(value: UInt64, size: Int){
        var offset = 0
        var res = UInt64(data[data.indices.lowerBound + offset] & 0x7f)
        while (data[data.indices.lowerBound + offset] & 0x80) != 0 {
            offset += 1
            res |= UInt64(data[data.indices.lowerBound + offset] & 0x7f) << (offset * 7)
        }
        return (res, offset + 1)
    }
    fileprivate static func varintsDecode(_ data: Data)->[UInt64]{
        var offset = 0
        var arr = [UInt64]()
        while data.indices.lowerBound + offset < data.indices.upperBound {
            let res = varintDecode(data[(data.indices.lowerBound + offset)...])
            arr.append(res.value)
            offset += res.size
        }
        return arr
    }
    @inline(__always)
    fileprivate static func formatEncode(_ id: Int, format: Format)->Data{
        return varintEncode(id << 3 | format.rawValue)
    }
    @inline(__always)
    fileprivate static func formatDecode(_ data: Data)->(id: Int, format: Format, value: UInt64, range: CountableRange<Int>)?{
        let format = varintDecode(data[data.indices.lowerBound...])
        let key = Int(format.value)
        let type = Format(rawValue: key & 0b111) ?? .start
        switch type {
        case .bit32: return (key >> 3, type, data[(data.indices.lowerBound + format.size)...].withUnsafeBytes{UInt64($0.pointee as UInt32)}, (data.indices.lowerBound + format.size)..<(data.indices.lowerBound + format.size + 4))
        case .bit64: return (key >> 3, type, data[(data.indices.lowerBound + format.size)...].withUnsafeBytes{$0.pointee}, (data.indices.lowerBound + format.size)..<(data.indices.lowerBound + format.size + 8))
        case .varint:
            let value = varintDecode(data[(data.indices.lowerBound + format.size)...])
            return (key >> 3, type, value.value, (data.indices.lowerBound + format.size)..<(data.indices.lowerBound + format.size + value.size))
        case .bytes:
            let len = varintDecode(data[(data.indices.lowerBound + format.size)...])
            return (key >> 3, type, 0, (data.indices.lowerBound + format.size + len.size)..<(data.indices.lowerBound + format.size + len.size + Int(len.value)))
        default:
            print("error:", data.indices.lowerBound, String(data[data.indices.lowerBound], radix: 16))
            return nil
        }
    }
    @inline(__always)
    fileprivate static func zigZagEncode(_ value: Int32)->UInt32{
        return UInt32(bitPattern: (value << 1) ^ (value >> 31))
    }
    @inline(__always)
    fileprivate static func zigZagEncode(_ value: Int64)->UInt64{
        return UInt64(bitPattern: (value << 1) ^ (value >> 63))
    }
    @inline(__always)
    fileprivate static func zigZagDecode<T: FixedWidthInteger & UnsignedInteger, R: FixedWidthInteger & SignedInteger>(_ value: T)->R{
        return R(value >> 1) ^ R(0 - (value & 1))
    }
    @inline(__always)
    fileprivate static func bytes<T>(_ value: T)->Data{
        var res = value
        return withUnsafePointer(to: &res){
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size / 8){
                Data(bytes: $0, count: MemoryLayout<T>.size)
            }
        }
    }
    @inline(__always)
    fileprivate static func numbers<T>(_ data: Data)->[T]{
        return data.withUnsafeBytes{ptr in (0..<(data.indices.count * 8 / MemoryLayout<T>.size)).map{(ptr + $0).pointee}}
    }
    public static func encode(){
        let per = PBEncoder(true)
        per.set(string: "frank", id: 1)
        per.set(int32: -18, id: 2)
        per.set(int32: 0, id: 3)
        
        let an1 = PBEncoder()
        an1.set(float: 1.1, id: 1)
        an1.set(double: 2.2, id: 2)
        an1.set(string: "cat", id: 3)
        
        let an2 = PBEncoder()
        an2.set(float: 3.3, id: 1)
        an2.set(double: 4.4, id: 2)
        an2.set(string: "dog", id: 3)
        per.set(datas: [an1.result, an2.result], id: 5)
        
        let data = per.result
        print(data as NSData)
        let st = GPBCodedInputStream.init(data: data)
        if let p = try? Person.parseDelimited(from: st, extensionRegistry: nil){
            print(222, dump(p))
        }
    }
    public static func decode(){
        let an1 = Animal()
        an1.weight = 1.1
        an1.price = 2.2
        an1.namme = "cat"
        
        let an2 = Animal()
        an2.weight = 3.3
        an2.price = 4.4
        an2.namme = "dog"
        
        let per = Person()
        per.name = "frank"
        per.age = -18
        per.deviceType = .ios
        per.animalsArray = [an1, an2]
        
        let data = per.delimitedData()
        print(data as NSData)
        
        
        guard let p = PBDecoder(data, package: true) else {return}
        print(p.string(1))
        print(p.int32(2))
        p.datas(5).map{
            guard let pp = PBDecoder($0) else {return}
            print(pp.float(1))
            print(pp.double(2))
            print(pp.string(3))
        }
        print(p)
    }
    public static func test(){
        encode()
        print("=============")
        decode()
    }
}

public final class PBEncoder {
    fileprivate var data = Data()
    fileprivate let package: Bool
    public var result: Data {return data.count == 0 ? Data([0]) : (package ? PBUtils.varintEncode(data.count) : Data()) + data}
    public init(_ package: Bool = false){
        self.package = package
    }
    public func set(bool: Bool, id: Int){
        if bool{
            data += PBUtils.formatEncode(id, format: .varint) + Data([1])
        }
    }
    public func set(int32: Int32, id: Int){
        set(uint32: UInt32(bitPattern: int32), id: id)
    }
    public func set(uint32: UInt32, id: Int){
        set(uint64: UInt64(uint32), id: id)
    }
    public func set(sint32: Int32, id: Int){
        set(uint32: PBUtils.zigZagEncode(sint32), id: id)
    }
    public func set(int64: Int64, id: Int){
        set(uint64: UInt64(bitPattern: int64), id: id)
    }
    public func set(uint64: UInt64, id: Int){
        if uint64 != 0{
            data += PBUtils.formatEncode(id, format: .varint) + PBUtils.varintEncode(uint64)
        }
    }
    public func set(sint64: Int64, id: Int){
        set(uint64: PBUtils.zigZagEncode(sint64), id: id)
    }
    public func set(fixed32: UInt32, id: Int){
        if fixed32 != 0{
            data += PBUtils.formatEncode(id, format: .bit32) + PBUtils.bytes(fixed32)
        }
    }
    public func set(sfixed32: Int32, id: Int){
        set(fixed32: UInt32(bitPattern: sfixed32), id: id)
    }
    public func set(fixed64: UInt64, id: Int){
        if fixed64 != 0{
            data += PBUtils.formatEncode(id, format: .bit64) + PBUtils.bytes(fixed64)
        }
    }
    public func set(sfixed64: Int64, id: Int){
        set(fixed64: UInt64(bitPattern: sfixed64), id: id)
    }
    public func set(float: Float, id: Int){
        set(fixed32: float.bitPattern, id: id)
    }
    public func set(double: Double, id: Int){
        set(fixed64: double.bitPattern, id: id)
    }
    public func set(string: String, id: Int){
        string.data(using: .utf8).map{set(data: $0, id: id)}
    }
    public func set(data: Data, id: Int){
        if data.count > 0 && data != Data([0]){
            self.data += PBUtils.formatEncode(id, format: .bytes) + PBUtils.varintEncode(data.count) + data
        }
    }
    public func set(bools: [Bool], id: Int){
        set(data: Data(bools.map{$0 ? 1 : 0}), id: id)
    }
    public func set(int32s: [Int32], id: Int){
        set(uint32s: int32s.map{UInt32(bitPattern: $0)}, id: id)
    }
    public func set(uint32s: [UInt32], id: Int){
        set(uint64s: uint32s.map{UInt64($0)}, id: id)
    }
    public func set(sint32s: [Int32], id: Int){
        set(uint32s: sint32s.map{PBUtils.zigZagEncode($0)}, id: id)
    }
    public func set(int64s: [Int64], id: Int){
        set(uint64s: int64s.map{UInt64(bitPattern: $0)}, id: id)
    }
    public func set(uint64s: [UInt64], id: Int){
        set(data: Data(uint64s.flatMap{PBUtils.varintEncode($0)}), id: id)
    }
    public func set(sint64s: [Int64], id: Int){
        set(uint64s: sint64s.map{PBUtils.zigZagEncode($0)}, id: id)
    }
    public func set(fixed32s: [UInt32], id: Int){
        set(data: Data(fixed32s.flatMap{PBUtils.bytes($0)}), id: id)
    }
    public func set(sfixed32s: [Int32], id: Int){
        set(fixed32s: sfixed32s.map{UInt32(bitPattern: $0)}, id: id)
    }
    public func set(fixed64s: [UInt64], id: Int){
        set(data: Data(fixed64s.flatMap{PBUtils.bytes($0)}), id: id)
    }
    public func set(sfixed64s: [Int64], id: Int){
        set(fixed64s: sfixed64s.map{UInt64(bitPattern: $0)}, id: id)
    }
    public func set(floats: [Float], id: Int){
        set(data: Data(floats.flatMap{PBUtils.bytes($0)}), id: id)
    }
    public func set(doubles: [Double], id: Int){
        set(data: Data(doubles.flatMap{PBUtils.bytes($0)}), id: id)
    }
    public func set(strings: [String], id: Int){
        strings.forEach{ set(string: $0, id: id) }
    }
    public func set(datas: [Data], id: Int){
        datas.forEach{ set(data: $0, id: id) }
    }
}

public final class PBDecoder: NSObject {
    fileprivate let data: Data
    fileprivate let tags: [(id: Int, format: PBUtils.Format, value: UInt64, range: CountableRange<Int>)]
    
    init?(_ data: Data, package: Bool = false) {
        self.data = data
        var arr = type(of: tags).init()
        var offset = self.data.indices.lowerBound + (package ? PBUtils.varintDecode(self.data).size : 0)
        while offset < self.data.indices.upperBound {
            guard let fmt = PBUtils.formatDecode(self.data[offset...]) else {return nil}
            arr.append(fmt)
            offset = fmt.range.upperBound
        }
        tags = arr
        super.init()
    }
    
    override public var description: String {
        return tags.reduce(""){
            $0 + "id: \($1.id), format: \($1.format), value: \(String($1.value, radix: 16)), range: \($1.range)\n"
        }
    }
    
    public func bool(_ id: Int)-> Bool?{
        return uint64(id).map{$0 != 0}
    }
    public func int32(_ id: Int)-> Int32?{
        return int64(id).map{Int32($0)}
    }
    public func uint32(_ id: Int)-> UInt32?{
        return uint64(id).map{UInt32($0)}
    }
    public func sint32(_ id: Int)-> Int32?{
        return uint32(id).map{PBUtils.zigZagDecode($0)}
    }
    public func int64(_ id: Int)-> Int64?{
        return uint64(id).map{Int64(bitPattern: $0)}
    }
    public func uint64(_ id: Int)-> UInt64?{
        return tags.first{$0.id == id && $0.format == .varint}.map{$0.value}
    }
    public func sint64(_ id: Int)-> Int64?{
        return uint64(id).map{PBUtils.zigZagDecode($0)}
    }
    public func fixed32(_ id: Int)-> UInt32?{
        return tags.first{$0.id == id && $0.format == .bit32}.map{UInt32($0.value)}
    }
    public func sfixed32(_ id: Int)-> Int32?{
        return fixed32(id).map{Int32(bitPattern: $0)}
    }
    public func fixed64(_ id: Int)-> UInt64?{
        return tags.first{$0.id == id && $0.format == .bit64}.map{$0.value}
    }
    public func sfixed64(_ id: Int)-> Int64?{
        return fixed64(id).map{Int64(bitPattern: $0)}
    }
    public func float(_ id: Int)-> Float?{
        return fixed32(id).map{Float(bitPattern: $0)}
    }
    public func double(_ id: Int)-> Double?{
        return fixed64(id).map{Double(bitPattern: $0)}
    }
    public func string(_ id: Int)->String?{
        return data(id).flatMap{String(bytes: $0, encoding: .utf8)}
    }
    public func data(_ id: Int)->Data?{
        return tags.first{$0.id == id && $0.format == .bytes}.map{data[$0.range]}
    }
    public func bools(_ id: Int)-> [Bool]{
        return data(id)?.map{$0 != 0} ?? []
    }
    public func int32s(_ id: Int)-> [Int32]{
        return uint32s(id).map{Int32(bitPattern: $0)}
    }
    public func uint32s(_ id: Int)-> [UInt32]{
        return uint64s(id).map{UInt32($0)}
    }
    public func sint32s(_ id: Int)-> [Int32]{
        return uint32s(id).map{PBUtils.zigZagDecode($0)}
    }
    public func int64s(_ id: Int)-> [Int64]{
        return uint64s(id).map{Int64(bitPattern: $0)}
    }
    public func uint64s(_ id: Int)-> [UInt64]{
        return data(id).map{PBUtils.varintsDecode($0)} ?? []
    }
    public func sint64s(_ id: Int)-> [Int64]{
        return uint64s(id).map{PBUtils.zigZagDecode($0)}
    }
    public func fixed32s(_ id: Int)-> [UInt32]{
        return data(id).map{PBUtils.numbers($0)} ?? []
    }
    public func sfixed32s(_ id: Int)-> [Int32]{
        return data(id).map{PBUtils.numbers($0)} ?? []
    }
    public func fixed64s(_ id: Int)-> [UInt64]{
        return data(id).map{PBUtils.numbers($0)} ?? []
    }
    public func sfixed64s(_ id: Int)-> [Int64]{
        return data(id).map{PBUtils.numbers($0)} ?? []
    }
    public func floats(_ id: Int)-> [Float]{
        return data(id).map{PBUtils.numbers($0)} ?? []
    }
    public func doubles(_ id: Int)-> [Double]{
        return data(id).map{PBUtils.numbers($0)} ?? []
    }
    public func strings(_ id: Int)-> [String]{
        return datas(id).map{String(bytes: $0, encoding: .utf8) ?? ""}
    }
    public func datas(_ id: Int)-> [Data]{
        return tags.filter{$0.id == id && $0.format == .bytes}.map{data[$0.range]}
    }
}
