package com.example.wg.protobuf

import kotlin.experimental.and
import java.lang.Float
import java.lang.Double

data class Quadruple<out A, out B, out C, out D>(val first: A, val second: B, val third: C, val fourth: D)

class PBUtils{
    companion object {
        fun <T>varintEncode(value: T): ByteArray where T: Number, T: Comparable<T>{
            val va = value.toLong()
            val low = 0x7f.toLong()
            val high = (-1).toLong() - low
            var offset = 0
            var next = va and (high shl (offset * 7)) != 0.toLong()
            var data = ByteArray(0)
            data += ((va and (high shl (offset * 7))) shr (offset * 7) or if (next) 0x80 else 0).toByte()
            while (next){
                offset += 1
                next = va and (high shl (offset * 7)) != 0.toLong()
                data += ((va and (high shl (offset * 7))) shr (offset * 7) or if (next) 0x80 else 0).toByte()
            }
            return data
        }
        fun formatEncode(id: Int, format: Format) = varintEncode(id shl 3 or format.ordinal)

        fun varintDecode(data: ByteArray): Pair<Long, Int>{
            var offset = 0
            var res = data[offset].toLong()
            while (data[offset] and 0x80.toByte() != 0.toByte()){
                offset += 1
                res = res or ((data[offset] and 0x7f).toLong() shl (offset * 7))
            }
            return Pair(res, offset + 1)
        }
        fun varintsDecode(data: ByteArray): LongArray {
            var offset = 0
            var arr = LongArray(0)
            while (offset < data.size){
                var va = data[offset].toLong()
                while (data[offset].toInt() and 0x80 != 0){
                    offset += 1
                    va = va or (data[offset].toLong() and 0x7f) shl (offset * 7)
                }
                arr += va
                offset += 1
            }
            return arr
        }

        fun formatDecode(data: ByteArray): Quadruple<Int, Format, Long, ByteArray?>?{
            val format = varintDecode(data)
            val key = format.first.toInt()
            val type = Format.values()[key and 0b111]
            return when (type){
                Format.Bit32-> Quadruple(key shr 3, type, ints(data.sliceArray(format.second..(format.second + 3)))[0].toLong(), null)
                Format.Bit64-> Quadruple(key shr 3, type, longs(data.sliceArray(format.second..(format.second + 7)))[0], null)
                Format.Varint-> Quadruple(key shr 3, type, varintDecode(data.sliceArray(format.second..(data.size - 1))).second.toLong(), null)
                Format.Bytes-> varintDecode(data.sliceArray(format.second..(data.size - 1))).run { Quadruple(key shr 3, type, 0.toLong(), data.sliceArray((format.second + this.second)..(format.second + this.second + this.first.toInt()))) }
                else-> null
            }
        }

        fun zigZagEncode(value: Int) = (value shl 1) xor (value shr 31)
        fun zigZagEncode(value: Long) = (value shl 1) xor (value shr 63)
        fun zigZagDecode(value: Int) = (value shr 1) xor -(value and 1)
        fun zigZagDecode(value: Long) = (value shr 1) xor -(value and 1)

        fun float(value: Int) = Float.intBitsToFloat(value)
        fun double(value: Long) = Double.longBitsToDouble(value)

        fun bytes(value: Int): ByteArray{
            var arr = ByteArray(0)
            (0 until 4).forEach { arr += (value shr (it * 8) and 0xff).toByte() }
            return arr
        }

        fun bytes(value: Long): ByteArray{
            (0 until 8).reduce{acc, i -> 0}
            var arr = ByteArray(0)
            (0 until 8).forEach { arr += (value shr (it * 8) and 0xff).toByte() }
            return arr
        }

        fun bytes(value: kotlin.Float) = bytes(Float.floatToIntBits(value))

        fun bytes(value: kotlin.Double) = bytes(Double.doubleToLongBits(value))

        fun ints(data: ByteArray) = (0 until data.size / 4).map { (0 until 4).reduce { acc, i -> acc + data[it * 4 + i] shl (i * 8) } }.toIntArray()

        fun longs(data: ByteArray) = (0 until data.size / 8).map { (0.toLong() until 8.toLong()).reduce { acc, i -> acc + data[(it * 4 + i).toInt()] shl (i * 8).toInt() } }.toLongArray()

        fun floats(data: ByteArray) = ints(data).map { Float.intBitsToFloat(it) }

        fun doubles(data: ByteArray) = longs(data).map { Double.longBitsToDouble(it) }
    }

    enum class Format{
        Varint, Bit64, Bytes, Start, Stop, Bit32
    }
}

class PBEncoder(private val pack: Boolean){
    private var data = ByteArray(0)
    fun result() = if (data.isEmpty()) ByteArray(1){0} else ((if (pack) ByteArray(1){ data.size.toByte() } else ByteArray(0)) + data)

    fun set(value: Int, id: Int){
        if (value != 0){
            data += PBUtils.formatEncode(id, PBUtils.Format.Varint) + PBUtils.varintEncode(value)
        }
    }
    fun set(value: Long, id: Int){
        if (value != 0.toLong()){
            data += PBUtils.formatEncode(id, PBUtils.Format.Varint) + PBUtils.varintEncode(value)
        }
    }
    fun setzigzag(value: Int, id: Int) = set(PBUtils.zigZagEncode(value), id)
    fun setzigzag(value: Long, id: Int) = set(PBUtils.zigZagEncode(value), id)
    fun setfixed(value: Int, id: Int){
        if (value != 0){
            data += PBUtils.formatEncode(id, PBUtils.Format.Bit32) + PBUtils.bytes(value)
        }
    }
    fun setfixed(value: Long, id: Int){
        if (value != 0.toLong()){
            data += PBUtils.formatEncode(id, PBUtils.Format.Bit64) + PBUtils.bytes(value)
        }
    }
    fun set(value: kotlin.Float, id: Int) = set(Float.floatToIntBits(value), id)
    fun set(value: kotlin.Double, id: Int) = set(Double.doubleToLongBits(value), id)
    fun set(value: String, id: Int) = set(value.toByteArray(), id)
    fun set(value: ByteArray, id: Int){
        if (!value.isEmpty() && data.contentEquals(ByteArray(1){0})){
            data += PBUtils.formatEncode(id, PBUtils.Format.Bytes) + PBUtils.varintEncode(value.size) + value
        }
    }
}

class PBDecoder(private val data: ByteArray, pack: Boolean = false){
    private var tags = emptyArray<Quadruple<Int, PBUtils.Format, Long, ByteArray?>>()
    init {
        var offset = if (pack) 1 else 0
        while (offset < data.size) {
            PBUtils.formatDecode(data.sliceArray(offset..(data.size - 1)))?.let { tags += it; offset = } ?: break
        }
    }
}