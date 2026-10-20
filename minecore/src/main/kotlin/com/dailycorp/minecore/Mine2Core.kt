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
    /** Common mineral lenses. Their outlines are driven by continuous world
     * fields; deposits vary deterministically on each cell inside the lens.
     */
    private fun basicAt(config:Mine2Config,x:Int,y:Int):String? {
        if(x<2 || x>=config.width-2 || y<5)return null
        val field=noise(x/11.0,y/11.5,config.seed xor 0x12F8AF6113FBC5E1L)*0.75+
            noise(x/3.8,y/5.2,config.seed xor 0x413A1BE557E1FAB7L)*0.25
        if(field<0.12)return null
        val index=(noise(x/27.0,y/24.0,config.seed xor 0x55438D716A9C4CB7L)+1.0)*0.5
        val options=when {
            y<25 -> listOf("clay","sand","gravel","salt","shale")
            y<95 -> listOf("gravel","granite","salt","sulfur","shale","clay")
            else -> listOf("granite","shale","sulfur","salt","gravel")
        }
        return options[(index*options.size).toInt().coerceIn(0,options.lastIndex)]
    }
    private fun resourceAmount(config:Mine2Config,x:Int,y:Int,grade:Int):Int {
        // Independent variation per cell without breaking the enclosing deposit.
        val local=random(x,y,config.seed xor 0x2461BB90772D319FL)
        val variation=((local+1.0)*0.5*max(3,grade*8)).toInt()
        return 1+variation+(y/85)
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
                        val baseMaterial=if(ore==null)basicAt(config,x,y)else null
                        if(ore!=null){
                            RockCell(RockKind.ORE,ore.first,
                                deposit=resourceAmount(config,x,y,ore.second),
                                grade=ore.second,
                                hardness=2+ore.second+y/35)
                        }else if(baseMaterial!=null){
                            val material=baseMaterial
                            val grade=(1+y/60).coerceIn(1,4)
                            RockCell(RockKind.ORE,material,
                                deposit=resourceAmount(config,x,y,grade),
                                grade=grade,hardness=2+grade+y/45)
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
    val reason:String="",
    val minersMoved:Int=0
)
data class Mine2Miner(
    val id:Int,
    var x:Int,
    var y:Int,
    var mining:Boolean=false,
    var target:CellPos?=null
):Serializable

data class SurveyQuote(
    val x:Int,
    val y:Int,
    val price:Long,
    val newCells:Int,
    val valid:Boolean,
    val reason:String
)
data class SurveyResult(
    val successful:Boolean,
    val charged:Long=0L,
    val cellsRevealed:Int=0,
    val reason:String=""
)

/** Mine 2.0 independent sandbox. Serializable UID kept for 0.6.0 saves.
 * Old snapshots deserialize minersV2=null, which is lazily migrated.
 */
class Mine2World(val config:Mine2Config):Serializable {
    companion object {
        private const val serialVersionUID=1L
        private val steps=listOf(CellPos(-1,0),CellPos(1,0),CellPos(0,-1),CellPos(0,1))
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
    // Kept for compatibility with already issued v0.6 snapshots. No free scans.
    var surveysLeft=4
        private set
    var surveysPerformed=0
        private set
    // Backward-compatible additions: old 0.7 saves deserialize these as 0/null.
    private var shaftLevelV2=0
    private var surveyFogV2:MutableSet<CellPos>?=null
    val shaftLevel:Int get()=max(1,shaftLevelV2)
    val crewLimit:Int get()=8+(shaftLevel-1)*4
    fun upgradePrice():Long=1300L*shaftLevel.toLong()*shaftLevel.toLong()
    fun canUpgrade():Boolean=shaftLevel<7
    fun upgradeShaft():Boolean {
        if(!canUpgrade())return false
        shaftLevelV2=shaftLevel+1
        return true
    }
    private fun surveyFog():MutableSet<CellPos> {
        if(surveyFogV2==null)surveyFogV2=mutableSetOf()
        return surveyFogV2!!
    }
    fun isSurveyDim(x:Int,y:Int):Boolean=CellPos(x,y) in surveyFog()
    private var minersV2:MutableList<Mine2Miner>?=null
    var timeTicks=0L
        private set

    fun miners():List<Mine2Miner> {
        if(minersV2==null)minersV2=mutableListOf(
            Mine2Miner(1,config.width/2,3)
        )
        return minersV2!!
    }
    fun hireMiner():Boolean {
        val workers=miners()
        if(workers.size>=crewLimit)return false
        val id=(workers.maxOfOrNull{it.id}?:0)+1
        minersV2!!.add(Mine2Miner(id,config.width/2,3))
        return true
    }
    fun cell(x:Int,y:Int):RockCell? {
        if(x !in 0 until config.width || y !in 0 until config.depthCells)return null
        val index=y/Mine2Geology.CHUNK_ROWS
        val chunk=chunks.getOrPut(index){Mine2Geology.generate(config,index)}
        return chunk.cells[y%Mine2Geology.CHUNK_ROWS][x]
    }
    fun reveal(x:Int,y:Int,radius:Int,fromSurvey:Boolean=false):Int {
        var newly=0
        val r=radius.coerceIn(0,12)
        for(py in max(0,y-r)..min(config.depthCells-1,y+r))
            for(px in max(0,x-r)..min(config.width-1,x+r)){
                val dx=px-x;val dy=py-y
                if(dx*dx+dy*dy>r*r)continue
                val target=cell(px,py)?:continue
                if(!target.explored){target.explored=true;newly++
                    if(fromSurvey)surveyFog().add(CellPos(px,py))
                }
                if(!fromSurvey)surveyFog().remove(CellPos(px,py))
            }
        return newly
    }
    /** The first survey costs 250 ₽. Each successive one costs 75 ₽
     * more; every 25 m of depth adds 20 ₽. No scanned or invalid cell is billed.
     */
    fun surveyQuote(x:Int,y:Int):SurveyQuote {
        if(cell(x,y)==null)return SurveyQuote(x,y,0,0,false,"Вне шахты")
        var nearKnown=false
        for(yy in max(0,y-10)..min(config.depthCells-1,y+10))
            for(xx in max(0,x-10)..min(config.width-1,x+10)){
                val dx=xx-x;val dy=yy-y
                if(dx*dx+dy*dy<=100 && cell(xx,yy)?.explored==true)
                    nearKnown=true
            }
        if(!nearKnown)return SurveyQuote(x,y,0,0,false,
            "Сначала разведай прилегающую область")
        var newCells=0
        for(py in max(0,y-8)..min(config.depthCells-1,y+8))
            for(px in max(0,x-8)..min(config.width-1,x+8)){
                val dx=px-x;val dy=py-y
                if(dx*dx+dy*dy<=64 && cell(px,py)?.explored==false)newCells++
            }
        if(newCells==0)return SurveyQuote(x,y,0,0,false,
            "Здесь уже всё исследовано")
        val depthMeters=y.toLong()*config.metersPerCell
        val price=450L+(depthMeters/25L)*20L+surveysPerformed.toLong()*75L
        return SurveyQuote(x,y,price,newCells,true,"Готово к разведке")
    }
    /** Validates balance in the core, not just Android button logic.
     * The app deducts charged from GameState.money and saves immediately.
     */
    fun surveyPaid(x:Int,y:Int,availableMoney:Long):SurveyResult {
        val quote=surveyQuote(x,y)
        if(!quote.valid)return SurveyResult(false,reason=quote.reason)
        if(availableMoney<quote.price)return SurveyResult(false,reason="Не хватает денег")
        val count=reveal(x,y,8,fromSurvey=true)
        if(count<=0)return SurveyResult(false,reason="Участок уже известен")
        surveysPerformed++
        surveysLeft=max(0,4-surveysPerformed)
        return SurveyResult(true,quote.price,count,"Разведка завершена")
    }
    fun orderArea(a:CellPos,b:CellPos):Int {
        var count=0
        val minX=max(1,min(a.x,b.x))
        val maxX=min(config.width-2,max(a.x,b.x))
        val minY=max(3,min(a.y,b.y))
        val maxY=min(config.depthCells-2,max(a.y,b.y))
        if(minX>maxX || minY>maxY)return 0
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
    private fun position(p:CellPos):RockCell?=cell(p.x,p.y)
    /** BFS only through open connected tunnels. The last passable cell
     * is a worksite adjacent to an ordered rock, so miners never dig through walls.
     */
    private fun nearestWork(worker:Mine2Miner,reserved:Set<CellPos>):
        Triple<CellPos,CellPos,Map<CellPos,CellPos>>? {
        val start=CellPos(worker.x,worker.y)
        if(position(start)?.passable!=true)return null
        val queue=java.util.ArrayDeque<CellPos>()
        val parent=hashMapOf(start to start)
        queue.add(start)
        while(queue.isNotEmpty()){
            val at=queue.removeFirst()
            for(d in steps){
                val next=CellPos(at.x+d.x,at.y+d.y)
                val block=position(next)?:continue
                if(block.ordered && !block.passable && block.kind!=RockKind.BEDROCK &&
                    next !in reserved) {
                    return Triple(at,next,parent)
                }
            }
            for(d in steps) {
                val next=CellPos(at.x+d.x,at.y+d.y)
                if(next !in parent && position(next)?.passable==true){
                    parent[next]=at
                    queue.addLast(next)
                }
            }
        }
        return null
    }
    /** Hardness for every subsequent unit (not for an entire cell). */
    fun oreWorkPerUnit(grade:Int,depthCell:Int):Int =
        (6 + grade*2 + depthCell/22).coerceAtMost(90)

    fun step(drillPower:Int=2):Mine2StepResult {
        timeTicks++
        var minedMaterial:String?=null
        var minedAmount=0
        var excavated=false
        var moved=0
        val reserved=mutableSetOf<CellPos>()
        for(worker in miners()) {
            worker.mining=false
            worker.target=null
            val work=nearestWork(worker,reserved)?:continue
            val stand=work.first
            val target=work.second
            reserved.add(target)
            worker.target=target
            val current=CellPos(worker.x,worker.y)
            if(current!=stand){
                // Backtrack the BFS path to the first adjacent open tile.
                var hop=stand
                while(work.third[hop]!=current && work.third[hop]!=hop){
                    hop=work.third[hop]?:break
                }
                if(position(hop)?.passable==true && hop!=current){
                    worker.x=hop.x
                    worker.y=hop.y
                    moved++
                }
                continue
            }
            worker.mining=true
            val block=position(target)?:continue
            // Each finished drilling cycle extracts at most ONE resource unit.
            // A 15-unit vein therefore lasts roughly 15 times longer than a 1-unit vein.
            block.hardness-=drillPower.coerceAtLeast(1)
            if(block.hardness>0)continue
            val material=block.resource
            if(block.kind==RockKind.ORE && material!=null && block.deposit>0){
                block.deposit--
                stockpile[material]=(stockpile[material]?:0)+1
                minedMaterial=material
                minedAmount++
                if(block.deposit>0){
                    // Persist drill progress in the existing hardness field; this
                    // avoids changing Java serialization IDs on existing saves.
                    block.hardness=oreWorkPerUnit(block.grade,target.y)
                    // Preserve the dig order until the deposit is exhausted.
                    continue
                }
            }
            block.kind=RockKind.TUNNEL
            block.ordered=false
            block.deposit=0
            block.hardness=0
            excavated=true
            totalExcavated++
            reveal(target.x,target.y,2)
        }
        return Mine2StepResult(excavated,minedMaterial,minedAmount,pendingCount(),
            if(excavated)"Проходка завершена" else if(moved>0)"Шахтёры перемещаются"
                else if(pendingCount()==0)"Нет заданий" else "Проходка или ожидание доступа",
            moved)
    }
}
