package com.dailycorp.minecore

import java.io.Serializable
import java.util.ArrayDeque

/** A connected component of discovered ore, including cells already excavated. */
data class Mine2VeinPlan(
    val family:String,
    val cells:MutableSet<CellPos> = mutableSetOf()
):Serializable

/** Serializes only player-established plans. Hidden geology is never exposed. */
class Mine2VeinAutomation:Serializable {
    companion object {
        private const val serialVersionUID=1L
        private const val MAX_CELLS_PER_PLAN=5000
        private val directions=listOf(CellPos(1,0),CellPos(-1,0),
            CellPos(0,1),CellPos(0,-1))
        /** Ore grade is not a mineral species. Other resource IDs stay exact. */
        fun family(material:String):String {
            val match=Regex("^ore_([0-9]+)_[0-9]+$").matchEntire(material)
            return if(match!=null)"ore_"+match.groupValues[1] else material
        }
        private fun adjacent(pos:CellPos)=directions.map{
            CellPos(pos.x+it.x,pos.y+it.y)
        }
    }
    var enabled:Boolean=true
        private set
    private val plans=mutableListOf<Mine2VeinPlan>()

    fun activePlans():Int=plans.size
    fun pendingCells(world:Mine2World):Int=plans.sumOf{plan->
        plan.cells.count{p->world.cell(p.x,p.y)?.ordered==true}
    }

    /** No automatic digging through undiscovered ore or other rocks. */
    private fun claim(world:Mine2World,start:CellPos,plan:Mine2VeinPlan) {
        val queue=ArrayDeque<CellPos>()
        queue.add(start)
        while(queue.isNotEmpty() && plan.cells.size<MAX_CELLS_PER_PLAN) {
            val p=queue.removeFirst()
            if(p in plan.cells)continue
            val c=world.cell(p.x,p.y)?:continue
            if(!c.explored || c.passable || c.kind!=RockKind.ORE ||
                c.deposit<=0 || family(c.resource?:continue)!=plan.family)continue
            // Another independently ordered component may be mining this cell.
            if(plans.any{it!==plan && p in it.cells})continue
            plan.cells.add(p)
            c.ordered=true
            for(n in adjacent(p))if(n !in plan.cells)queue.addLast(n)
        }
    }

    fun tap(world:Mine2World,p:CellPos):Boolean {
        val c=world.cell(p.x,p.y)?:return false
        if(!enabled || c.kind!=RockKind.ORE || c.resource==null)
            return world.toggleCellOrder(p)
        if(!c.explored || c.passable || c.deposit<=0)return false
        val existing=plans.firstOrNull{p in it.cells}
        if(existing!=null) {
            stopPlan(world,existing)
            return false
        }
        // Preserve manual orders instead of stealing them from the player.
        if(c.ordered){c.ordered=false;return false}
        val plan=Mine2VeinPlan(family(c.resource!!))
        plans.add(plan)
        claim(world,p,plan)
        if(plan.cells.isEmpty())plans.remove(plan)
        return c.ordered
    }

    /** New ore continues the original plan only via face-adjacent vein cells. */
    fun onReveal(world:Mine2World,discovered:List<CellPos>) {
        if(!enabled || plans.isEmpty())return
        for(p in discovered) {
            val c=world.cell(p.x,p.y)?:continue
            if(!c.explored || c.kind!=RockKind.ORE || c.deposit<=0)continue
            val material=c.resource?:continue
            val familyKey=family(material)
            val plan=plans.firstOrNull{
                it.family==familyKey && it.cells.size<MAX_CELLS_PER_PLAN &&
                    adjacent(p).any{neighbor->neighbor in it.cells}
            }?:continue
            claim(world,p,plan)
        }
    }

    private fun stopPlan(world:Mine2World,plan:Mine2VeinPlan) {
        for(p in plan.cells){
            val c=world.cell(p.x,p.y)?:continue
            if(!c.passable)c.ordered=false
        }
        plans.remove(plan)
    }
    fun clear(world:Mine2World){
        for(plan in plans.toList())stopPlan(world,plan)
    }
    fun setEnabled(world:Mine2World,on:Boolean) {
        if(!on)clear(world)
        enabled=on
    }
}
