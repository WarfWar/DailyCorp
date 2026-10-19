package com.dailycorp.nativegame

import android.content.Context
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

/** Scrollable side-on cross-section: excavations, miners, rail carts and ore piles. */
class MineCanvasView(context:Context, private val game:GameEngine, val cityId:Int, val lotId:Int) : View(context) {
    var onCellTap: ((Int,Int)->Unit)? = null
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
    private var zoom=1f
    private var moveX=0f
    private var moveY=0f
    private var firstX=0f
    private var firstY=0f
    private var startX=0f
    private var startY=0f
    private var dragged=false
    private val tile=36f*resources.displayMetrics.density
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
        for(y in 0 until MineWorld.HEIGHT)for(x in 0 until MineWorld.WIDTH){
            val l=ox+x*t;val top=oy+y*t
            if(l+t<0f || l>width || top+t<0f || top>height)continue
            val block=floor.blocks[y][x]
            fill(colorFor(block,y));canvas.drawRect(l,top,l+t+0.4f,top+t+0.4f,paint)
            if(block.terrain==MineTerrain.ROCK || block.terrain==MineTerrain.ORE){
                fill(Color.argb(85,9,22,30))
                canvas.drawLine(l+2f,top+t*0.82f,l+t*0.73f,top+t*0.17f,paint)
                if(block.terrain==MineTerrain.ORE){
                    fill(Color.argb(210,235,215,140));canvas.drawCircle(l+t*0.56f,top+t*0.43f,t*0.12f,paint)
                }
                if(block.ordered){
                    fill(Color.argb(120,255,195,72));canvas.drawRect(l+2,top+2,l+t-2,top+t-2,paint)
                    paint.style=Paint.Style.STROKE;paint.strokeWidth=max(2f,t*0.06f)
                    paint.color=Color.rgb(255,223,119);canvas.drawRect(l+2,top+2,l+t-2,top+t-2,paint)
                    paint.style=Paint.Style.FILL
                }
            }
            if(block.terrain==MineTerrain.TUNNEL || block.terrain==MineTerrain.SHAFT){
                fill(Color.rgb(144,117,87))
                canvas.drawRect(l,top+t*0.82f,l+t,top+t*0.88f,paint)
                fill(Color.rgb(98,114,120))
                canvas.drawLine(l,top+t*0.89f,l+t,top+t*0.89f,paint)
                if(block.terrain==MineTerrain.SHAFT){
                    fill(Color.rgb(149,151,135))
                    canvas.drawRect(l+t*0.22f,top,l+t*0.27f,top+t,paint)
                    canvas.drawRect(l+t*0.74f,top,l+t*0.79f,top+t,paint)
                }
            }
        }
        for(pile in floor.piles){
            val x=ox+(pile.x+0.5f)*t;val y=oy+(pile.y+0.71f)*t
            fill(Color.rgb(213,166,79))
            canvas.drawCircle(x,y,t*0.20f,paint)
            label(canvas,pile.amount.toString(),x-t*0.09f,y+t*0.04f,9f,Color.WHITE)
        }
        for(worker in floor.workers){
            val x=ox+(worker.x+0.5f)*t;val y=oy+(worker.y+0.42f)*t
            fill(Color.rgb(253,209,151));canvas.drawCircle(x,y-t*0.12f,t*0.13f,paint)
            fill(if(worker.striking)Color.rgb(243,168,58) else Color.rgb(62,161,187))
            canvas.drawRect(x-t*0.12f,y,x+t*0.12f,y+t*0.3f,paint)
            fill(Color.rgb(249,196,63))
            canvas.drawRect(x-t*0.14f,y-t*0.24f,x+t*0.14f,y-t*0.15f,paint)
        }
        for(cart in floor.carts){
            val x=ox+(cart.x+0.5f)*t;val y=oy+(cart.y+0.5f)*t
            fill(Color.rgb(208,136,76));canvas.drawRoundRect(RectF(x-t*0.29f,y-t*0.04f,x+t*0.29f,y+t*0.19f),t*0.04f,t*0.04f,paint)
            fill(Color.rgb(48,60,64))
            canvas.drawCircle(x-t*0.19f,y+t*0.22f,t*0.075f,paint)
            canvas.drawCircle(x+t*0.19f,y+t*0.22f,t*0.075f,paint)
            if(cart.amount>0){
                fill(Color.rgb(245,209,93))
                canvas.drawCircle(x,y-t*0.06f,t*0.115f,paint)
            }
        }
        fill(Color.argb(235,7,28,42))
        canvas.drawRoundRect(RectF(12f,12f,width-12f,74f*resources.displayMetrics.density),13f,13f,paint)
        label(canvas,"ШАХТА #"+(lotId+1)+"  ·  ЭТАЖ "+u.activeFloor+"/"+mine.depth,22f,34f*resources.displayMetrics.density,15f)
        label(canvas,"Коснись породы — назначить/снять проходку  ·  Проведи пальцем для перемещения",22f,55f*resources.displayMetrics.density,9f,Color.rgb(196,225,231))
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
