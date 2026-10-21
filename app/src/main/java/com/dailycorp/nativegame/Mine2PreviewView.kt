package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import com.dailycorp.minecore.*
import kotlin.math.*

/** Continuous pan and pinch. TWO taps on the same rock order/cancel extraction.
 * The only temporary tool is the paid scouting scanner.
 */
class Mine2PreviewView(context:Context,val world:Mine2World):View(context) {
    enum class Mode { NORMAL, SURVEY, RAIL, LIFT }
    var mode=Mode.NORMAL
    var onPlan:((CellPos,CellPos)->Unit)?=null
    var onSurvey:((CellPos)->Unit)?=null
    var onRail:((CellPos)->Unit)?=null
    var onLift:((CellPos)->Unit)?=null
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val art=GameArt(context)
    private val blocks=MineBlockAtlas(context)
    private val sprites=MineSpriteFrames(context)
    private val tracks=mutableMapOf<Int,Mine2MotionTrack>()
    private val cartTracks=mutableMapOf<Int,Mine2MotionTrack>()
    private val facing=mutableMapOf<Int,Boolean>()
    private val previousX=mutableMapOf<Int,Int>()
    private var scanAt:CellPos?=null
    private var scanStarted=0L
    fun scanPulse(cell:CellPos){
        scanAt=cell
        scanStarted=android.os.SystemClock.uptimeMillis()
        invalidate()
    }
    fun resetScanner(){ mode=Mode.NORMAL;invalidate() }
    private val unit=33f*resources.displayMetrics.density
    private var zoom=1f
    private var panX=0f
    private var panY=0f
    private var lastX=0f
    private var lastY=0f
    private var firstX=0f
    private var firstY=0f
    private var moved=false
    private var multi=false
    private val scale=ScaleGestureDetector(context,object:ScaleGestureDetector.SimpleOnScaleGestureListener(){
        override fun onScale(e:ScaleGestureDetector):Boolean{
            zoom=(zoom*e.scaleFactor).coerceIn(0.5f,2.4f)
            invalidate()
            return true
        }
    })
    private fun tile()=unit*zoom
    private fun ox()=width*0.5f-world.config.width*tile()*0.5f+panX
    private fun oy()=height*0.25f-3f*tile()+panY
    private fun cellAt(x:Float,y:Float)=CellPos(
        floor((x-ox())/tile()).toInt(),
        floor((y-oy())/tile()).toInt()
    )
    fun moveDepth(cells:Int){panY-=cells*tile();invalidate()}
    fun surface(){panX=0f;panY=0f;invalidate()}
    private fun fill(color:Int){
        paint.color=color;paint.style=Paint.Style.FILL;paint.strokeWidth=1f
    }
    private fun terrain(c:RockCell):Int=when(c.kind){
        RockKind.SOIL->Color.rgb(64,50,41)
        RockKind.ROCK->Color.rgb(53,53,55)
        RockKind.HARD_ROCK->Color.rgb(42,43,49)
        RockKind.DEEP_ROCK->Color.rgb(29,30,34)
        RockKind.BEDROCK->Color.rgb(11,12,15)
        RockKind.ORE->Color.rgb(78,58,40)
        RockKind.TUNNEL->Color.rgb(15,16,19)
        RockKind.SHAFT->Color.rgb(23,24,28)
    }
    private fun asset(c:RockCell):String=when(c.kind){
        RockKind.SOIL->"mine.soil"
        RockKind.ROCK->"mine.stone"
        RockKind.HARD_ROCK->"mine.deep_stone"
        RockKind.DEEP_ROCK,RockKind.BEDROCK->"mine.abyss"
        RockKind.TUNNEL->"mine.empty"
        RockKind.SHAFT->"mine.shaft"
        RockKind.ORE->when(c.resource){
            "coal"->"mine.coal"
            "iron"->"mine.iron"
            "copper"->"mine.copper"
            "gold"->"mine.gold"
            "clay","sand"->"mine.soil"
            "gravel","granite"->"mine.stone"
            "salt"->"mine.quartz"
            "sulfur"->"mine.gold"
            "shale"->"mine.deep_stone"
            else->"mine.quartz"
        }
    }
    private fun smallLabel(c:RockCell):String=when(c.resource){
        "clay"->"Гл";"sand"->"Пс";"gravel"->"Гр"
        "granite"->"Гн";"salt"->"Сл";"sulfur"->"Sr"
        "shale"->"Сн";else->""
    }
    override fun onDraw(canvas:Canvas){
        canvas.drawColor(Color.rgb(2,2,3))
        val t=tile();val left=ox();val top=oy()
        val x0=max(0,floor(-left/t).toInt()-1)
        val x1=min(world.config.width-1,floor((width-left)/t).toInt()+1)
        val y0=max(0,floor(-top/t).toInt()-1)
        val y1=min(world.config.depthCells-1,floor((height-top)/t).toInt()+1)
        if(x0>x1||y0>y1)return
        for(y in y0..y1){
            for(x in x0..x1){
                val c=world.cell(x,y)?:continue
                val l=left+x*t;val p=top+y*t
                fill(if(c.explored)terrain(c) else Color.rgb(6,6,8))
                canvas.drawRect(l,p,l+t+0.6f,p+t+0.6f,paint)
                if(x==0||x==world.config.width-1){
                    fill(Color.rgb(109,84,51))
                    canvas.drawRect(l+2,p+2,l+t-2,p+t-2,paint)
                    fill(Color.rgb(35,31,28))
                    canvas.drawRect(l+7,p+6,l+t-7,p+t-6,paint)
                    paint.color=Color.rgb(225,170,71)
                    paint.strokeWidth=max(1.5f,t*0.035f)
                    canvas.drawLine(l+3,p+3,l+t-3,p+t-3,paint)
                    continue
                }
                if(!c.explored)continue
                if(zoom>0.53f){
                    val texture=when(c.kind) {
                        RockKind.SOIL -> "terrain_soil"
                        RockKind.ROCK,RockKind.HARD_ROCK,RockKind.DEEP_ROCK -> "terrain_stone"
                        RockKind.BEDROCK -> "terrain_bedrock"
                        RockKind.ORE -> c.resource?.let {MineBlockAtlas.textureForMaterial(it)}
                        else -> null
                    }
                    if(texture==null || !blocks.draw(canvas,texture,l,p,l+t+0.5f,p+t+0.5f))
                        art.draw(canvas,asset(c),l,p,l+t+0.5f,p+t+0.5f)
                }
                val shadow=when {
                    world.isSurveyDim(x,y) -> 112
                    c.kind==RockKind.DEEP_ROCK -> 58
                    c.kind==RockKind.HARD_ROCK -> 32
                    else -> 20
                }
                fill(Color.argb(shadow,0,0,0))
                canvas.drawRect(l,p,l+t+0.5f,p+t+0.5f,paint)
                if(c.kind==RockKind.ORE && c.deposit>0){
                    // Remaining resource units, plus drilling progress per unit.
                    val indicator="${c.deposit}"
                    val w=t*0.53f
                    fill(Color.argb(223,10,11,13))
                    canvas.drawRoundRect(RectF(l+t-w-2,p+2,l+t-2,p+t*0.37f),
                        t*0.05f,t*0.05f,paint)
                    fill(Color.rgb(249,221,147))
                    paint.textSize=max(10f*resources.displayMetrics.scaledDensity,t*0.23f)
                    canvas.drawText(c.deposit.toString(),l+t-w+3,p+t*0.28f,paint)
                    val progress=(1f-c.hardness.toFloat()/
                        world.oreWorkPerUnit(c.grade,y).toFloat()).coerceIn(0f,1f)
                    fill(Color.rgb(20,21,23))
                    canvas.drawRect(l+2,p+t-t*0.115f,l+t-2,p+t-2,paint)
                    fill(Color.rgb(242,183,75))
                    canvas.drawRect(l+2,p+t-t*0.115f,
                        l+2+(t-4)*progress,p+t-2,paint)
                }else if(c.kind==RockKind.ORE && t>30f){
                    val label=smallLabel(c)
                    if(label.isNotEmpty()){
                        fill(Color.rgb(229,203,149));paint.textSize=t*0.19f
                        canvas.drawText(label,l+t*0.08f,p+t*0.78f,paint)
                    }
                }
                if(c.ordered){
                    fill(Color.argb(73,245,178,56))
                    canvas.drawRect(l+2,p+2,l+t-2,p+t-2,paint)
                    paint.style=Paint.Style.STROKE;paint.strokeWidth=max(2f,t*0.045f)
                    paint.color=Color.rgb(248,209,104)
                    canvas.drawRect(l+2,p+2,l+t-2,p+t-2,paint)
                    paint.style=Paint.Style.FILL
                }
                if(c.kind==RockKind.TUNNEL){
                    fill(Color.rgb(122,97,73))
                    canvas.drawRect(l,p+t*0.85f,l+t,p+t*0.92f,paint)
                }
            }
            if(y%10==0){
                val py=top+y*t
                fill(Color.argb(200,11,12,14))
                canvas.drawRoundRect(RectF(4f,py,100f*resources.displayMetrics.density,
                    py+22f*resources.displayMetrics.density),4f,4f,paint)
                fill(Color.WHITE);paint.textSize=12f*resources.displayMetrics.scaledDensity
                canvas.drawText((y*world.config.metersPerCell).toString()+" м",
                    12f*resources.displayMetrics.density,
                    py+16f*resources.displayMetrics.density,paint)
            }
        }
        world.existingTransport()?.lifts()?.forEach{site->
            if(site.x in x0..x1){
                val l=left+site.x*t
                val begin=max(3,y0)
                val finish=min(site.builtToY,y1)
                if(begin<=finish){
                    fill(Color.rgb(100,82,55))
                    canvas.drawRect(l+t*0.1f,top+begin*t,
                        l+t*0.16f,top+(finish+1)*t,paint)
                    canvas.drawRect(l+t*0.84f,top+begin*t,
                        l+t*0.9f,top+(finish+1)*t,paint)
                }
            }
        }
        // Rail infrastructure is overlaid on excavated passages, never on ore.
        world.existingTransport()?.let{transport->
            for(p in transport.rails){
                if(p.x !in x0..x1 || p.y !in y0..y1)continue
                val cell=world.cell(p.x,p.y)?:continue
                if(!cell.passable)continue
                val l=left+p.x*t;val topY=top+p.y*t
                fill(Color.rgb(126,102,68))
                val horizontal=transport.railAt(CellPos(p.x-1,p.y)) ||
                    transport.railAt(CellPos(p.x+1,p.y))
                if(horizontal){
                    canvas.drawRect(l+t*0.05f,topY+t*0.73f,
                        l+t*0.95f,topY+t*0.79f,paint)
                    canvas.drawRect(l+t*0.05f,topY+t*0.91f,
                        l+t*0.95f,topY+t*0.97f,paint)
                    for(i in 1..3){
                        val x=l+i*t/4f
                        fill(Color.rgb(169,142,96))
                        canvas.drawRect(x-t*0.028f,topY+t*0.71f,
                            x+t*0.028f,topY+t*0.99f,paint)
                    }
                }else{
                    canvas.drawRect(l+t*0.27f,topY,
                        l+t*0.32f,topY+t,paint)
                    canvas.drawRect(l+t*0.68f,topY,
                        l+t*0.73f,topY+t,paint)
                }
            }
            for((p,materials) in transport.piles){
                if(p.x !in x0..x1 || p.y !in y0..y1)continue
                val amount=materials.values.sum()
                if(amount<=0)continue
                val l=left+p.x*t;val y=top+p.y*t
                fill(Color.rgb(180,122,67))
                canvas.drawOval(RectF(l+t*0.22f,y+t*0.62f,
                    l+t*0.78f,y+t*0.90f),paint)
                fill(Color.rgb(254,222,149))
                paint.textSize=max(9f*resources.displayMetrics.scaledDensity,t*0.23f)
                canvas.drawText(amount.toString(),l+t*0.36f,y+t*0.59f,paint)
            }
        }
        val now=android.os.SystemClock.uptimeMillis()
        var animating=false
        tracks.keys.retainAll(world.miners().map{it.id}.toSet())
        for(worker in world.miners()){
            val track=tracks.getOrPut(worker.id){
                Mine2MotionTrack(worker.x.toFloat(),worker.y.toFloat(),515L)
            }
            val oldX=previousX[worker.id]
            if(oldX!=null && worker.x!=oldX)facing[worker.id]=worker.x>oldX
            previousX[worker.id]=worker.x
            track.target(worker.x.toFloat(),worker.y.toFloat(),now)
            val moving=track.moving(now)
            if(moving||worker.mining)animating=true
            val pos=track.position(now)
            val cx=left+(pos.x+0.5f)*t
            val cy=top+(pos.y+0.91f)*t
            if(cx+t<0 || cx-t>width || cy+t<0 || cy-t>height)continue
            val right=if(worker.mining && worker.target!=null){
                worker.target!!.x>=worker.x
            }else facing[worker.id]?:true
            val sprite=if(worker.mining) {
                if(right)"miner_mine_right" else "miner_mine_left"
            }else if(moving){
                if(right)"miner_walk_right" else "miner_walk_left"
            }else if(right)"miner_idle_right" else "miner_idle_left"
            if(!sprites.draw(canvas,sprite,cx,cy,t,now,worker.id)){
                fill(Color.rgb(65,149,175))
                canvas.drawRoundRect(RectF(cx-t*0.13f,cy-t*0.34f,
                    cx+t*0.13f,cy-t*0.08f),t*0.05f,t*0.05f,paint)
                fill(Color.rgb(252,205,131))
                canvas.drawCircle(cx,cy-t*0.45f,t*0.14f,paint)
                fill(Color.rgb(255,206,63))
                canvas.drawRect(cx-t*0.15f,cy-t*0.58f,
                    cx+t*0.15f,cy-t*0.50f,paint)
            }
            if(t>24f){
                fill(Color.WHITE);paint.textSize=t*0.19f
                canvas.drawText(worker.id.toString(),cx-t*0.08f,cy-t*0.15f,paint)
            }
        }
        world.existingTransport()?.let{transport->
            cartTracks.keys.retainAll(transport.carts.map{it.id}.toSet())
            for(cart in transport.carts){
                val track=cartTracks.getOrPut(cart.id){
                    Mine2MotionTrack(cart.x.toFloat(),cart.y.toFloat(),500L)
                }
                track.target(cart.x.toFloat(),cart.y.toFloat(),now)
                val moving=track.moving(now)
                if(moving)animating=true
                val pos=track.position(now)
                val x=left+(pos.x+0.5f)*t
                val feet=top+(pos.y+0.96f)*t
                if(x+t<0 || x-t>width || feet+t<0 || feet-t>height)continue
                val name=when{
                    moving && cart.amount>0 -> "cart_move_loaded"
                    moving -> "cart_move_empty"
                    cart.amount>0 -> "cart_idle_loaded"
                    else -> "cart_idle_empty"
                }
                if(!sprites.draw(canvas,name,x,feet,t,now,cart.id)){
                    fill(Color.rgb(194,124,67))
                    canvas.drawRoundRect(RectF(x-t*0.37f,feet-t*0.57f,
                        x+t*0.37f,feet-t*0.22f),t*0.06f,t*0.06f,paint)
                    fill(Color.rgb(51,53,56))
                    canvas.drawCircle(x-t*0.24f,feet-t*0.17f,t*0.075f,paint)
                    canvas.drawCircle(x+t*0.24f,feet-t*0.17f,t*0.075f,paint)
                }
            }
        }
        scanAt?.let{p->
            val age=now-scanStarted
            if(age in 0..1300L){
                animating=true
                val ratio=age/1300f
                paint.color=Color.argb(((1f-ratio)*170).toInt().coerceIn(0,255),
                    239,178,69)
                paint.style=Paint.Style.STROKE;paint.strokeWidth=max(2f,t*0.06f)
                canvas.drawCircle(left+(p.x+0.5f)*t,top+(p.y+0.5f)*t,
                    (1f+8f*ratio)*t,paint)
                paint.style=Paint.Style.FILL
            }else scanAt=null
        }
        val density=resources.displayMetrics.density
        val borderL=left+t
        val borderR=left+(world.config.width-1)*t
        paint.color=Color.rgb(222,157,73);paint.strokeWidth=2*density
        if(borderL in 0f..width.toFloat())
            canvas.drawLine(borderL,0f,borderL,height.toFloat(),paint)
        if(borderR in 0f..width.toFloat())
            canvas.drawLine(borderR,0f,borderR,height.toFloat(),paint)
        fill(Color.argb(205,10,10,12))
        canvas.drawRoundRect(RectF(4*density,6*density,width-4*density,
            29*density),4*density,4*density,paint)
        fill(Color.rgb(232,183,113))
        paint.textSize=10*resources.displayMetrics.scaledDensity
        val leftCells=max(0,((width*0.5f-left)/t).toInt())
        val rightCells=max(0,world.config.width-leftCells-1)
        canvas.drawText("◀ Граница: "+leftCells+" кл.",
            10*density,22*density,paint)
        val msg="Граница: "+rightCells+" кл. ▶"
        canvas.drawText(msg,width-10*density-paint.measureText(msg),
            22*density,paint)
        if(animating && isAttachedToWindow)postInvalidateDelayed(42L)
    }
    override fun onTouchEvent(e:MotionEvent):Boolean{
        scale.onTouchEvent(e)
        when(e.actionMasked){
            MotionEvent.ACTION_DOWN->{
                lastX=e.x;lastY=e.y;firstX=e.x;firstY=e.y
                moved=false;multi=false
                return true
            }
            MotionEvent.ACTION_POINTER_DOWN->{multi=true;return true}
            MotionEvent.ACTION_MOVE->{
                if(e.pointerCount==1&&!scale.isInProgress&&!multi){
                    if(hypot(e.x-firstX,e.y-firstY)>8f*resources.displayMetrics.density)
                        moved=true
                    if(moved){
                        panX+=e.x-lastX;panY+=e.y-lastY
                    }
                    lastX=e.x;lastY=e.y
                    invalidate()
                }
                return true
            }
            MotionEvent.ACTION_UP->{
                if(!moved&&!multi&&!scale.isInProgress){
                    val p=cellAt(e.x,e.y)
                    if(mode==Mode.SURVEY){
                        onSurvey?.invoke(p)
                    }else if(mode==Mode.RAIL){
                        onRail?.invoke(p)
                    }else if(mode==Mode.LIFT){
                        onLift?.invoke(p)
                    }else{
                        val c=world.cell(p.x,p.y)
                        if(c?.explored==true && !c.passable && c.kind!=RockKind.BEDROCK){
                            // One tap toggles the dig order. A drag remains a pan.
                            onPlan?.invoke(p,p)
                        }
                    }
                }
                invalidate()
                return true
            }
            MotionEvent.ACTION_CANCEL->{invalidate();return true}
        }
        return true
    }
}
