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
    }
    
    @inline(__always)
    fileprivate static func format(_ value: UInt8)->(id: Int, format: Format){
        let val = Int(value)
        let fmt = val & 0b111
        guard (0...2).contains(fmt) || fmt == 5 else {fatalError("illegal format \(value)")}
        return (id: val >> 3, format: Format(rawValue: fmt)!)
    }
    @inline(__always)
    fileprivate static func tag(_ id: Int, format: Format)->UInt8{
        let fmt = format.rawValue
        guard (0...2).contains(fmt) || fmt == 5 else {fatalError("illegal format \(format)")}
        return UInt8(id << 3 | fmt)
    }
    @inline(__always)
    fileprivate static func varintDecode<T: FixedWidthInteger & BinaryInteger>(_ data: Data)->T{
        var offset = 0
        var res = T(data[data.indices.lowerBound + offset])
        while (data[data.indices.lowerBound + offset] & 0x80) != 0 {
            offset += 1
            res |= T(data[data.indices.lowerBound + offset] & 0x7f) << (offset * 7)
        }
        return res
    }
    @inline(__always)
    fileprivate static func varintEncode<T: FixedWidthInteger & BinaryInteger>(_ value: T)->Data{
        let val = value >= 0 ? UInt64(value) : UInt64(bitPattern: Int64(value))
        let low = UInt64(0x7f)
        let high = UInt64.max - low
        var offset = UInt64(0)
        var next = val & (high << (offset * 7)) > 0
        var data = Data([UInt8(((val & (low << (offset * 7))) >> (offset * 7)) | (next ? 0x80 : 0))])
        while next {
            offset += 1
            next = val & (high << (offset * 7)) > 0
            data.append(UInt8(((val & (low << (offset * 7))) >> (offset * 7)) | (next ? 0x80 : 0)))
        }
        return data
    }
    fileprivate static func varintsDecode<T: FixedWidthInteger & BinaryInteger>(_ data: Data)->[T]{
        var offset = 0
        var arr = [T]()
        while offset < data.indices.upperBound{
            var val = T(data[data.indices.lowerBound + offset])
            while (data[data.indices.lowerBound + offset] & 0x80) != 0 {
                offset += 1
                val |= T(data[data.indices.lowerBound + offset] & 0x7f) << (offset * 7)
            }
            arr.append(val)
            offset += 1
        }
        return arr
    }
    @inline(__always)
    fileprivate static func zigZagEncode<T: FixedWidthInteger & SignedInteger>(_ value: T)->T{
        return (value << 1) ^ (value >> T.bitWidth - 1)
    }
    @inline(__always)
    fileprivate static func zigZagDecode<T: FixedWidthInteger & SignedInteger>(_ value: T)->T{
        return (value >> 1) ^ -(value & 1)
    }
    @inline(__always)
    fileprivate static func float<T: FixedWidthInteger & BinaryInteger, R>(_ value: T)->R{
        var res = value
        return withUnsafePointer(to: &res){
            $0.withMemoryRebound(to: R.self, capacity: 1){
                $0.pointee
            }
        }
    }
    @inline(__always)
    fileprivate static func bytes<T>(_ value: T)->Data{
        var res = value
        return withUnsafePointer(to: &res){
            $0.withMemoryRebound(to: UInt8.self, capacity: 1){
                Data(bytes: $0, count: MemoryLayout<T>.size)
            }
        }
    }
    public static func test(){
        var arr: [UInt8] = [0xa4,0x70,0x9d,0x3f]
        
        let an1 = Animal()
//        an1.weight = 0
//        an1.price = 0
//        an1.namme = "cat"
        
        var dat = Data([0xee,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x01])
        let val = PBUtils.varintDecode(dat) as Int64
//        print(String.init(UInt64(bitPattern: val), radix: 16))
        
//        print(dat as NSData)
//        let data = an1.delimitedData()
//        print(data as NSData)
//        let ptr = PBDecoder(data, first: true)
//        print(ptr.float(1))
//        print(ptr.double(2))
//        print(ptr.string(3))
        
        let per = Person()
        per.name = ""//"frank"
//        per.age = -18
//        per.deviceType = .ios
        
        let an2 = Animal()
//        an2.weight = 4.2
//        an2.price = 5.67
//        an2.namme = "dog"
        
        let encoder = PBEncoder(true)
//        encoder.set(string: "frank", id: 1)
//        encoder.set(int32: -18, id: 2)
        
        per.animalsArray = [an1, an2]
        
        let data1 = per.delimitedData()
        let data = encoder.result
        let p = PBDecoder(data1, package: true)
//        print(p.string(1))
//        print(p.int32(2))
        print(data1 as NSData)
        p.datas(5).map{
            let pp = PBDecoder($0)
            print(pp.float(1))
            print(pp.double(2))
        }
       print(p.datas(5))
    }
}

public final class PBEncoder {
    fileprivate var data: Data
    fileprivate let package: Bool
    
    public var result: Data {return data.count == 0 ? Data([0]) : (package ? [UInt8(data.count)] : []) + data}
    public init(_ package: Bool = false){
        self.package = package
        data = Data()
    }
    public func set(bool: Bool, id: Int){
        if bool {
            data += [PBUtils.tag(id, format: .varint), 1]
        }
    }
    public func set(int32: Int32, id: Int){
        if int32 != 0 {
            data += [PBUtils.tag(id, format: .varint)] + PBUtils.varintEncode(int32)
        }
    }
    public func set(uint32: UInt32, id: Int){
        if uint32 != 0{
            data += [PBUtils.tag(id, format: .varint)] + PBUtils.varintEncode(uint32)
        }
    }
    public func set(sint32: Int32, id: Int){
        if sint32 != 0{
            data += [PBUtils.tag(id, format: .varint)] + PBUtils.varintEncode(PBUtils.zigZagEncode(sint32))
        }
    }
    public func set(int64: Int64, id: Int){
        if int64 != 0{
            data += [PBUtils.tag(id, format: .varint)] + PBUtils.varintEncode(int64)
        }
    }
    public func set(uint64: UInt64, id: Int){
        if uint64 != 0{
            data += [PBUtils.tag(id, format: .varint)] + PBUtils.varintEncode(uint64)
        }
    }
    public func set(sint64: Int64, id: Int){
        if sint64 != 0{
            data += [PBUtils.tag(id, format: .varint)] + PBUtils.varintEncode(PBUtils.zigZagEncode(sint64))
        }
    }
    public func set(fixed32: UInt32, id: Int){
        if fixed32 != 0{
            data += [PBUtils.tag(id, format: .bit32)] + PBUtils.bytes(fixed32)
        }
    }
    public func set(sfixed32: Int32, id: Int){
        if sfixed32 != 0{
            data += [PBUtils.tag(id, format: .bit32)] + PBUtils.bytes(sfixed32)
        }
    }
    public func set(fixed64: UInt64, id: Int){
        if fixed64 != 0{
            data += [PBUtils.tag(id, format: .bit64)] + PBUtils.bytes(fixed64)
        }
    }
    public func set(sfixed64: Int64, id: Int){
        if sfixed64 != 0{
            data += [PBUtils.tag(id, format: .bit64)] + PBUtils.bytes(sfixed64)
        }
    }
    public func set(float: Float, id: Int){
        if float != 0{
            data += [PBUtils.tag(id, format: .bit32)] + PBUtils.bytes(float)
        }
    }
    public func set(double: Double, id: Int){
        if double != 0{
            data += [PBUtils.tag(id, format: .bit64)] + PBUtils.bytes(double)
        }
    }
    public func set(string: String, id: Int){
        if string.count > 0{
            data += [PBUtils.tag(id, format: .bytes), UInt8(string.lengthOfBytes(using: .utf8))] + string.utf8
        }
    }
    public func set(data: Data, id: Int){
        if data.count > 0{
            self.data += [PBUtils.tag(id, format: .bytes), UInt8(data.count)] + data
        }
    }
    public func set(bools: [Bool], id: Int){
        if bools.count > 0 {
            data += [PBUtils.tag(id, format: .bytes), UInt8(bools.count)] + bools.map{$0 ? 1 : 0}
        }
    }
    public func set(int32s: [Int32], id: Int){
        if int32s.count > 0 {
            let d = int32s.reduce(Data()){$0 + PBUtils.varintEncode($1)}
            data += [PBUtils.tag(id, format: .bytes), UInt8(d.count)] + d
        }
    }
    public func set(uint32s: [UInt32], id: Int){
        if uint32s.count > 0{
            let d = uint32s.reduce(Data()){$0 + PBUtils.varintEncode($1)}
            data += [PBUtils.tag(id, format: .bytes), UInt8(d.count)] + d
        }
    }
    public func set(int64s: [Int64], id: Int){
        if int64s.count > 0 {
            let d = int64s.filter{$0 != 0}.reduce(Data()){$0 + PBUtils.varintEncode($1)}
            data += [PBUtils.tag(id, format: .bytes), UInt8(d.count)] + d
        }
    }
    public func set(uint64s: [UInt64], id: Int){
        if uint64s.count > 0 {
            let d = uint64s.filter{$0 != 0}.reduce(Data()){$0 + PBUtils.varintEncode($1)}
            data += [PBUtils.tag(id, format: .bytes), UInt8(d.count)] + d
        }
    }
}

public final class PBDecoder {
    fileprivate let data: Data
    fileprivate let tags: [Int: (id: Int, format: PBUtils.Format)]
    
    init(_ data: Data, package: Bool = false) {
        self.data = data
        var arr = [Int: (Int, PBUtils.Format)]()
        var offset = self.data.indices.lowerBound + (package ? 1 : 0)
        while offset < self.data.indices.upperBound {
            let fmt = PBUtils.format(self.data[offset])
            arr[offset] = fmt
            switch fmt.format{
            case .varint:
                offset += 1
                while self.data[offset] >= 0x80{
                    offset += 1
                }
                offset += 1
            case .bit64: offset += 8 + 1
            case .bytes: offset += Int(self.data[offset + 1]) + 2
            case .bit32: offset += 4 + 1
            default:
                fatalError("illegal format \(offset + (package ? 1 : 0))")
            }
        }
        tags = arr
    }
    
    public func bool(_ id: Int)-> Bool?{
        return tags.first{$0.value.id == id && $0.value.format == .varint}.map{data[$0.key + 1] != 0}
    }
    public func int32(_ id: Int)-> Int32?{
        return tags.first{$0.value.id == id && $0.value.format == .varint}.map{PBUtils.varintDecode(data[($0.key + 1)...])}
    }
    public func uint32(_ id: Int)-> UInt32?{
        return tags.first{$0.value.id == id && $0.value.format == .varint}.map{PBUtils.varintDecode(data[($0.key + 1)...])}
    }
    public func sint32(_ id: Int)-> Int32?{
        return tags.first{$0.value.id == id && $0.value.format == .varint}.map{PBUtils.zigZagDecode(PBUtils.varintDecode(data[($0.key + 1)...]))}
    }
    public func int64(_ id: Int)-> Int64?{
        return tags.first{$0.value.id == id && $0.value.format == .varint}.map{PBUtils.varintDecode(data[($0.key + 1)...])}
    }
    public func uint64(_ id: Int)-> UInt64?{
        return tags.first{$0.value.id == id && $0.value.format == .varint}.map{PBUtils.varintDecode(data[($0.key + 1)...])}
    }
    public func sint64(_ id: Int)-> Int64?{
        return tags.first{$0.value.id == id && $0.value.format == .varint}.map{PBUtils.zigZagDecode(PBUtils.varintDecode(data[($0.key + 1)...]))}
    }
    public func fixed32(_ id: Int)-> UInt32?{
        return tags.first{$0.value.id == id && $0.value.format == .bit32}.map{data[($0.key + 1)...].withUnsafeBytes{$0.pointee}}
    }
    public func sfixed32(_ id: Int)-> Int32?{
        return tags.first{$0.value.id == id && $0.value.format == .bit32}.map{data[($0.key + 1)...].withUnsafeBytes{$0.pointee}}
    }
    public func fixed64(_ id: Int)-> UInt64?{
        return tags.first{$0.value.id == id && $0.value.format == .bit64}.map{data[($0.key + 1)...].withUnsafeBytes{$0.pointee}}
    }
    public func sfixed64(_ id: Int)-> Int64?{
        return tags.first{$0.value.id == id && $0.value.format == .bit64}.map{data[($0.key + 1)...].withUnsafeBytes{$0.pointee}}
    }
    public func float(_ id: Int)-> Float?{
        return tags.first{$0.value.id == id && $0.value.format == .bit32}.map{PBUtils.float(data[($0.key + 1)...].withUnsafeBytes{$0.pointee as UInt32})}
    }
    public func double(_ id: Int)-> Double?{
        return tags.first{$0.value.id == id && $0.value.format == .bit64}.map{PBUtils.float(data[($0.key + 1)...].withUnsafeBytes{$0.pointee as UInt32})}
    }
    public func string(_ id: Int)->String?{
        return tags.first(where: {$0.value.id == id && $0.value.format == .bytes}).flatMap{String(bytes: data[($0.key + 2)..<($0.key + 2 + Int(data[$0.key + 1]))], encoding: .utf8)}
    }
    public func data(_ id: Int)->Data?{
        return tags.first(where: {$0.value.id == id && $0.value.format == .bytes}).flatMap{data[($0.key + 2)..<($0.key + 2 + Int(data[$0.key + 1]))]}
    }
    public func bools(_ id: Int)-> [Bool]{
        return data(id)?.map{$0 != 0} ?? []
    }
    public func int32s(_ id: Int)-> [Int32]{
        return data(id).map{PBUtils.varintsDecode($0)} ?? []
    }
    public func uint32s(_ id: Int)-> [Int32]{
        return data(id).map{PBUtils.varintsDecode($0)} ?? []
    }
    public func int64s(_ id: Int)-> [Int64]{
        return data(id).map{PBUtils.varintsDecode($0)} ?? []
    }
    public func uint64s(_ id: Int)-> [Int64]{
        return data(id).map{PBUtils.varintsDecode($0)} ?? []
    }
    public func floats(_ id: Int)-> [Float]{
        return tags.filter{$0.value.id == id && $0.value.format == .bit32}.map{PBUtils.float(data[($0.key + 1)...].withUnsafeBytes{$0.pointee as UInt32})}
    }
    public func doubles(_ id: Int)-> [Double]{
        return tags.filter{$0.value.id == id && $0.value.format == .bit64}.map{PBUtils.float(data[($0.key + 1)...].withUnsafeBytes{$0.pointee as UInt64})}
    }
    public func strings(_ id: Int)-> [String]{
        #if swift(>=4.1)
            return tags.filter{$0.value.id == id && $0.value.format == .bytes}.compactMap{String(bytes: data[($0.key + 2)..<($0.key + 2 + Int(data[$0.key + 1]))], encoding: .utf8)}
        #else
            return tags.filter{$0.value.id == id && $0.value.format == .bytes}.flatMap{String(bytes: data[($0.key + 2)..<($0.key + 2 + Int(data[$0.key + 1]))], encoding: .utf8)}
        #endif
    }
    public func datas(_ id: Int)-> [Data]{
        #if swift(>=4.1)
            return tags.filter{$0.value.id == id && $0.value.format == .bytes}.compactMap{data[($0.key + 2)..<($0.key + 2 + Int(data[$0.key + 1]))]}
        #else
            return tags.filter{$0.value.id == id && $0.value.format == .bytes}.flatMap{data[($0.key + 2)..<($0.key + 2 + Int(data[$0.key + 1]))]}
        #endif
    }
}
