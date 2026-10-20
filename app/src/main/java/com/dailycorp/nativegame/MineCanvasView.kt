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
            val artKey=art.mineKey(block,y)
            if(!art.draw(canvas,artKey,l,top,l+t+0.4f,top+t+0.4f)){
                fill(colorFor(block,y))
                canvas.drawRect(l,top,l+t+0.4f,top+t+0.4f,paint)
            }
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
            track.target(worker.x.toFloat(),worker.y.toFloat(),now)
            val moving=track.animating(now)
            if(moving) hasMotion=true
            val pos=track.position(now)
            val x=ox+(pos.x+0.5f)*t
            val baseY=oy+(pos.y+0.42f)*t
            val phase=(now%560L).toFloat()*((2.0*PI).toFloat()/560f)
            val stride=if(moving)sin(phase)*t*0.10f else 0f
            val bounce=if(moving)kotlin.math.abs(sin(phase))*t*0.035f else 0f
            val y=baseY-bounce
            // Cast shadow and alternating boots so walking is visually continuous.
            fill(Color.argb(105,3,11,17))
            canvas.drawOval(RectF(x-t*0.20f,baseY+t*0.25f,
                x+t*0.20f,baseY+t*0.32f),paint)
            paint.strokeWidth=t*0.06f
            paint.strokeCap=Paint.Cap.ROUND
            paint.color=Color.rgb(36,46,60)
            canvas.drawLine(x-t*0.055f,y+t*0.17f,x-t*0.07f-stride,y+t*0.35f,paint)
            canvas.drawLine(x+t*0.055f,y+t*0.17f,x+t*0.07f+stride,y+t*0.35f,paint)
            fill(Color.rgb(253,209,151))
            canvas.drawCircle(x,y-t*0.12f,t*0.13f,paint)
            fill(if(worker.striking)Color.rgb(243,168,58) else Color.rgb(62,161,187))
            canvas.drawRect(x-t*0.12f,y,x+t*0.12f,y+t*0.21f,paint)
            fill(Color.rgb(249,196,63))
            canvas.drawRoundRect(RectF(x-t*0.15f,y-t*0.25f,
                x+t*0.15f,y-t*0.15f),t*0.04f,t*0.04f,paint)
            // A visible oscillating mining arm and pick while striking rock.
            if(worker.striking){
                hasMotion=true
                val angle=sin(phase)*t*0.14f
                paint.color=Color.rgb(229,195,154);paint.strokeWidth=t*0.07f
                canvas.drawLine(x+t*0.08f,y+t*0.03f,
                    x+t*0.27f,y-t*0.09f+angle,paint)
                paint.color=Color.rgb(178,188,189);paint.strokeWidth=t*0.045f
                canvas.drawLine(x+t*0.25f,y-t*0.21f+angle,
                    x+t*0.36f,y+t*0.03f+angle,paint)
            }
        }
        for(cart in floor.carts){
            val track=cartTracks.getOrPut(cart.id){
                MotionTrack(cart.x.toFloat(),cart.y.toFloat(),950L)
            }
            track.target(cart.x.toFloat(),cart.y.toFloat(),now)
            val moving=track.animating(now)
            if(moving) hasMotion=true
            val pos=track.position(now)
            val x=ox+(pos.x+0.5f)*t
            val y=oy+(pos.y+0.5f)*t
            fill(Color.argb(95,2,12,18))
            canvas.drawOval(RectF(x-t*0.38f,y+t*0.17f,
                x+t*0.38f,y+t*0.29f),paint)
            fill(Color.rgb(208,136,76))
            canvas.drawRoundRect(RectF(x-t*0.29f,y-t*0.04f,
                x+t*0.29f,y+t*0.19f),t*0.04f,t*0.04f,paint)
            val wheelAngle=if(moving)(now%650L).toFloat()/650f*(2.0*PI).toFloat() else 0f
            for(sign in listOf(-1f,1f)){
                val cx=x+sign*t*0.19f
                val cy=y+t*0.22f
                fill(Color.rgb(48,60,64))
                canvas.drawCircle(cx,cy,t*0.077f,paint)
                paint.color=Color.rgb(215,208,173);paint.strokeWidth=t*0.022f
                val spoke=t*0.057f
                val vx=kotlin.math.cos(wheelAngle)*spoke
                val vy=sin(wheelAngle)*spoke
                canvas.drawLine(cx-vx,cy-vy,cx+vx,cy+vy,paint)
            }
            if(cart.amount>0){
                fill(Color.rgb(245,209,93))
                canvas.drawCircle(x,y-t*0.06f,t*0.115f,paint)
            }
        }
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
