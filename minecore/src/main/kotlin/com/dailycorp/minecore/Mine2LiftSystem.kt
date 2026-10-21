package com.dailycorp.minecore

import java.io.Serializable
import kotlin.math.min

/** A paid, automatically excavated vertical freight shaft.
 * Existing world generation and saved geology stay unchanged elsewhere.
 */
data class Mine2LiftQuote(
    val x:Int,
    val endY:Int,
    val valid:Boolean,
    val reason:String,
    val price:Long=0L,
    val stations:List<Int> = emptyList(),
    val oreCellsAffected:Int=0,
    val newCells:Int=0
)
data class Mine2CargoLift(
    val id:Int,
    val x:Int,
    val endY:Int,
    val stations:MutableList<Int>,
    var builtToY:Int=2,
    val buffered:MutableMap<Int,MutableMap<String,Int>> = mutableMapOf(),
    var cargoMaterial:String?=null,
    var cargoAmount:Int=0,
    var fromStationY:Int=3,
    var tripTicksLeft:Int=0,
    var tripTicksTotal:Int=0,
    var totalDelivered:Int=0
):Serializable {
    val completed:Boolean get()=builtToY>=endY
    fun stationPos(y:Int)=CellPos(x,y)
    fun carriageY():Float {
        if(!completed || tripTicksTotal<=0 || tripTicksLeft<=0)return 3f
        val progress=(tripTicksTotal-tripTicksLeft).toFloat()/tripTicksTotal
        // Carriage descends toward its pickup station and returns to surface.
        return if(progress<0.5f)3f+(fromStationY-3)*progress*2f
            else fromStationY-(fromStationY-3)*(progress-0.5f)*2f
    }
}

/** Project + stations are serialized as part of the existing transport object. */
class Mine2LiftNetwork:Serializable {
    companion object { private const val serialVersionUID=1L }
    val lifts:MutableList<Mine2CargoLift> = mutableListOf()

    fun quote(world:Mine2World,transport:Mine2Transport,x:Int,endY:Int):Mine2LiftQuote {
        fun invalid(reason:String)=Mine2LiftQuote(x,endY,false,reason)
        if(x !in 2 until world.config.width-2)return invalid("Выбери место внутри шахты")
        if(endY !in 8 until world.config.depthCells-1)
            return invalid("Глубина должна быть не меньше 40 м и внутри шахты")
        if(lifts.size>=5)return invalid("Максимум пять дополнительных грузовых стволов")
        if(lifts.any{it.x==x})return invalid("На этой вертикали уже есть грузовой ствол")
        if(!transport.railAt(CellPos(x,3)) ||
            world.cell(x,3)?.passable!=true)
            return invalid("Сначала соедини точку на горизонте 15 м с рельсами у ствола")
        var ore=0
        var cells=0
        for(y in 4..endY){
            val c=world.cell(x,y)?:return invalid("Нельзя строить за границей шахты")
            if(c.kind==RockKind.BEDROCK)return invalid("На пути непроходимая порода")
            if(c.kind==RockKind.ORE && c.deposit>0)ore++
            if(!c.passable)cells++
        }
        val stops=mutableListOf(3)
        var level=23
        while(level<endY-5){stops.add(level);level+=20}
        stops.add(endY)
        // A preview must include the footprint and displaced ore before payment.
        val price=1100L+cells*55L+(stops.size-1)*280L
        return Mine2LiftQuote(x,endY,true,"Готово к строительству",
            price,stops,ore,cells)
    }
    fun start(world:Mine2World,transport:Mine2Transport,quote:Mine2LiftQuote):Boolean {
        if(!quote.valid)return false
        val fresh=quote(world,transport,quote.x,quote.endY)
        if(!fresh.valid || fresh.price!=quote.price)return false
        val id=(lifts.maxOfOrNull{it.id}?:0)+1
        lifts.add(Mine2CargoLift(id,quote.x,quote.endY,fresh.stations.toMutableList()))
        return true
    }
    fun stations():List<CellPos> = lifts.filter{it.completed}
        .flatMap{site->site.stations.drop(1).map{CellPos(site.x,it)}}
    fun findStation(at:CellPos):Mine2CargoLift? = lifts.firstOrNull{
        it.completed && it.x==at.x && at.y in it.stations && at.y>3
    }
    fun deposit(at:CellPos,material:String,amount:Int):Boolean {
        val lift=findStation(at)?:return false
        if(amount<=0)return false
        val store=lift.buffered.getOrPut(at.y){mutableMapOf()}
        store[material]=(store[material]?:0)+amount
        return true
    }
    /**
     * Construction: only one vertical segment per half-second tick per lift.
     * The new station tile becomes rail-connected only when the shaft reaches
     * its final depth; wagon arrivals never trigger a free lift teleport.
     */
    fun step(world:Mine2World,transport:Mine2Transport){
        for(site in lifts){
            if(!site.completed){
                val y=site.builtToY+1
                val p=CellPos(site.x,y)
                val c=world.cell(p.x,p.y)?:continue
                if(c.kind==RockKind.BEDROCK)continue
                // Construction cannot hand out free ores: material in the
                // shaft footprint is explicitly disclosed in the quote.
                c.kind=RockKind.SHAFT
                c.hardness=0
                c.deposit=0
                c.ordered=false
                c.explored=true
                site.builtToY=y
                world.reveal(site.x,y,1)
                if(site.completed){
                    for(stop in site.stations.drop(1))
                        transport.rails.add(CellPos(site.x,stop))
                }
                continue
            }
            if(site.cargoAmount>0){
                site.tripTicksLeft--
                if(site.tripTicksLeft<=0){
                    val material=site.cargoMaterial
                    if(material!=null){
                        world.removeFromUndergroundStockpile(material,site.cargoAmount)
                        transport.delivered[material]=(transport.delivered[material]?:0)+site.cargoAmount
                        site.totalDelivered+=site.cargoAmount
                    }
                    site.cargoAmount=0
                    site.cargoMaterial=null
                    site.tripTicksTotal=0
                    site.tripTicksLeft=0
                }
                continue
            }
            val location=site.buffered.entries
                .filter{e->e.value.values.any{it>0}}
                .minByOrNull{it.key}?:continue
            val material=location.value.entries.firstOrNull{it.value>0}?.key?:continue
            val amount=min(transport.liftCapacity()*5,location.value.getValue(material))
            if(amount<=0)continue
            location.value[material]=location.value.getValue(material)-amount
            site.cargoMaterial=material
            site.cargoAmount=amount
            site.fromStationY=location.key
            // Round trip distance: from 15 m top station to depth and back.
            // Lift speed increases with level; deep shafts take longer.
            site.tripTicksTotal=(((location.key-3)*2.0)/transport.liftLevel)
                .toInt().coerceAtLeast(2)
            site.tripTicksLeft=site.tripTicksTotal
        }
    }
}
