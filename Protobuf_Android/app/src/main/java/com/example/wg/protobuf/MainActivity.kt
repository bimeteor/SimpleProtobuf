package com.example.wg.protobuf

import android.content.Intent
import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.renderscript.Float2
import android.renderscript.Float4


class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val a = -12
        var b: Int = 12
//        b = 0xffffffff
        var c = 12
        var d = 0xffffffff.javaClass
//        val c: Int = b shl 24
//        val d: Int = 0x
        val low = 0x7f.toLong()
        val high = (-1).toLong() - low
        val str = PBUtils.varintEncode(a)

        val arr = arrayOf(0xee, 0xff, 0xff, 0xff, 0x0f)
        val bytes = ByteArray(arr.size){arr[it].toByte()}

        val pari = PBUtils.varintDecode(bytes)
        val zig = PBUtils.zigZagEncode(2147483647)
        val inttt = 0x80.toByte().toInt()
        println("xxxxxx")
        println("aaaaa")
        println(pari)
        Float
//        val intentx = Intent()
//        intentx.setClassName(this.packageName,"com.example.wg.protobuf.Main2Activity")
//        startActivity(intentx)
        Unit
    }
}
