package com.dailycorp.nativegame

import android.content.Context
import com.dailycorp.minecore.Mine2Config
import com.dailycorp.minecore.Mine2World
import java.io.File
import java.io.ObjectInputStream
import java.io.ObjectOutputStream

/** Foreground-session mining while viewing the city/continent.
 * No Android background service or offline gains. Old snapshots load lazily.
 */
object Mine2Runtime {
    private data class Key(val city:Int,val lot:Int)
    private val worlds=mutableMapOf<Key,Mine2World>()
    private val dirty=mutableSetOf<Key>()
    private val blocked=mutableSetOf<Key>()
    private var foregroundTicks=0
    private const val SAVE_INTERVAL=5

    fun config(game:GameEngine,cityId:Int,lotId:Int):Mine2Config {
        val mine=game.company(cityId).mines.getValue(lotId)
        return Mine2Config(
            seed=game.city(cityId).seed xor lotId.toLong()*9973L,
            width=52,
            depthCells=(mine.depth*8).coerceIn(120,1200),
            ores=mine.ores.ifEmpty{listOf("coal","iron","copper","gold")}
        )
    }
    fun filename(city:Int,lot:Int)="mine2_v1_city_"+city+"_lot_"+lot+".save"
    private fun load(context:Context,game:GameEngine,key:Key):Mine2World? {
        val config=config(game,key.city,key.lot)
        val file=File(context.filesDir,filename(key.city,key.lot))
        if(!file.exists())return Mine2World.create(config)
        return try {
            ObjectInputStream(file.inputStream()).use {
                (it.readObject() as Mine2World).takeIf { w->w.config==config }
            }
        }catch (_:Exception){null}
    }
    /** Incompatible/corrupt saves are never replaced by a fresh world. */
    fun advance(context:Context,game:GameEngine,seconds:Int=1) {
        val active=game.state.companies.entries.flatMap { (city,c) ->
            c.mines.values.filter{it.mine2ProductionEnabled}.map{Key(city,it.lotId)}
        }
        for(key in active){
            if(key in blocked)continue
            val world=worlds[key]?:load(context,game,key)?.also{worlds[key]=it}
            if(world==null){blocked.add(key);continue}
            repeat(seconds.coerceIn(0,15)*2){world.step()}
            dirty.add(key)
        }
        foregroundTicks+=seconds
        if(foregroundTicks>=SAVE_INTERVAL){
            flush(context,game)
            foregroundTicks=0
        }
    }
    /** Persist Mine2 first; only then credit its delivered totals to GameState. */
    fun flush(context:Context,game:GameEngine) {
        for(key in dirty.toList()){
            val world=worlds[key]?:continue
            val file=File(context.filesDir,filename(key.city,key.lot))
            val tmp=File(context.filesDir,file.name+".background.tmp")
            try{
                ObjectOutputStream(tmp.outputStream()).use{it.writeObject(world)}
                if(!tmp.renameTo(file))throw IllegalStateException("Mine2 snapshot commit failed")
                game.applyMine2Delivery(key.city,key.lot,
                    world.existingTransport()?.delivered?:emptyMap())
                dirty.remove(key)
            }catch (_:Exception){
                tmp.delete()
                // No cargo credit unless the mine snapshot was saved.
            }
        }
    }
    /** Prevent two simulators from advancing the same underground save. */
    fun leaveCityScreen(context:Context,game:GameEngine){
        flush(context,game)
        worlds.clear()
        dirty.clear()
        blocked.clear()
        foregroundTicks=0
    }
}
