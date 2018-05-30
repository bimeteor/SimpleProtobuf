package com.example.wg.protobuf

import kotlin.experimental.and

data class Quadruple<out A, out B, out C, out D>(val first: A, val second: B, val third: C, val fourth: D)

class ByteSlice internal constructor(private val data: ByteArray, val range: IntRange){
    operator fun get(key: Int) = data[key]
    fun slice(range: IntRange) = ByteSlice(data, range)
    fun toByteArray() = data.sliceArray(range)
    fun <T>map(transform: (Byte) -> T) = range.map { transform(data[it]) }
}

fun ByteArray.toByteSlice() = ByteSlice(this, 0..(this.size - 1))
fun ByteArray.byteSlice(range: IntRange) = ByteSlice(this, range)

class PBUtils{
    companion object {
        fun <T>varintEncode(value: T): ByteArray where T: Number, T: Comparable<T>{
            val va = if (value is Int) 0xffffffff and value.toLong() else value.toLong()
            val low = 0x7f.toLong()
            val high = (-1).toLong() - low
            var offset = 0
            var next = va and (high shl (offset * 7)) != 0.toLong()
            var data = ByteArray(0)
            data += ((va and (low shl (offset * 7))) shr (offset * 7) or if (next) 0x80 else 0).toByte()
            while (next){
                offset += 1
                next = va and (high shl (offset * 7)) != 0.toLong()
                data += ((va and (low shl (offset * 7))) shr (offset * 7) or if (next) 0x80 else 0).toByte()
            }
            return data
        }
        fun varintDecode(data: ByteSlice): Pair<Long, Int>{
            var offset = 0
            var res = (data[data.range.start + offset] and 0x7f).toLong()
            while (data[data.range.start + offset].toInt() and 0x80 != 0){
                offset += 1
                res = res or ((data[data.range.start + offset] and 0x7f).toLong() shl (offset * 7))
            }
            return Pair(res, offset + 1)
        }
        fun varintsDecode(data: ByteSlice): LongArray {
            var offset = 0
            var arr = LongArray(0)
            while (data.range.start + offset <= data.range.last){
                varintDecode(data.slice((data.range.start + offset)..data.range.last)).let { arr += it.first; offset += it.second }
            }
            return arr
        }
        fun formatEncode(id: Int, format: Format) = varintEncode(id shl 3 or format.ordinal)
        fun formatDecode(data: ByteSlice): Quadruple<Int, Format, Long, IntRange>?{
            val format = varintDecode(data)
            val key = format.first.toInt()
            val type = Format.values()[key and 0b111]
            return when (type){
                Format.Bit32-> Quadruple(key shr 3, type, ints(data.slice((data.range.start + format.second)..(data.range.start + format.second + 3)))[0].toLong(), (data.range.start + format.second)..(data.range.start + format.second + 3))
                Format.Bit64-> Quadruple(key shr 3, type, longs(data.slice((data.range.start + format.second)..(data.range.start + format.second + 7)))[0], (data.range.start + format.second)..(data.range.start + format.second + 7))
                Format.Varint-> varintDecode(data.slice((data.range.start + format.second)..data.range.last)).let { Quadruple(key shr 3, type, it.first, (data.range.start + format.second)..(data.range.start + format.second + it.second - 1)) }
                Format.Bytes-> varintDecode(data.slice((data.range.start + format.second)..data.range.last)).let { Quadruple(key shr 3, type, 0.toLong(), (data.range.start + format.second + it.second)..(data.range.start + format.second + it.second + it.first.toInt() - 1)) }
                else-> null
            }
        }

        fun zigZagEncode(value: Int) = (value shl 1) xor (value shr 31)
        fun zigZagEncode(value: Long) = (value shl 1) xor (value shr 63)
        fun zigZagDecode(value: Int) = (value shr 1) xor -(value and 1)
        fun zigZagDecode(value: Long) = (value shr 1) xor -(value and 1)

        fun <T>bytes(value: T) where T: Number, T: Comparable<T> = (0..(if (value is Int) 3 else 7)).map { (value.toLong() shr (it * 8) and 0xff).toByte() }.toByteArray()
        fun ints(data: ByteSlice) = (0..(data.range.count() / 4 - 1)).map { (0..3).fold(0) { acc, i -> acc + ((data[data.range.start + it * 4 + i].toInt() and 0xff) shl (i * 8)) } }.toIntArray()
        fun longs(data: ByteSlice) = (0..(data.range.count() / 8 - 1)).map { (0..7).fold(0.toLong()) { acc, i -> acc + ((data[data.range.start + it * 8 + i].toLong() and 0xff) shl (i * 8)) } }.toLongArray()
    }

    enum class Format{
        Varint, Bit64, Bytes, Start, Stop, Bit32
    }
}

class PBEncoder(private val pack: Boolean = false){
    private var data = ByteArray(0)
    fun result() = if (data.isEmpty()) ByteArray(1){0} else ((if (pack) PBUtils.varintEncode(data.size) else ByteArray(0)) + data)

    fun set(value: Boolean, id: Int) = if (value) data += PBUtils.formatEncode(id, PBUtils.Format.Varint) + ByteArray(1){ 1 } else Unit
    fun set(value: Int, id: Int) = if (value != 0) data += PBUtils.formatEncode(id, PBUtils.Format.Varint) + PBUtils.varintEncode(value) else Unit
    fun set(value: Long, id: Int) = if (value != 0.toLong()) data += PBUtils.formatEncode(id, PBUtils.Format.Varint) + PBUtils.varintEncode(value) else Unit
    fun sets(value: Int, id: Int) = set(PBUtils.zigZagEncode(value), id)
    fun sets(value: Long, id: Int) = set(PBUtils.zigZagEncode(value), id)
    fun setf(value: Int, id: Int) = if (value != 0) data += PBUtils.formatEncode(id, PBUtils.Format.Bit32) + PBUtils.bytes(value) else Unit
    fun setf(value: Long, id: Int) = if (value != 0.toLong()) data += PBUtils.formatEncode(id, PBUtils.Format.Bit64) + PBUtils.bytes(value) else Unit
    fun set(value: Float, id: Int) = setf(java.lang.Float.floatToIntBits(value), id)
    fun set(value: Double, id: Int) = setf(java.lang.Double.doubleToLongBits(value), id)
    fun set(value: String, id: Int) = set(value.toByteArray(), id)
    fun set(value: ByteArray, id: Int) = if (value.isNotEmpty() && !data.contentEquals(ByteArray(1){0})) data += PBUtils.formatEncode(id, PBUtils.Format.Bytes) + PBUtils.varintEncode(value.size) + value else Unit
    fun set(value: BooleanArray, id: Int) = set(value.map { (if (it) 1 else 0).toByte() }.toByteArray(), id)
    fun set(value: IntArray, id: Int) = set(value.map { PBUtils.varintEncode(it) }.flatMap { it.asIterable() }.toByteArray(), id)
    fun set(value: LongArray, id: Int) = set(value.map { PBUtils.varintEncode(it) }.flatMap { it.asIterable() }.toByteArray(), id)
    fun sets(value: IntArray, id: Int) = set(value.map { PBUtils.zigZagEncode(it) }.toIntArray(), id)
    fun sets(value: LongArray, id: Int) = set(value.map { PBUtils.zigZagEncode(it) }.toLongArray(), id)
    fun setf(value: IntArray, id: Int) = set(value.map { PBUtils.bytes(it) }.flatMap { it.asIterable() }.toByteArray() , id)
    fun setf(value: LongArray, id: Int) = set(value.map { PBUtils.bytes(it) }.flatMap { it.asIterable() }.toByteArray() , id)
    fun set(value: FloatArray, id: Int) = set(value.map { PBUtils.bytes(java.lang.Float.floatToIntBits(it)) }.flatMap { it.asIterable() }.toByteArray() , id)
    fun set(value: DoubleArray, id: Int) = set(value.map { PBUtils.bytes(java.lang.Double.doubleToLongBits(it)) }.flatMap { it.asIterable() }.toByteArray() , id)
    fun set(value: Array<String>, id: Int) = value.forEach { set(it, id) }
    fun set(value: Array<ByteArray>, id: Int) = value.forEach { set(it, id) }
}

class PBDecoder(private val data: ByteSlice, pack: Boolean = false) {
    constructor(data: ByteArray, pack: Boolean = false) : this(data.toByteSlice(), pack)

    private var tags = emptyArray<Quadruple<Int, PBUtils.Format, Long, IntRange>>()

    init {
        var offset = data.range.first + if (pack) PBUtils.varintDecode(data).second else 0
        while (offset <= data.range.last) {
            PBUtils.formatDecode(data.slice(offset..data.range.last))?.let { tags += it; offset = it.fourth.last + 1 }
                    ?: break
        }
    }

    fun bool(id: Int) = long(id)?.let { it != 0.toLong() }
    fun int(id: Int) = long(id)?.toInt()
    fun long(id: Int) = tags.firstOrNull { it.first == id && it.second == PBUtils.Format.Varint }?.third
    fun sint(id: Int) = int(id)?.let { PBUtils.zigZagDecode(it) }
    fun slong(id: Int) = long(id)?.let { PBUtils.zigZagDecode(it) }
    fun fint(id: Int) = tags.firstOrNull { it.first == id && it.second == PBUtils.Format.Bit32 }?.third?.toInt()
    fun flong(id: Int) = tags.firstOrNull { it.first == id && it.second == PBUtils.Format.Bit64 }?.third
    fun float(id: Int) = fint(id)?.let { java.lang.Float.intBitsToFloat(it) }
    fun double(id: Int) = flong(id)?.let { java.lang.Double.longBitsToDouble(it) }
    fun string(id: Int) = bytes(id)?.let { String(it.toByteArray()) }
    fun bytes(id: Int) = tags.firstOrNull { it.first == id && it.second == PBUtils.Format.Bytes }?.let { data.slice(it.fourth) }

    fun bools(id: Int) = bytes(id)?.map { it != 0.toByte() }?.toBooleanArray() ?: BooleanArray(0)
    fun ints(id: Int) = longs(id).map { it.toInt() }.toIntArray()
    fun longs(id: Int) = bytes(id)?.let { PBUtils.varintsDecode(it) } ?: LongArray(0)
    fun sints(id: Int) = ints(id).map { PBUtils.zigZagDecode(it) }.toIntArray()
    fun slongs(id: Int) = longs(id).map { PBUtils.zigZagDecode(it) }.toLongArray()
    fun fints(id: Int) = bytes(id)?.let { PBUtils.ints(it) } ?: IntArray(0)
    fun flongs(id: Int) = bytes(id)?.let { PBUtils.longs(it) } ?: LongArray(0)
    fun floats(id: Int) = fints(id).map { java.lang.Float.intBitsToFloat(it) }.toFloatArray()
    fun doubles(id: Int) = flongs(id).map { java.lang.Double.longBitsToDouble(it) }.toDoubleArray()
    fun strings(id: Int) = bytess(id).map { it.toString() }
    fun bytess(id: Int) = tags.filter { it.first == id && it.second == PBUtils.Format.Bytes }.map { data.slice(it.fourth) }
}