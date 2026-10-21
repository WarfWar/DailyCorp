package com.dailycorp.minecore

import java.io.Serializable
import java.util.ArrayDeque
import kotlin.math.min

data class Mine2Cart(
    val id:Int,
    var x:Int,
    var y:Int,
    var material:String?=null,
    var amount:Int=0
):Serializable

data class Mine2Delivery(val material:String,val amount:Int):Serializable

/** All V4 fields are optional for legacy Java saves, UID must remain 1L. */
class Mine2Transport(private val depot:CellPos):Serializable {
    companion object { private const val serialVersionUID=1L }
    val rails:MutableSet<CellPos> = mutableSetOf()
    val piles:MutableMap<CellPos,MutableMap<String,Int>> = mutableMapOf()
    val carts:MutableList<Mine2Cart> = mutableListOf()
    /** Cumulative unloaded quantities. Replayed idempotently to the city ledger. */
    val delivered:MutableMap<String,Int> = mutableMapOf()
    private var liftNetworkV5:Mine2LiftNetwork?=null
    fun lifts():List<Mine2CargoLift> = liftNetworkV5?.lifts?:emptyList()
    fun stationNodes():List<CellPos> = liftNetworkV5?.stations()?:emptyList()
    fun quoteLift(world:Mine2World,x:Int,y:Int):Mine2LiftQuote =
        (liftNetworkV5?:Mine2LiftNetwork()).quote(world,this,x,y)
    fun startLift(world:Mine2World,quote:Mine2LiftQuote):Boolean {
        val network=liftNetworkV5?:Mine2LiftNetwork().also{liftNetworkV5=it}
        return network.start(world,this,quote)
    }
    // Optional in old Java saves: no compatibility-breaking UID change.
    private var railProjectsV8:MutableList<Mine2RailProject>?=null
    fun railProjects():List<Mine2RailProject> = railProjectsV8?:emptyList()
    fun quoteRailProject(world:Mine2World,to:CellPos):Mine2RailQuote =
        Mine2RailPlanner.quote(world,this,to)
    fun startRailProject(world:Mine2World,quote:Mine2RailQuote):Boolean{
        if(!quote.valid || quote.path.isEmpty())return false
        val fresh=quoteRailProject(world,quote.destination)
        if(!fresh.valid || fresh.path!=quote.path || fresh.price!=quote.price)
            return false
        val projects=railProjectsV8?:mutableListOf<Mine2RailProject>().also{railProjectsV8=it}
        projects.add(Mine2RailProject(fresh.destination,fresh.path,fresh.price))
        return true
    }
    private fun advanceRailProjects(world:Mine2World){
        for(project in railProjects()){
            if(project.completed || project.blocked)continue
            val next=project.path[project.nextIndex]
            // One paid segment per half-second, respecting current topology.
            if(next in rails){
                project.nextIndex++
            }else if(buildRail(world,next)){
                project.nextIndex++
            }else{
                project.blocked=true
            }
        }
    }
    var totalRailBuilt=0
        private set
    private var liftLevelV4=0
    var transportTicksV4=0L
        private set
    var idleWithoutRailV4=0L
        private set
    var liftCongestionTicksV4=0L
        private set
    var loadedTripsV4=0L
        private set
    var cartTravelStepsV4=0L
        private set

    val liftLevel:Int get()=liftLevelV4.coerceAtLeast(1)
    fun liftCapacity():Int=liftLevel
    fun liftUpgradeCost():Long=1200L*liftLevel*liftLevel
    fun canUpgradeLift():Boolean=liftLevel<6
    fun upgradeLift():Boolean {
        if(!canUpgradeLift())return false
        liftLevelV4=liftLevel+1
        return true
    }
    init{
        for(x in depot.x-4..depot.x+4)rails.add(CellPos(x,depot.y))
        for(y in 0..5)rails.add(CellPos(depot.x,y))
    }
    fun railPrice():Long=60L+10L*(totalRailBuilt/12)
    fun cartPrice():Long=750L+350L*carts.size
    fun cartCapacity():Int=5
    fun railAt(p:CellPos):Boolean=p in rails
    private fun neighbors(p:CellPos)=listOf(
        CellPos(p.x-1,p.y),CellPos(p.x+1,p.y),
        CellPos(p.x,p.y-1),CellPos(p.x,p.y+1)
    )
    fun canBuildRail(world:Mine2World,p:CellPos):Boolean {
        val c=world.cell(p.x,p.y)?:return false
        if(!c.explored || !c.passable || p in rails)return false
        return neighbors(p).any{it in rails}
    }
    fun buildRail(world:Mine2World,p:CellPos):Boolean {
        if(!canBuildRail(world,p))return false
        rails.add(p)
        totalRailBuilt++
        return true
    }
    fun hireCart(at:CellPos=depot):Boolean {
        if(carts.size>=8 || (at!=depot && at !in stationNodes()))return false
        carts.add(Mine2Cart((carts.maxOfOrNull{it.id}?:0)+1,at.x,at.y))
        return true
    }
    fun addPile(at:CellPos,material:String,amount:Int) {
        if(amount<=0)return
        val contents=piles.getOrPut(at){mutableMapOf()}
        contents[material]=(contents[material]?:0)+amount
    }
    private fun route(from:CellPos,to:CellPos):List<CellPos>{
        if(from !in rails || to !in rails)return emptyList()
        if(from==to)return listOf(from)
        val queue=ArrayDeque<CellPos>()
        val parent=mutableMapOf(from to from)
        queue.add(from)
        while(queue.isNotEmpty()){
            val at=queue.removeFirst()
            for(n in neighbors(at)){
                if(n !in rails || n in parent)continue
                parent[n]=at
                if(n==to){
                    val result=mutableListOf(n)
                    var cursor=n
                    while(cursor!=from){
                        cursor=parent.getValue(cursor)
                        result.add(cursor)
                    }
                    return result.asReversed()
                }
                queue.addLast(n)
            }
        }
        return emptyList()
    }
    /**
     * Auto dispatch chooses the shortest connected route, penalising piles that
     * other idle carts already selected. One edge per 500ms, no artificial pause.
     * Loading takes a tick; upgraded lift unloads 1..6 wagons per tick.
     */
    fun step(world:Mine2World):List<Mine2Delivery>{
        transportTicksV4++
        advanceRailProjects(world)
        val arrivals=mutableListOf<Mine2Delivery>()
        var liftUsed=0
        var waitingForRail=false
        var congestion=false
        val reserved=mutableMapOf<CellPos,Int>()
        val dropoffs=listOf(depot)+stationNodes()
        for(cart in carts){
            val at=CellPos(cart.x,cart.y)
            if(cart.amount>0){
                val nearest=dropoffs.mapNotNull{drop->
                    val path=route(at,drop)
                    if(path.isEmpty())null else drop to path
                }.minByOrNull{it.second.size}
                if(nearest==null){waitingForRail=true;continue}
                val (drop,path)=nearest
                if(at==drop){
                    val material=cart.material?:continue
                    val amount=cart.amount
                    if(drop==depot){
                        if(liftUsed>=liftCapacity()){congestion=true;continue}
                        world.removeFromUndergroundStockpile(material,amount)
                        delivered[material]=(delivered[material]?:0)+amount
                        arrivals.add(Mine2Delivery(material,amount))
                        liftUsed++
                    }else if(liftNetworkV5?.deposit(drop,material,amount)!=true){
                        continue
                    }
                    cart.material=null
                    cart.amount=0
                }else if(path.size>1){
                    cart.x=path[1].x
                    cart.y=path[1].y
                    cartTravelStepsV4++
                }
                continue
            }
            var target:CellPos?=null
            var pathToTarget:List<CellPos>?=null
            var bestScore=Int.MAX_VALUE
            for((place,materials) in piles){
                val count=materials.values.sum()
                if(count<=0)continue
                val candidate=route(at,place)
                if(candidate.isEmpty())continue
                val already=reserved[place]?:0
                // Prefer distributing across piles with useful remaining ore.
                val score=candidate.size+already*6+
                    if(count<=already*cartCapacity())12 else 0
                if(score<bestScore){
                    bestScore=score
                    target=place
                    pathToTarget=candidate
                }
            }
            val destination=target
            val path=pathToTarget
            if(destination==null || path==null){
                if(piles.isNotEmpty())waitingForRail=true
                continue
            }
            reserved[destination]=(reserved[destination]?:0)+1
            if(path.size>1){
                cart.x=path[1].x
                cart.y=path[1].y
                cartTravelStepsV4++
            }else{
                val pile=piles[destination]?:continue
                val resource=pile.entries.firstOrNull{it.value>0}?.key?:continue
                val amount=min(cartCapacity(),pile.getValue(resource))
                if(amount<=0)continue
                pile[resource]=pile.getValue(resource)-amount
                if(pile.values.all{it==0})piles.remove(destination)
                cart.material=resource
                cart.amount=amount
                loadedTripsV4++
            }
        }
        liftNetworkV5?.step(world,this)
        if(waitingForRail)idleWithoutRailV4++
        if(congestion)liftCongestionTicksV4++
        return arrivals
    }
}
