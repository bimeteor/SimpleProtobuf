package com.example.wg.protobuf

import android.support.v7.app.AppCompatActivity
import android.os.Bundle

import android.util.Log

fun IntArray.print(){
    forEach { println(it) }
}

fun logv(tag: String, message: Any?){
    Log.v(tag, message.toString())
}

fun ByteArray.toHexString() = "[" + joinToString(separator = ","){ it.toHexString() } + "]"

fun IntArray.toHexString() = "[" + joinToString(separator = ","){ it.toString(16) } + "]"

fun Byte.toHexString() = if (this >= 0) toString(16) else (this + 0x100).toString(16)

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val per = PBEncoder(true)
        per.set("frank", 1)
        per.set(-18, 2)
        per.set(0, 3)

        val an1 = PBEncoder()
        an1.set(1.1.toFloat(), 1)
        an1.set(2.2, 2)
        an1.set("cat", 3)

        val an2 = PBEncoder()
        an2.set(3.3.toFloat(), 1)
        an2.set(4.4, 2)
        an2.set("dog", 3)

        per.set(arrayOf(an1.result(), an2.result()), 5)

        val res = per.result()
        logv("==", res.toHexString())

        val dec = PBDecoder(res, true)
        logv("==", dec.string(1))
        logv("==", dec.int(2))
        logv("==", dec.int(3))
        dec.bytess(5).map { PBDecoder(it) }.map {
            logv("==", it.float(1))
            logv("==", it.double(2))
            logv("==", it.string(3))
        }
    }
}
