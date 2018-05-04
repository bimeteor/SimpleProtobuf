//
//  InputStream.swift
//  Tan_ProtocolBuffer
//
//  Created by WG on 2018/4/27.
//  Copyright © 2018年 mac001. All rights reserved.
//

import Foundation

@objcMembers
public class Utils: NSObject{
    fileprivate enum Format: Int{
        case varint, bit64, bytes, start, stop, bit32
    }
    
    @inline(__always)
    fileprivate static func format(_ value: UInt8)->(id: Int, format: Format){
        let val = Int(value)
        let fmt = val & 0b111
        guard (0...2).contains(fmt) || fmt == 5 else {fatalError("illegal format \(value)")}
        return (id: val >> 3, format: Format(rawValue: fmt) ?? .varint)
    }
    @inline(__always)
    fileprivate static func tag(_ id: Int, format: Format)->UInt8{
        let fmt = format.rawValue
        guard (0...2).contains(fmt) || fmt == 5 else {fatalError("illegal format \(format)")}
        return UInt8(id << 3 | fmt)
    }
    @inline(__always)
    fileprivate static func varintDecode(_ array: ArraySlice<UInt8>)->Int64{
        var offset = array.indices.lowerBound
        var res = Int64(array[offset])
        while array[offset] > 0x80 {
            res |= Int64(Int(array[offset] & 0x7f) << (offset * 7))
            offset += 1
        }
        return res
    }
//    @inline(__always)
//    fileprivate static func varintDecode(_ array: Int64)->[UInt8]{
//        var offset = 0
//        var res = Int64(array[0])
//        while array[offset] > 0x80 {
//            res |= Int64(Int(array[offset] & 0x7f) << (offset * 7))
//            offset += 1
//        }
//        return res
//    }
    @inline(__always)
    fileprivate static func zigZagEncode<T: FixedWidthInteger & SignedInteger>(_ value: T)->T{
        return (value << 1) ^ (value >> T.bitWidth - 1)
    }
    fileprivate static func zigZagDecode<T: FixedWidthInteger & SignedInteger>(_ value: T)->T{
        return (value >> 1) ^ -(value & 1)
    }
    public static func test(){
        let an1 = Animal()
        an1.weight = 1.2
        an1.price = 45.67
        an1.namme = "1234"
        
        let data = an1.delimitedData()
        print(data as NSData)
        let ptr = PBDecoder(data, first: true)
        print(ptr.float(1))
        print(ptr.double(2))
        print(ptr.string(3))
        
        let per = Person()
        per.name = "frank"
        per.age = 18
        per.deviceType = .ios
        
        let data1 = per.delimitedData()
        let p = PBDecoder(data1, first: true)
        print(p.string(1))
        print(p.int32(2))
    }
    
    public static func test1() {
//        var a: Float = 0.1234
//        withUnsafeMutablePointer(to: &a){
//            let ptr = unsafeBitCast($0, to: UnsafePointer<Int32>.self)
//
//            var val = ptr.pointee
//            print(String.init(val, radix: 16))
//            withUnsafeMutablePointer(to: &val){
//                let ptr = unsafeBitCast($0, to: UnsafePointer<Float>.self)
//                print(ptr.pointee)
//            }
//        }
//        withUnsafePointer(to: &a){
//            $0.withMemoryRebound(to: UInt8.self, capacity: 4){
//                print($0.pointee)
//                print(($0 + 1).pointee)
//            }
//        }
//        var arr = Data([0,0x24,0xb9,0xfc,0x3d])
//        let val = withUnsafePointer(to: &arr[1]){
//            $0.withMemoryRebound(to: Float.self, capacity: 4){
//                $0.pointee
//            }
//        }
//
//        print("test1", val)
    }
}

public class PBEncoder {
    
    public func set(_ int32: Int32, id: Int){
        
    }
}

public class PBDecoder {
    fileprivate var array: [UInt8]
    fileprivate let tags: [Int: (id: Int, format: Utils.Format)]
    
    convenience init(_ data:Data, first: Bool = false) {
        self.init(Array(data), first: first)
    }
    
    init(_ array:[UInt8], first: Bool = false) {
        self.array = first ? Array(array[1...]) : array
        var arr = [Int: (Int, Utils.Format)]()
        var offset = 0
        while offset < self.array.count {
            print(offset, String(self.array[offset], radix: 16))
            let fmt = Utils.format(self.array[offset])
            print("fmt: ", fmt.id, fmt.format.rawValue)
            arr[offset] = fmt
            switch fmt.format.rawValue{
            case 0:
                offset += 1
                while self.array[offset] >= 0x80{
                    offset += 1
                }
                offset += 1
            case 1: offset += 8 + 1
            case 2: offset += Int(self.array[offset + 1]) + 2
            case 5: offset += 4 + 1
            default:
                fatalError("illegal format \(offset + (first ? 1 : 0))")
            }
        }
        tags = arr
    }
    
    public func int32(_ id: Int)-> Int32{
        return integer(id, format: .varint)
    }
    public func uint32(_ id: Int)-> UInt32{
        return integer(id, format: .varint)
    }
    public func sint32(_ id: Int)-> Int32{
        return Utils.zigZagDecode(integer(id, format: .varint))
    }
    public func int64(_ id: Int)-> Int64{
        return integer(id, format: .varint)
    }
    public func uint64(_ id: Int)-> UInt64{
        return integer(id, format: .varint)
    }
    public func sint64(_ id: Int)-> Int64{
        return Utils.zigZagDecode(integer(id, format: .varint))
    }
    public func fixed32(_ id: Int)-> UInt32{
        return integer(id, format: .bit32)
    }
    public func sfixed32(_ id: Int)-> Int32{
        return integer(id, format: .bit32)
    }
    public func fixed64(_ id: Int)-> UInt64{
        return integer(id, format: .bit64)
    }
    public func sfixed64(_ id: Int)-> Int64{
        return integer(id, format: .bit64)
    }
    public func float(_ id: Int)-> Float{
        var res: Int32 = integer(id, format: .bit32)
        return  withUnsafePointer(to: &res){
            $0.withMemoryRebound(to: Float.self, capacity: MemoryLayout<Float>.size){$0.pointee}
        }
    }
    public func double(_ id: Int)-> Double{
        var res: Int64 = integer(id, format: .bit64)
        return  withUnsafePointer(to: &res){
            $0.withMemoryRebound(to: Double.self, capacity: MemoryLayout<Double>.size){$0.pointee}
        }
    }
    public func string(_ id: Int)->String{
        if let tag = tags.first(where: {$0.value.id == id}){
            guard tag.value.format == .bytes else {fatalError("illegal format)")}
            return String(bytes: array[(tag.key + 1)...(tag.key + 1 + Int(array[tag.key + 1]))], encoding: .utf8) ?? ""
        }
        return ""
    }
    public func data(_ id: Int)->ArraySlice<UInt8>{
        if let tag = tags.first(where: {$0.value.id == id}){
            guard tag.value.format == .bytes else {fatalError("illegal format)")}
            return array[(tag.key + 1)...(tag.key + 1 + Int(array[tag.key + 1]))]
        }
        return []
    }
    public func int32s(_ id: Int)-> [Int32]{
        return integers(id, format: .varint)
    }
    public func uint32s(_ id: Int)-> [Int32]{
        return integers(id, format: .varint)
    }
    public func int64s(_ id: Int)-> [Int64]{
        return integers(id, format: .varint)
    }
    public func uint64s(_ id: Int)-> [Int64]{
        return integers(id, format: .varint)
    }
    public func floats(_ id: Int)-> [Float]{
        return (integers(id, format: .bit32) as [Int32]).map{
            var res = $0
            return  withUnsafePointer(to: &res){
                $0.withMemoryRebound(to: Float.self, capacity: MemoryLayout<Float>.size){$0.pointee}
            }
        }
    }
    public func doubles(_ id: Int)-> [Double]{
        return (integers(id, format: .bit64) as [Int64]).map{
            var res = $0
            return  withUnsafePointer(to: &res){
                $0.withMemoryRebound(to: Double.self, capacity: MemoryLayout<Double>.size){$0.pointee}
            }
        }
    }
    public func strings(_ id: Int)-> [Double]{
        return []
    }
    public func datas(_ id: Int)-> [Data]{
        return []
    }
    public func objects<T>(_ id: Int, block: ((ArraySlice<UInt8>)->T))-> [T]{
        return tags.filter{$0.value.id == id && $0.value.format == .bytes}.map{block(array[($0.key + 1)...($0.key + 1 + Int(array[$0.key + 1]))])}
    }
}

extension PBDecoder{
    fileprivate func integer<T: FixedWidthInteger & BinaryInteger>(_ id: Int, format: Utils.Format)->T{
        return tags.first{$0.value.id == id && $0.value.format == format}.map{integer(offset: $0.key + 1, format: format)} ?? 0
    }
    fileprivate func integers<T: FixedWidthInteger & BinaryInteger>(_ id: Int, format: Utils.Format)->[T]{
        return tags.filter{$0.value.id == id && $0.value.format == format}.map{integer(offset: $0.key + 1, format: format)}
    }
    fileprivate func integer<T: FixedWidthInteger & BinaryInteger>(offset: Int, format: Utils.Format)->T{
        switch format{
        case .bit32, .bit64:
            return withUnsafePointer(to: &array[offset]){
                $0.withMemoryRebound(to: T.self, capacity: T.bitWidth){$0.pointee}
            }
        case .varint:
            var val = Utils.varintDecode(array[offset...min(offset + 9, array.count - 1)])
            return withUnsafePointer(to: &val){
                $0.withMemoryRebound(to: T.self, capacity: T.bitWidth){$0.pointee}
            }
        default: return 0
        }
    }
}
