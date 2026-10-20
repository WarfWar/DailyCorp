package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Color
import org.json.JSONObject

/**
 * User-provided DailyCorp illustrated atlases extracted as 132 sprite cells.
 * All bitmap decode and JSON parsing happens once. The draw path allocates
 * no new bitmap and uses cached rectangular source areas.
 */
class GameArt(context: Context) {
    private val bitmap: Bitmap?
    private val tiles: Map<String,Rect>
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

    init {
        var decoded:Bitmap?=null
        var cells:Map<String,Rect> = emptyMap()
        try {
            val metadata=JSONObject(context.assets.open("dailycorp_sprite_map.json")
                .bufferedReader().use{it.readText()})
            val size=metadata.getInt("tile")
            val columns=metadata.getInt("columns")
            val names=metadata.getJSONObject("sprites")
            cells=buildMap{
                val keys=names.keys()
                while(keys.hasNext()) {
                    val key=keys.next()
                    val index=names.getInt(key)
                    val sx=(index%columns)*size
                    val sy=(index/columns)*size
                    put(key,Rect(sx,sy,sx+size,sy+size))
                }
            }
            decoded=context.assets.open("dailycorp_resources.webp").use{
                BitmapFactory.decodeStream(it)
            }
        }catch(_:Exception){ /* Graceful fallback on unsupported or missing atlas. */ }
        bitmap=decoded
        tiles=cells
    }

    fun has(id:String):Boolean = bitmap!=null && tiles.containsKey(id)

    fun draw(canvas:Canvas,id:String,left:Float,top:Float,right:Float,bottom:Float):Boolean {
        val b=bitmap ?:return false
        val rect=tiles[id] ?:return false
        if(right<=left || bottom<=top)return false
        canvas.drawBitmap(b,rect,RectF(left,top,right,bottom),paint)
        return true
    }

    fun draw(canvas:Canvas,id:String,centerX:Float,centerY:Float,width:Float,height:Float):Boolean =
        draw(canvas,id,centerX-width/2f,centerY-height/2f,
            centerX+width/2f,centerY+height/2f)

    fun mineKey(block:MineBlock,depth:Int):String = when(block.terrain) {
        MineTerrain.BEDROCK -> "mine.abyss"
        MineTerrain.ROCK -> when {
            depth<=5 -> "mine.soil"
            depth<=11 -> "mine.stone"
            depth<=17 -> "mine.deep_stone"
            else -> "mine.abyss"
        }
        MineTerrain.ORE -> "mine."+oreKey(block.material)
        MineTerrain.TUNNEL -> "mine.empty"
        MineTerrain.SHAFT -> "mine.shaft"
    }

    private fun oreKey(material:String):String {
        return when(material) {
            "iron" -> "iron"
            "coal" -> "coal"
            "copper" -> "copper"
            "gold" -> "gold"
            else -> {
                val index=material.removePrefix("ore_").substringBefore('_').toIntOrNull() ?: -1
                listOf("bauxite","nickel","tungsten","limestone","lithium",
                    "quartz","sulfur","uranium","platinum","silver",
                    "cobalt","titanium","rare_earth","iridium","emerald",
                    "ruby","sapphire","crystal","clay","petroleum")
                    .getOrNull(index) ?: "stone"
            }
        }
    }

    fun buildingKey(kind:BuildingKind,lotId:Int):String = when(kind) {
        BuildingKind.MINE -> "infra.storage_yard"
        BuildingKind.FACTORY -> "infra.utilities"
        BuildingKind.WAREHOUSE -> "buildings.warehouse_10"
        BuildingKind.MARKET -> if(lotId%2==0)"buildings.market_10" else "infra.market_stalls"
        BuildingKind.MUNICIPAL -> "buildings.cityhall_10"
        BuildingKind.ENERGY -> "buildings.electric_10"
        BuildingKind.RESEARCH -> "buildings.university_10"
    }
}
