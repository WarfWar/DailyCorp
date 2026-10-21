package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF

/**
 * Compact, offline, curated artwork from DailyCorp World Style B packs 7/9/10.
 * Single decode per atlas; no PNG decoding, geologic mutation or object creation
 * per frame. Earlier concept cards are intentionally NOT autotiled: their
 * geometric connectors are not seamless.
 */
class WorldStyleBArt(context:Context) {
    private val material:Bitmap?=decode(context,"dailycorp/world/styleb_materials.webp")
    private val isometric:Bitmap?=decode(context,"dailycorp/world/styleb_isometric.webp")
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    val hasMaterials:Boolean get()=material!=null
    val hasIsometric:Boolean get()=isometric!=null

    private fun decode(context:Context,name:String):Bitmap?=try {
        val options=BitmapFactory.Options().apply{inScaled=false}
        context.assets.open(name).use{BitmapFactory.decodeStream(it,null,options)}
    }catch (_:Exception){null}

    private fun family(b:Biome):Int=when(b) {
        Biome.OCEAN,Biome.LAKE,Biome.RIVER->7
        Biome.COAST,Biome.DESERT->4
        Biome.PLAINS->2
        Biome.FOREST->1
        Biome.MOUNTAINS->3
        Biome.SNOW->5
        Biome.SWAMP->6
    }
    /** Source variation is deterministic and does not expose randomized new biomes. */
    fun drawContinentCell(canvas:Canvas,b:Biome,x:Int,y:Int,left:Float,top:Float,size:Float):Boolean {
        val image=material?:return false
        val i=family(b)
        val tileX=(i%4)*128
        val tileY=(i/4)*128
        val subX=((x*31+y*7) and 63)
        val subY=((x*11+y*43) and 63)
        canvas.drawBitmap(image,Rect(tileX+subX,tileY+subY,
            tileX+subX+48,tileY+subY+48),
            RectF(left,top,left+size+0.3f,top+size+0.3f),paint)
        return true
    }
    private fun isoGroup(b:Biome):Int=when(b){
        Biome.OCEAN,Biome.LAKE,Biome.RIVER->7
        Biome.COAST,Biome.DESERT->4
        Biome.PLAINS->2
        Biome.FOREST->1
        Biome.MOUNTAINS->3
        Biome.SNOW->5
        Biome.SWAMP->6
    }
    fun drawCityTile(canvas:Canvas,b:Biome,x:Int,y:Int,
        cx:Float,cy:Float,rx:Float,ry:Float):Boolean {
        val image=isometric?:return false
        // 4 variations per biome; 8 groups in the 128px source-cell atlas.
        val family=isoGroup(b)
        // 5x5-cell stable regions prevent checkerboard-like alternating
        // material variants on adjacent isometric tiles.
        val variation=((x/5)*7+(y/5)*3) and 3
        val index=family*4+variation
        val sx=index%8*128
        val sy=index/8*128
        canvas.drawBitmap(image,Rect(sx,sy,sx+128,sy+64),
            RectF(cx-rx,cy-ry,cx+rx,cy+ry),paint)
        return true
    }
    /** Optional decoration. 32..39 Pack9 objects, 40..43 Pack10 overlays. */
    fun drawDecor(canvas:Canvas,id:Int,cx:Float,cy:Float,
        width:Float,height:Float):Boolean {
        val image=isometric?:return false
        if(id !in 32..43)return false
        val sx=id%8*128
        val sy=id/8*128
        canvas.drawBitmap(image,Rect(sx,sy,sx+128,sy+128),
            RectF(cx-width*0.5f,cy-height,cx+width*0.5f,cy),paint)
        return true
    }
}
