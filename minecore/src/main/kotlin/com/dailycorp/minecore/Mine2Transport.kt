package com.dailycorp.minecore

import java.io.Serializable
import java.util.ArrayDeque
import kotlin.math.min

/** Mine2 v0.14 rail logistics: the only way to move fresh ore out of a heading
 * is to lay a connected rail, hire a cart, load it and drive it back to the lift.
 * Physically transported ore is removed from the underground stockpile ON unload.
 */
data class Mine2Cart(
    val id:Int,
    var x:Int,
    var y:Int,
    var material:String?=null,
    var amount:Int=0
):Serializable

data class Mine2Delivery(val material:String,val amount:Int):Serializable

class Mine2Transport(private val depot:CellPos):Serializable {
    companion object { private const val serialVersionUID=1L }
    val rails:MutableSet<CellPos> = mutableSetOf()
    val piles:MutableMap<CellPos,MutableMap<String,Int>> = mutableMapOf()
    val carts:MutableList<Mine2Cart> = mutableListOf()
    /** Cargo after physical rail transport and unloading into the shaft lift. */
    val delivered:MutableMap<String,Int> = mutableMapOf()
    var totalRailBuilt=0
        private set

    init {
        // Starter infrastructure: horizontal station plus connected hoist track.
        for(x in depot.x-4..depot.x+4) rails.add(CellPos(x,depot.y))
        for(y in 0..5)rails.add(CellPos(depot.x,y))
    }
    fun railPrice():Long=60L+10L*(totalRailBuilt/12)
    fun cartPrice():Long=750L+350L*carts.size
    fun cartCapacity():Int=5
    fun railAt(p:CellPos):Boolean=p in rails
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
    fun hireCart():Boolean {
        if(carts.size>=8)return false
        val id=(carts.maxOfOrNull{it.id}?:0)+1
        carts.add(Mine2Cart(id,depot.x,depot.y))
        return true
    }
    fun addPile(at:CellPos,material:String,amount:Int) {
        if(amount<=0)return
        val materials=piles.getOrPut(at){mutableMapOf()}
        materials[material]=(materials[material]?:0)+amount
    }
    private fun neighbors(p:CellPos)=listOf(
        CellPos(p.x-1,p.y),CellPos(p.x+1,p.y),
        CellPos(p.x,p.y-1),CellPos(p.x,p.y+1)
    )
    private fun route(from:CellPos,to:CellPos):List<CellPos> {
        if(from !in rails || to !in rails)return emptyList()
        if(from==to)return listOf(from)
        val queue=ArrayDeque<CellPos>()
        val parent=mutableMapOf(from to from)
        queue.add(from)
        while(queue.isNotEmpty()) {
            val at=queue.removeFirst()
            for(n in neighbors(at)) {
                if(n !in rails || n in parent)continue
                parent[n]=at
                if(n==to) {
                    val result=mutableListOf(n)
                    var cursor=n
                    while(cursor!=from) {
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
     * One movement edge per 500ms mine tick. Never sleeps on intermediate cells.
     * Loading/unloading each consume one tick (and unloading has one-lift
     * capacity per tick). All carts share one depot, so cargo never teleports.
     */
    fun step(world:Mine2World):List<Mine2Delivery> {
        val arrivals=mutableListOf<Mine2Delivery>()
        var liftUsed=false
        for(cart in carts) {
            val at=CellPos(cart.x,cart.y)
            if(cart.amount>0) {
                if(at==depot) {
                    if(liftUsed)continue
                    liftUsed=true
                    val material=cart.material?:continue
                    val amount=cart.amount
                    delivered[material]=(delivered[material]?:0)+amount
                    world.removeFromUndergroundStockpile(material,amount)
                    arrivals.add(Mine2Delivery(material,amount))
                    cart.material=null
                    cart.amount=0
                } else {
                    val path=route(at,depot)
                    if(path.size>1){
                        cart.x=path[1].x
                        cart.y=path[1].y
                    }
                }
                continue
            }
            var bestPos:CellPos?=null
            var bestRoute:List<CellPos>?=null
            for((place,materials) in piles) {
                if(materials.values.none{it>0})continue
                val path=route(at,place)
                if(path.isNotEmpty() && (bestRoute==null || path.size<bestRoute.size)){
                    bestRoute=path
                    bestPos=place
                }
            }
            val target=bestPos?:continue
            val path=bestRoute!!
            if(path.size>1){
                cart.x=path[1].x
                cart.y=path[1].y
            }else{
                val pile=piles[target]?:continue
                val material=pile.entries.firstOrNull{it.value>0}?.key?:continue
                val amount=min(cartCapacity(),pile.getValue(material))
                pile[material]=pile.getValue(material)-amount
                if(pile.values.all{it==0})piles.remove(target)
                cart.material=material
                cart.amount=amount
            }
        }
        return arrivals
    }
}
