package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF

/**
 * Original PNG frames from DailyCorp_SideView_GIF_Integration_v1.zip.
 * Exactly 16 action rows × 8 frame columns, resampled to 96x128.
 * 6/7-frame actions loop over their real frame count without duplicate frames.
 * Decoding happens once per Canvas view, not for every actor or drawing tick.
 */
class MineSpriteFrames(context:Context) {
    private data class Clip(val row:Int,val frames:Int,val durationMs:Int)
    companion object {
        private const val FRAME_W=96
        private const val FRAME_H=128
        private const val MAX_FRAMES=8
        private val clips=listOf(
            Triple("cart_idle_empty",8,160),
            Triple("cart_idle_loaded",8,160),
            Triple("cart_loading",6,125),
            Triple("cart_move_empty",8,110),
            Triple("cart_move_loaded",8,110),
            Triple("cart_unloading",6,125),
            Triple("miner_idle_left",8,160),
            Triple("miner_idle_right",8,160),
            Triple("miner_mine_left",7,125),
            Triple("miner_mine_right",7,125),
            Triple("miner_pickup_left",6,140),
            Triple("miner_pickup_right",6,140),
            Triple("miner_push_left",8,120),
            Triple("miner_push_right",8,120),
            Triple("miner_walk_left",8,100),
            Triple("miner_walk_right",8,100)
        ).mapIndexed { row,item -> item.first to Clip(row,item.second,item.third) }.toMap()
    }
    private val bitmap:Bitmap?=try {
        context.assets.open("dailycorp/mine/sideview_frames.webp").use {
            BitmapFactory.decodeStream(it)
        }?.takeIf {it.width==FRAME_W*MAX_FRAMES && it.height==FRAME_H*clips.size}
    }catch(_:Exception){null}
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    val loaded:Boolean get()=bitmap!=null
    fun draw(canvas:Canvas,name:String,x:Float,feetY:Float,tile:Float,
        nowMs:Long,offset:Int=0):Boolean {
        val atlas=bitmap?:return false
        val clip=clips[name]?:return false
        val frame=(((nowMs/clip.durationMs).toInt()+offset) % clip.frames + clip.frames)%clip.frames
        val cart=name.startsWith("cart")
        // A miner belongs INSIDE one tunnel tile, not across 1.5 rows.
        // Keep frame aspect ratio (96:128 = 0.75), preserve feetY baseline.
        // Carts should be visually contained in one tile, like miners.
        // Reduce both axes by the same ratio: keep the original art proportions.
        val width=if(cart)tile*0.98f else tile*0.675f
        val height=if(cart)tile*0.73f else tile*0.90f
        val source=Rect(frame*FRAME_W,clip.row*FRAME_H,
            (frame+1)*FRAME_W,(clip.row+1)*FRAME_H)
        val destination=RectF(x-width/2f,feetY-height,x+width/2f,feetY)
        canvas.drawBitmap(atlas,source,destination,paint)
        return true
    }
}
