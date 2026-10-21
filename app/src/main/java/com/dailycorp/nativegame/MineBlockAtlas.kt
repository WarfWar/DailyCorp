package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.ColorMatrixColorFilter
import android.graphics.Rect
import android.graphics.RectF

/** Exact Style B material textures, packed into a single mobile atlas.
 * The source ZIP has square opaque 1x1 blocks. Never draw ore by selecting a
 * random stone background: that made unrelated resources look identical.
 */
class MineBlockAtlas(context:Context) {
    companion object {
        private const val CELL=128
        private const val COLS=6
        private val keys=listOf(
            "ore_bauxite","ore_chromium","ore_clay","ore_coal","ore_cobalt",
            "ore_copper","ore_gold","ore_granite","ore_graphite",
            "ore_gravel","ore_iron","ore_lead","ore_lithium",
            "ore_manganese","ore_molybdenum","ore_nickel",
            "ore_platinum","ore_quartz","ore_rare_earth","ore_salt",
            "ore_sand","ore_silicon","ore_silver","ore_slate",
            "ore_sulfur","ore_tin","ore_titanium","ore_tungsten",
            "ore_uranium","ore_zinc","terrain_bedrock","terrain_soil",
            "terrain_stone"
        ).withIndex().associate { it.value to it.index }
        private val oreFamilies=listOf(
            "bauxite","nickel","zinc","lead","tungsten","cobalt",
            "titanium","lithium","graphite","quartz","sulfur","uranium",
            "platinum","silver","manganese","chromium","molybdenum",
            "tin","silicon","rare_earth"
        )
        fun textureForMaterial(material:String):String{
            val parts=material.split("_")
            if(parts.size==3 && parts[0]=="ore"){
                val family=parts[1].toIntOrNull()
                if(family!=null && family in oreFamilies.indices)
                    return "ore_"+oreFamilies[family]
            }
            return when(material){
                "shale" -> "ore_slate"
                "rare_earth" -> "ore_rare_earth"
                else -> "ore_"+material
            }
        }
    }
    private val bitmap:Bitmap?=try{
        context.assets.open("dailycorp/mine/style_b_blocks.webp").use { stream ->
            BitmapFactory.decodeStream(stream)
        }
    }catch(_:Exception){null}
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    // The supplied tin and titanium textures share nearly identical geometry.
    // Separate tonal palettes without changing source atlas keys or saved IDs.
    private val tinFilter=ColorMatrixColorFilter(floatArrayOf(
        1.15f,0f,0f,0f,20f,
        0f,1.02f,0f,0f,12f,
        0f,0f,0.78f,0f,-5f,
        0f,0f,0f,1f,0f
    ))
    private val titaniumFilter=ColorMatrixColorFilter(floatArrayOf(
        0.82f,0f,0f,0f,-5f,
        0f,1.04f,0f,0f,6f,
        0f,0f,1.28f,0f,24f,
        0f,0f,0f,1f,0f
    ))
    val loaded get()=bitmap!=null
    fun draw(canvas:Canvas,key:String,left:Float,top:Float,right:Float,bottom:Float):Boolean {
        val image=bitmap?:return false
        val index=keys[key]?:return false
        val sx=index%COLS*CELL
        val sy=index/COLS*CELL
        paint.colorFilter=when(key){
            "ore_tin"->tinFilter
            "ore_titanium"->titaniumFilter
            else->null
        }
        canvas.drawBitmap(image,Rect(sx,sy,sx+CELL,sy+CELL),
            RectF(left,top,right,bottom),paint)
        paint.colorFilter=null
        return true
    }
}
