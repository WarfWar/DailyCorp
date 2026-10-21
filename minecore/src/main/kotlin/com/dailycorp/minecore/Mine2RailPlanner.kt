package com.dailycorp.minecore

import java.io.Serializable
import java.util.ArrayDeque

/** One affordable rail segment per mine tick, along an existing open tunnel. */
data class Mine2RailQuote(
    val destination:CellPos,
    val valid:Boolean,
    val reason:String,
    val path:List<CellPos> = emptyList(),
    val price:Long=0L
)
data class Mine2RailProject(
    val destination:CellPos,
    val path:List<CellPos>,
    val paid:Long,
    var nextIndex:Int=0,
    var blocked:Boolean=false
):Serializable{
    val completed:Boolean get()=nextIndex>=path.size
    val remaining:Int get()=path.size-nextIndex
}

/** Uses only explored traversable cells; unknown geology never grants free access. */
object Mine2RailPlanner {
    private val directions=listOf(CellPos(1,0),CellPos(-1,0),
        CellPos(0,1),CellPos(0,-1))
    private const val MAX_PATH=160
    private const val MAX_SEARCH=4000

    fun quote(world:Mine2World,t:Mine2Transport,to:CellPos):Mine2RailQuote{
        fun invalid(reason:String)=Mine2RailQuote(to,false,reason)
        val target=world.cell(to.x,to.y)?:return invalid("Вне шахты")
        if(!target.explored || !target.passable)
            return invalid("Авто-рельсы прокладываются только по открытым тоннелям")
        if(to in t.rails)return invalid("В этом месте рельсы уже есть")
        if(t.railProjects().any{!it.completed && !it.blocked})
            return invalid("Сначала дождись завершения текущего маршрута")
        // Multiple source stations are legitimate starts of independent rail lines.
        val q=ArrayDeque<CellPos>()
        val parent=mutableMapOf<CellPos,CellPos>()
        for(source in t.rails){
            if(world.cell(source.x,source.y)?.passable==true){
                q.add(source)
                parent[source]=source
            }
        }
        if(q.isEmpty())return invalid("Нет начальной рельсовой станции")
        while(q.isNotEmpty() && parent.size<MAX_SEARCH){
            val at=q.removeFirst()
            if(at==to)break
            for(d in directions){
                val next=CellPos(at.x+d.x,at.y+d.y)
                if(next in parent)continue
                val cell=world.cell(next.x,next.y)?:continue
                if(!cell.explored || !cell.passable)continue
                parent[next]=at
                q.add(next)
            }
        }
        if(to !in parent)return invalid("Нет открытого пути к существующим рельсам")
        val reversed=mutableListOf<CellPos>()
        var cur=to
        while(cur !in t.rails){
            reversed.add(cur)
            cur=parent[cur]?:return invalid("Маршрут не найден")
            if(reversed.size>MAX_PATH)return invalid("Маршрут длиннее 160 клеток: разбей на участки")
        }
        reversed.reverse()
        val price=reversed.indices.sumOf{index->
            60L+10L*((t.totalRailBuilt+index)/12)
        }
        return Mine2RailQuote(to,true,"Маршрут готов",reversed,price)
    }
}
