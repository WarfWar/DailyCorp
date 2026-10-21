package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF

/**
 * Mobile atlas sampled from all ten user-supplied Style B surface packs.
 * A material is NOT an isometric decal: it is used only for cached top-down
 * continent raster. Diamond sprites preserve the 2:1 city projection.
 * Large dioramas are sparse accents, never automatically repeated as tiles.
 */
class WorldStyleBAtlas(context:Context) {
    companion object {
        private const val CELL=128
        private const val COLUMNS=8
        private val names=listOf(
            "material.grass","material.forest","material.rock","material.sand","material.snow","material.dirt",
            "material.wetland","ground.grass","ground.forest","ground.rock","ground.sand","ground.snow",
            "ground.dirt","ground.wetland","base.grass","base.forest","base.rock","base.sand",
            "base.snow","base.dirt","base.wetland","base.water","transition.grass_forest_01","transition.grass_forest_02",
            "transition.grass_forest_04","transition.grass_forest_08","transition.grass_rock_01","transition.grass_rock_04","landmark.meadow","landmark.forest",
            "landmark.mountain","landmark.coast","water.river_straight","water.river_bend","water.small_island","accent.grass_rock",
            "accent.forest_mountain","accent.construction","road.road_cross","road.road_bridge","road.rail_straight","nature.conifer",
            "nature.conifer_cluster","nature.rock","nature.shrub","site.plot_available","site.metal_outcrop","site.coal_outcrop",
            "site.stone_quarry","relief.grass_01","relief.forest_01","relief.rock_01","elevation.cliff_grass_h1_both_v0","elevation.cliff_rock_h1_both_v0",
            "elevation.slope_grass_u_plus_v0","elevation.terrace_forest_inner_left_h1"
        )
        private val lookup=names.withIndex().associate{it.value to it.index}
        fun biomeMaterial(b:Biome):String? = when(b){
            Biome.PLAINS -> "grass"
            Biome.FOREST -> "forest"
            Biome.MOUNTAINS -> "rock"
            Biome.SNOW -> "snow"
            Biome.DESERT,Biome.COAST -> "sand"
            Biome.SWAMP -> "wetland"
            else -> null
        }
        fun biomeSurface(b:Biome):String = when(b){
            Biome.PLAINS -> "ground.grass"
            Biome.FOREST -> "ground.forest"
            Biome.MOUNTAINS -> "ground.rock"
            Biome.SNOW -> "ground.snow"
            Biome.DESERT,Biome.COAST -> "ground.sand"
            Biome.SWAMP -> "ground.wetland"
            Biome.OCEAN,Biome.LAKE,Biome.RIVER -> "base.water"
        }
    }

    private val bitmap:Bitmap?=try{
        context.assets.open("dailycorp/world/styleb_10_packs.webp").use{
            BitmapFactory.decodeStream(it)
        }
    }catch(_:Exception){null}
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    val loaded:Boolean get()=bitmap!=null
    private fun source(key:String,verticalInset:Int=0,verticalHeight:Int=CELL):Rect? {
        val index=lookup[key]?:return null
        val x=index%COLUMNS*CELL;val y=index/COLUMNS*CELL
        return Rect(x,y+verticalInset,x+CELL,y+verticalInset+verticalHeight)
    }
    fun drawGround(canvas:Canvas,biome:Biome,cx:Float,cy:Float,
        halfW:Float,halfH:Float):Boolean{
        val bmp=bitmap?:return false
        val src=source(biomeSurface(biome),32,64)?:return false
        canvas.drawBitmap(bmp,src,RectF(cx-halfW,cy-halfH,
            cx+halfW,cy+halfH),paint)
        return true
    }
    fun drawAccent(canvas:Canvas,name:String,cx:Float,bottom:Float,
        width:Float,height:Float):Boolean{
        val bmp=bitmap?:return false
        val src=source(name)?:return false
        canvas.drawBitmap(bmp,src,RectF(cx-width/2f,bottom-height,
            cx+width/2f,bottom),paint)
        return true
    }
    /**
     * Continent stays fast even on a zoomed-out tablet: rasterize the 96x72
     * stable biome cells ONCE into an 8x8 pixel-per-cell bitmap.
     */
    fun bakeContinent(biomes:Array<Array<Biome>>):Bitmap?{
        val bmp=bitmap?:return null
        val output=Bitmap.createBitmap(96*8,72*8,Bitmap.Config.ARGB_8888)
        val c=Canvas(output)
        val flat=Paint(Paint.FILTER_BITMAP_FLAG)
        for(y in 0 until 72)for(x in 0 until 96){
            val biome=biomes[y][x]
            val material=biomeMaterial(biome)
            if(material==null){
                flat.color=when(biome){
                    Biome.OCEAN -> Color.rgb(28,86,125)
                    Biome.RIVER -> Color.rgb(56,131,157)
                    Biome.LAKE -> Color.rgb(45,117,149)
                    else -> Color.rgb(39,111,135)
                }
                c.drawRect(x*8f,y*8f,(x+1)*8f,(y+1)*8f,flat)
                continue
            }
            val src=source("material."+material)?:continue
            val px=(x*7+y*3)%120
            val py=(y*5+x*2)%120
            flat.color=Color.WHITE
            c.drawBitmap(bmp,Rect(src.left+px,src.top+py,
                src.left+px+8,src.top+py+8),
                RectF(x*8f,y*8f,(x+1)*8f,(y+1)*8f),flat)
        }
        return output
    }
    fun drawContinent(canvas:Canvas,image:Bitmap,rect:RectF){
        canvas.drawBitmap(image,null,rect,paint)
    }
}
