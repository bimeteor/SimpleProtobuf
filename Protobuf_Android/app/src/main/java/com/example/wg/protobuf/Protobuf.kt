package com.example.wg.protobuf


class PBUtils{
    companion object {
        fun <T>varintEncode(value: T): ByteArray where T: Number, T: Comparable<T>{
            val v = value.toLong()
            val low = 0x7f
//            val high = 0xffffffffffffff80
            return ByteArray(0)
        }
    }
    enum class Format{
        Varint, Bit64, Bytes, Start, Stop, Bit32
    }
}

class PBEncoder{
//    private var data: ByteArray
//    private val first: Boolean
//    public var result: ByteArray =

}

class PBDecoder{

}