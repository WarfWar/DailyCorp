package com.dailycorp.nativegame

import android.content.Context
import android.os.SystemClock
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.PI

/** Scrollable side-on cross-section: excavations, miners, rail carts and ore piles. */
class MineCanvasView(context:Context, private val game:GameEngine, val cityId:Int, val lotId:Int) : View(context) {
    var onCellTap: ((Int,Int)->Unit)? = null
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
    private val art=GameArt(context)
    private val blocks=MineBlockAtlas(context)
    private val sprites=MineSpriteFrames(context)
    private val minerDirection=mutableMapOf<Int,Boolean>()
    private val lastMinerX=mutableMapOf<Int,Int>()
    private var zoom=1f
    private var moveX=0f
    private var moveY=0f
    private var firstX=0f
    private var firstY=0f
    private var startX=0f
    private var startY=0f
    private var dragged=false
    private val tile=36f*resources.displayMetrics.density
    private val workerTracks=mutableMapOf<Int,MotionTrack>()
    private val cartTracks=mutableMapOf<Int,MotionTrack>()
    private var lastFloor=-1
    private val detector=ScaleGestureDetector(context,object:ScaleGestureDetector.SimpleOnScaleGestureListener(){
        override fun onScale(e:ScaleGestureDetector):Boolean {
            zoom=(zoom*e.scaleFactor).coerceIn(0.55f,2.3f)
            invalidate()
            return true
        }
    })
    private fun colorFor(b:MineBlock,y:Int):Int=when(b.terrain){
        MineTerrain.BEDROCK -> Color.rgb(27,32,40)
        MineTerrain.ROCK -> if(y<7) Color.rgb(114,91,78) else if(y<14) Color.rgb(86,83,86) else Color.rgb(70,76,89)
        MineTerrain.ORE -> when(b.material) {
            "coal" -> Color.rgb(53,58,67)
            "iron" -> Color.rgb(159,85,69)
            "copper" -> Color.rgb(194,111,77)
            "gold" -> Color.rgb(209,173,65)
            else -> Color.rgb(93,163,154)
        }
        MineTerrain.TUNNEL -> Color.rgb(34,44,53)
        MineTerrain.SHAFT -> Color.rgb(42,55,67)
    }
    private fun fill(c:Int){paint.color=c;paint.style=Paint.Style.FILL;paint.strokeWidth=1f}
    private fun label(canvas:Canvas,text:String,x:Float,y:Float,sp:Float,c:Int=Color.WHITE){
        fill(c);paint.textSize=sp*resources.displayMetrics.scaledDensity;canvas.drawText(text,x,y,paint)
    }
    private fun originX()=width/2f-(MineWorld.ENTRANCE_X+0.5f)*tile*zoom+moveX
    private fun originY()=height*0.36f-(MineWorld.ENTRANCE_Y+0.5f)*tile*zoom+moveY
    override fun onDraw(canvas:Canvas){
        super.onDraw(canvas)
        canvas.drawColor(Color.rgb(14,30,42))
        val floor=game.mineFloor(cityId,lotId) ?:return
        val mine=game.company(cityId).mines.getValue(lotId)
        val u=MineWorld.interior(mine)
        val ox=originX();val oy=originY();val t=tile*zoom
        val now=SystemClock.uptimeMillis()
        var hasMotion=false
        if(lastFloor!=u.activeFloor) {
            workerTracks.clear();cartTracks.clear();lastFloor=u.activeFloor
        }
        // Remove retired actors from the animation cache (save/load and upgrades).
        workerTracks.keys.retainAll(floor.workers.map{it.id}.toSet())
        cartTracks.keys.retainAll(floor.carts.map{it.id}.toSet())
        for(y in 0 until MineWorld.HEIGHT)for(x in 0 until MineWorld.WIDTH){
            val l=ox+x*t;val top=oy+y*t
            if(l+t<0f || l>width || top+t<0f || top>height)continue
            val block=floor.blocks[y][x]
            // Transparent gutters in the supplied atlas are filled with the
            // local rock tone instead of exposing black bars between blocks.
            fill(colorFor(block,y))
            canvas.drawRect(l,top,l+t+0.6f,top+t+0.6f,paint)
            val artKey=art.mineKey(block,y+(u.activeFloor-1)*4)
            val texture=when(block.terrain){
                MineTerrain.BEDROCK -> "terrain_bedrock"
                MineTerrain.ROCK -> if(y<6)"terrain_soil" else "terrain_stone"
                MineTerrain.ORE -> MineBlockAtlas.textureForMaterial(block.material)
                else -> null
            }
            if(texture==null || !blocks.draw(canvas,texture,l,top,l+t+0.55f,top+t+0.55f))
                art.draw(canvas,artKey,l,top,l+t+0.55f,top+t+0.55f)
            if(block.terrain==MineTerrain.ROCK || block.terrain==MineTerrain.ORE){
                if(block.ordered){
                    fill(Color.argb(120,255,195,72));canvas.drawRect(l+2,top+2,l+t-2,top+t-2,paint)
                    paint.style=Paint.Style.STROKE;paint.strokeWidth=max(2f,t*0.06f)
                    paint.color=Color.rgb(255,223,119);canvas.drawRect(l+2,top+2,l+t-2,top+t-2,paint)
                    paint.style=Paint.Style.FILL
                }
            }
            if(block.terrain==MineTerrain.TUNNEL && y==MineWorld.ENTRANCE_Y) {
                art.draw(canvas,"mine.track",l,top,l+t,top+t)
            }
        }
        for(pile in floor.piles){
            val x=ox+(pile.x+0.5f)*t;val y=oy+(pile.y+0.71f)*t
            fill(Color.rgb(213,166,79))
            canvas.drawCircle(x,y,t*0.20f,paint)
            label(canvas,pile.amount.toString(),x-t*0.09f,y+t*0.04f,9f,Color.WHITE)
        }
        for(worker in floor.workers){
            val track=workerTracks.getOrPut(worker.id){
                MotionTrack(worker.x.toFloat(),worker.y.toFloat(),950L)
            }
            val oldX=lastMinerX.put(worker.id,worker.x)
            if(oldX!=null && oldX!=worker.x)minerDirection[worker.id]=worker.x>oldX
            track.target(worker.x.toFloat(),worker.y.toFloat(),now)
            val moving=track.animating(now)
            if(moving || worker.striking)hasMotion=true
            val pos=track.position(now)
            val x=ox+(pos.x+0.5f)*t
            val footY=oy+(pos.y+0.93f)*t
            val right=minerDirection[worker.id]?:true
            val state=when{
                worker.striking && right -> "miner_mine_right"
                worker.striking -> "miner_mine_left"
                moving && right -> "miner_walk_right"
                moving -> "miner_walk_left"
                right -> "miner_idle_right"
                else -> "miner_idle_left"
            }
            if(!sprites.draw(canvas,state,x,footY,t,now,worker.id)){
                fill(Color.rgb(66,157,178))
                canvas.drawRoundRect(RectF(x-t*0.12f,footY-t*0.55f,
                    x+t*0.12f,footY-t*0.25f),t*0.05f,t*0.05f,paint)
                fill(Color.rgb(244,197,131))
                canvas.drawCircle(x,footY-t*0.67f,t*0.12f,paint)
                fill(Color.rgb(246,195,64))
                canvas.drawRect(x-t*0.15f,footY-t*0.83f,
                    x+t*0.15f,footY-t*0.75f,paint)
            }
        }
        for(cart in floor.carts){
            val track=cartTracks.getOrPut(cart.id){
                MotionTrack(cart.x.toFloat(),cart.y.toFloat(),950L)
            }
            track.target(cart.x.toFloat(),cart.y.toFloat(),now)
            val moving=track.animating(now)
            if(moving)hasMotion=true
            val pos=track.position(now)
            val x=ox+(pos.x+0.5f)*t
            val footY=oy+(pos.y+0.95f)*t
            val state=when{
                moving && cart.amount>0 -> "cart_move_loaded"
                moving -> "cart_move_empty"
                cart.amount>0 -> "cart_idle_loaded"
                else -> "cart_idle_empty"
            }
            if(!sprites.draw(canvas,state,x,footY,t,now,cart.id)){
                fill(Color.rgb(194,124,67))
                canvas.drawRoundRect(RectF(x-t*0.33f,footY-t*0.5f,
                    x+t*0.33f,footY-t*0.24f),t*0.05f,t*0.05f,paint)
                for(side in listOf(-1f,1f)){
                    fill(Color.rgb(51,53,56))
                    canvas.drawCircle(x+side*t*0.22f,footY-t*0.22f,t*0.08f,paint)
                }
            }
        }
        if(sprites.loaded && (floor.carts.isNotEmpty() || floor.workers.isNotEmpty()))
            hasMotion=true
        fill(Color.argb(235,7,28,42))
        canvas.drawRoundRect(RectF(12f,12f,width-12f,74f*resources.displayMetrics.density),13f,13f,paint)
        label(canvas,"ШАХТА #"+(lotId+1)+"  ·  ЭТАЖ "+u.activeFloor+"/"+mine.depth,22f,34f*resources.displayMetrics.density,15f)
        label(canvas,"Коснись породы — назначить/снять проходку  ·  Проведи пальцем для перемещения",22f,55f*resources.displayMetrics.density,9f,Color.rgb(196,225,231))
        // View animates in-between one-second physics ticks; no extra mining ticks.
        if (hasMotion && isAttachedToWindow) postInvalidateDelayed(33L)
    }
    override fun onTouchEvent(event:MotionEvent):Boolean{
        detector.onTouchEvent(event)
        when(event.actionMasked){
            MotionEvent.ACTION_DOWN -> {
                firstX=event.x;firstY=event.y;startX=event.x;startY=event.y
                dragged=false;return true
            }
            MotionEvent.ACTION_POINTER_DOWN -> {dragged=true;return true}
            MotionEvent.ACTION_MOVE -> {
                if(event.pointerCount==1 && !detector.isInProgress){
                    val dx=event.x-firstX;val dy=event.y-firstY
                    if(hypot(event.x-startX,event.y-startY)>10f*resources.displayMetrics.density)dragged=true
                    if(dragged){moveX+=dx;moveY+=dy;invalidate()}
                    firstX=event.x;firstY=event.y
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                if(!dragged && !detector.isInProgress){
                    val x=((event.x-originX())/(tile*zoom)).toInt()
                    val y=((event.y-originY())/(tile*zoom)).toInt()
                    if(x in 0 until MineWorld.WIDTH && y in 0 until MineWorld.HEIGHT) onCellTap?.invoke(x,y)
                }
                return true
            }
        }
        return true
    }
}
