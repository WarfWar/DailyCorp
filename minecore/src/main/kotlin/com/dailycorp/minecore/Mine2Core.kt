package com.dailycorp.minecore

import java.io.Serializable
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** No Android types here. All world state is deterministic and serializable. */
data class Mine2Config(
    val seed: Long,
    val width: Int = 52,
    val depthCells: Int = 240,
    val metersPerCell: Int = 5,
    val ores: List<String> = listOf("coal","iron","copper","gold")
) : Serializable {
    init {
        require(width in 20..160)
        require(depthCells in 48..1600)
        require(metersPerCell in 1..20)
        require(ores.isNotEmpty())
    }
}
data class CellPos(val x:Int,val y:Int):Serializable
enum class RockKind { SOIL, ROCK, HARD_ROCK, DEEP_ROCK, BEDROCK, ORE, TUNNEL, SHAFT }
data class RockCell(
    var kind:RockKind,
    val resource:String?=null,
    var deposit:Int=0,
    val grade:Int=1,
    var hardness:Int=1,
    var explored:Boolean=false,
    var ordered:Boolean=false
):Serializable {
    val passable:Boolean get()=kind==RockKind.TUNNEL || kind==RockKind.SHAFT
}
data class Mine2Chunk(
    val index:Int,
    val rows:Int,
    val cells:MutableList<MutableList<RockCell>>
):Serializable

/** Deterministic continuous value-noise: inputs are global coordinates,
 * so adjacent chunks meet without seams in geology. */
object Mine2Geology {
    const val CHUNK_ROWS=24
    private fun random(x:Int,y:Int,seed:Long):Double {
        var z=seed xor (x.toLong()*0x4F1BBCDCBFA54029L) xor
            (y.toLong()*0x369DEA0F31A53F85L)
        z=(z xor (z ushr 30))*-4658895280553007687L
        z=(z xor (z ushr 27))*-7723592293110705685L
        z=z xor (z ushr 31)
        return (z ushr 11).toDouble()/9007199254740992.0*2.0-1.0
    }
    private fun fade(v:Double)=v*v*(3.0-2.0*v)
    private fun lerp(a:Double,b:Double,t:Double)=a+(b-a)*t
    private fun noise(x:Double,y:Double,seed:Long):Double {
        val ix=floor(x).toInt();val iy=floor(y).toInt()
        val fx=fade(x-ix);val fy=fade(y-iy)
        return lerp(lerp(random(ix,iy,seed),random(ix+1,iy,seed),fx),
            lerp(random(ix,iy+1,seed),random(ix+1,iy+1,seed),fx),fy)
    }
    private fun oreAt(config:Mine2Config,x:Int,y:Int):Pair<String,Int>? {
        if(y<5 || y>=config.depthCells-1 || x<2 || x>=config.width-2)return null
        val main=noise(x/8.2,y/12.0,config.seed xor 0x17AC992004A21EEFL)
        val detail=noise(x/3.1,y/4.7,config.seed xor 0x7DF12A9310EFD2B1L)
        val field=main*0.76+detail*0.24
        if(field<0.20)return null
        val index=(noise(x/19.0,y/21.0,config.seed xor 0x6358219A13F4BB17L)+1.0)*0.499
        val selected=config.ores[(index*config.ores.size).toInt().coerceIn(0,config.ores.lastIndex)]
        val grade=(1+(field*3.0).toInt()).coerceIn(1,4)
        return selected to grade
    }
    fun generate(config:Mine2Config,index:Int):Mine2Chunk {
        require(index>=0 && index*CHUNK_ROWS<config.depthCells)
        val from=index*CHUNK_ROWS
        val height=min(CHUNK_ROWS,config.depthCells-from)
        val entry=config.width/2
        val cells=MutableList(height){localY ->
            val y=from+localY
            MutableList(config.width){x ->
                when {
                    x==0 || x==config.width-1 || y==config.depthCells-1 ->
                        RockCell(RockKind.BEDROCK,hardness=Int.MAX_VALUE)
                    (x==entry && y in 0..5) ->
                        RockCell(RockKind.SHAFT,hardness=0)
                    (y==3 && x in (entry-4)..(entry+4)) ->
                        RockCell(RockKind.TUNNEL,hardness=0)
                    else -> {
                        val ore=oreAt(config,x,y)
                        if(ore!=null){
                            RockCell(RockKind.ORE,ore.first,
                                deposit=1+ore.second*2,grade=ore.second,
                                hardness=2+ore.second+y/35)
                        }else{
                            val rock=when {
                                y<10 -> RockKind.SOIL
                                y<55 -> RockKind.ROCK
                                y<125 -> RockKind.HARD_ROCK
                                else -> RockKind.DEEP_ROCK
                            }
                            RockCell(rock,hardness=1+y/28+
                                when(rock){
                                    RockKind.SOIL -> 1
                                    RockKind.ROCK -> 2
                                    RockKind.HARD_ROCK -> 4
                                    else -> 7
                                })
                        }
                    }
                }
            }
        }
        return Mine2Chunk(index,height,cells)
    }
}

data class Mine2StepResult(
    val excavated:Boolean,
    val minedMaterial:String?=null,
    val amount:Int=0,
    val remainingOrders:Int=0,
    val reason:String=""
)

/** Stage 1: no worker teleportation or city-economy integration.
 * A single abstract passage crew excavates only a reachable ordered frontier.
 */
class Mine2World(val config:Mine2Config):Serializable {
    companion object {
        private const val serialVersionUID=1L
        fun create(config:Mine2Config):Mine2World=Mine2World(config).apply {
            val entry=config.width/2
            reveal(entry,3,4)
            for(x in entry-4..entry+4)reveal(x,3,2)
        }
    }
    private val chunks=mutableMapOf<Int,Mine2Chunk>()
    val stockpile:MutableMap<String,Int> = mutableMapOf()
    var totalExcavated=0
        private set
    var surveysLeft=4
        private set
    var timeTicks=0L
        private set

    fun cell(x:Int,y:Int):RockCell? {
        if(x !in 0 until config.width || y !in 0 until config.depthCells)return null
        val index=y/Mine2Geology.CHUNK_ROWS
        val chunk=chunks.getOrPut(index){Mine2Geology.generate(config,index)}
        return chunk.cells[y%Mine2Geology.CHUNK_ROWS][x]
    }
    fun reveal(x:Int,y:Int,radius:Int):Int {
        var newly=0
        val r=radius.coerceIn(0,12)
        for(py in max(0,y-r)..min(config.depthCells-1,y+r))
            for(px in max(0,x-r)..min(config.width-1,x+r)){
                val dx=px-x;val dy=py-y
                if(dx*dx+dy*dy>r*r)continue
                val target=cell(px,py)?:continue
                if(!target.explored){target.explored=true;newly++}
            }
        return newly
    }
    fun survey(x:Int,y:Int):Int {
        if(surveysLeft<=0 || cell(x,y)==null)return 0
        // Must start near known terrain; can't uncover every deep deposit for free.
        var nearKnown=false
        for(yy in max(0,y-8)..min(config.depthCells-1,y+8))
            for(xx in max(0,x-8)..min(config.width-1,x+8)){
                if((xx-x)*(xx-x)+(yy-y)*(yy-y)<=64 &&
                    cell(xx,yy)?.explored==true)nearKnown=true
            }
        if(!nearKnown)return 0
        surveysLeft--
        return reveal(x,y,5)
    }
    fun orderArea(a:CellPos,b:CellPos):Int {
        var count=0
        val minX=max(1,min(a.x,b.x))
        val maxX=min(config.width-2,max(a.x,b.x))
        val minY=max(3,min(a.y,b.y))
        val maxY=min(config.depthCells-2,max(a.y,b.y))
        if(minX>maxX || minY>maxY)return 0
        // Limits mobile touch mistakes and runaway task queues.
        if((maxX-minX+1).toLong()*(maxY-minY+1)>300)return 0
        for(y in minY..maxY)for(x in minX..maxX){
            val c=cell(x,y)?:continue
            if(c.explored && c.kind !in listOf(RockKind.BEDROCK,RockKind.SHAFT,
                RockKind.TUNNEL) && !c.ordered){
                c.ordered=true
                count++
            }
        }
        return count
    }
    fun cancelOrders():Int {
        var count=0
        for(chunk in chunks.values)for(row in chunk.cells)for(c in row){
            if(c.ordered){c.ordered=false;count++}
        }
        return count
    }
    fun pendingCount():Int=chunks.values.sumOf{
        it.cells.sumOf{row->row.count{c->c.ordered}}
    }

    private fun reachable():Set<CellPos> {
        val queue=java.util.ArrayDeque<CellPos>()
        val entrance=CellPos(config.width/2,3)
        val visited=mutableSetOf(entrance)
        queue.add(entrance)
        while(queue.isNotEmpty()){
            val p=queue.removeFirst()
            for(q in listOf(CellPos(p.x+1,p.y),CellPos(p.x-1,p.y),
                CellPos(p.x,p.y+1),CellPos(p.x,p.y-1))){
                if(q in visited || cell(q.x,q.y)?.passable!=true)continue
                visited.add(q);queue.addLast(q)
            }
        }
        return visited
    }
    fun step(drillPower:Int=2):Mine2StepResult {
        timeTicks++
        val active=reachable()
        var choice:CellPos?=null
        for(pos in active){
            for(q in listOf(CellPos(pos.x+1,pos.y),CellPos(pos.x-1,pos.y),
                CellPos(pos.x,pos.y+1),CellPos(pos.x,pos.y-1))){
                val c=cell(q.x,q.y)
                if(c?.ordered==true && !c.passable && c.kind!=RockKind.BEDROCK){
                    if(choice==null || q.y<choice.y ||
                        (q.y==choice.y && q.x<choice.x))choice=q
                }
            }
        }
        if(choice==null)return Mine2StepResult(false,remainingOrders=pendingCount(),
            reason=if(pendingCount()==0)"Нет заданий" else "Нет доступного фронта")
        val target=cell(choice.x,choice.y)!!
        target.hardness-=drillPower.coerceAtLeast(1)
        if(target.hardness>0) return Mine2StepResult(false,
            remainingOrders=pendingCount(),reason="Проходка")
        val material=target.resource
        val mined=if(material==null)0 else target.deposit
        if(material!=null && mined>0){
            stockpile[material]=(stockpile[material]?:0)+mined
        }
        target.kind=RockKind.TUNNEL
        target.ordered=false
        target.deposit=0
        totalExcavated++
        reveal(choice.x,choice.y,2)
        return Mine2StepResult(true,material,mined,pendingCount(),"Проход проложен")
    }
}
