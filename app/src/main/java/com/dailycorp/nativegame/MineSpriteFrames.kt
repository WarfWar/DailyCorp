package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF

/** Adapter of the uploaded MineFrameAnimator.kt for one compressed atlas.
 * Four time-spaced real frames per animation, aligned at bottom-center.
 * Decodes ONE bitmap for the entire mine scene, not per actor or frame.
 */
class MineSpriteFrames(context:Context) {
    companion object{
        private val rows=listOf(
            "cart_idle_empty","cart_idle_loaded","cart_loading",
            "cart_move_empty","cart_move_loaded","cart_unloading",
            "miner_idle_left","miner_idle_right","miner_mine_left",
            "miner_mine_right","miner_pickup_left","miner_pickup_right",
            "miner_push_left","miner_push_right","miner_walk_left",
            "miner_walk_right"
        ).withIndex().associate{it.value to it.index}
        private const val FRAME_W=18
        private const val FRAME_H=24
        private const val FRAME_COUNT=4
    }
    private val bitmap:Bitmap?=try{
        context.assets.open("dailycorp/mine/sideview_frames.webp").use{
            BitmapFactory.decodeStream(it)
        }
    }catch(_:Exception){null}
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    val loaded:Boolean get()=bitmap!=null
    fun draw(canvas:Canvas,name:String,x:Float,feetY:Float,tile:Float,
        nowMs:Long,offset:Int=0):Boolean{
        val atlas=bitmap?:return false
        val row=rows[name]?:return false
        val frame=(((nowMs/145L).toInt()+offset).mod(FRAME_COUNT))
        val width=if(name.startsWith("cart"))tile*1.45f else tile*1.05f
        val height=if(name.startsWith("cart"))tile*1.50f else tile*1.48f
        val src=Rect(frame*FRAME_W,row*FRAME_H,(frame+1)*FRAME_W,(row+1)*FRAME_H)
        val dst=RectF(x-width/2f,feetY-height,x+width/2f,feetY)
        canvas.drawBitmap(atlas,src,dst,paint)
        return true
    }
}
