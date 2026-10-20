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

/** Mine2 cutaway: paints visible cells only; vector fallback if sprite unavailable. */
class Mine2PreviewView(context:Context,val world:Mine2World):View(context){
    enum class Mode { DIG,PAN,SURVEY }
    var mode=Mode.DIG
    var onPlan:((CellPos,CellPos)->Unit)?=null
    var onSurvey:((CellPos)->Unit)?=null
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val art=GameArt(context)
    private val minerTracks=mutableMapOf<Int,Mine2MotionTrack>()
    private var scanAt:CellPos?=null
    private var scanStarted=0L
    fun scanPulse(cell:CellPos){
        scanAt=cell
        scanStarted=android.os.SystemClock.uptimeMillis()
        invalidate()
    }
    private val unit=33f*resources.displayMetrics.density
    private var zoom=1f
    private var panX=0f
    private var panY=0f
    private var lastX=0f
    private var lastY=0f
    private var firstX=0f
    private var firstY=0f
    private var down:CellPos?=null
    private var current:CellPos?=null
    private var moved=false
    private var multi=false
    private val scale=ScaleGestureDetector(context,object:ScaleGestureDetector.SimpleOnScaleGestureListener(){
        override fun onScale(e:ScaleGestureDetector):Boolean {
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
    private fun fill(color:Int){paint.color=color;paint.style=Paint.Style.FILL;paint.strokeWidth=1f}
    private fun color(c:RockCell):Int=when(c.kind){
        RockKind.SOIL->Color.rgb(62,52,45)
        RockKind.ROCK->Color.rgb(55,55,57)
        RockKind.HARD_ROCK->Color.rgb(43,43,48)
        RockKind.DEEP_ROCK->Color.rgb(30,29,34)
        RockKind.BEDROCK->Color.rgb(12,12,14)
        RockKind.ORE->Color.rgb(72,58,42)
        RockKind.TUNNEL->Color.rgb(16,16,18)
        RockKind.SHAFT->Color.rgb(24,24,26)
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
    override fun onDraw(canvas:Canvas){
        canvas.drawColor(Color.rgb(2,2,3))
        val t=tile();val left=ox();val top=oy()
        val x0=max(0,floor(-left/t).toInt()-1)
        val x1=min(world.config.width-1,floor((width-left)/t).toInt()+1)
        val y0=max(0,floor(-top/t).toInt()-1)
        val y1=min(world.config.depthCells-1,floor((height-top)/t).toInt()+1)
        if(x0>x1||y0>y1)return
        // Explicit world boundaries: walls on x=0 and x=width-1.
        val wallL=left+t
        val wallR=left+(world.config.width-1)*t
        for(y in y0..y1){
            for(x in x0..x1){
                val c=world.cell(x,y)?:continue
                val l=left+x*t;val p=top+y*t
                fill(if(c.explored)color(c) else Color.rgb(6,6,8))
                canvas.drawRect(l,p,l+t+0.6f,p+t+0.6f,paint)
                if(x==0 || x==world.config.width-1){
                    fill(Color.rgb(105,83,51))
                    canvas.drawRect(l+2,p+2,l+t-2,p+t-2,paint)
                    fill(Color.rgb(35,31,29))
                    canvas.drawRect(l+7,p+5,l+t-7,p+t-5,paint)
                    paint.color=Color.rgb(218,161,65)
                    paint.strokeWidth=max(1.5f,t*0.035f)
                    canvas.drawLine(l+3,p+3,l+t-3,p+t-3,paint)
                    continue
                }
                if(!c.explored)continue
                if(zoom>0.53f)art.draw(canvas,asset(c),l,p,l+t+0.5f,p+t+0.5f)
                // Dark rock lighting and a deliberately darker scanned zone.
                fill(Color.argb(if(world.isSurveyDim(x,y))155 else 65,0,0,0))
                canvas.drawRect(l,p,l+t+0.5f,p+t+0.5f,paint)
                if(c.resource!=null && zoom>0.73f && t>24f){
                    val sign=when(c.resource){
                        "clay"->"Гл";"sand"->"Пс";"gravel"->"Гр"
                        "granite"->"Гн";"salt"->"Сл";"sulfur"->"Sr"
                        "shale"->"Сн"
                        else->""
                    }
                    if(sign.isNotEmpty()){
                        fill(Color.rgb(234,207,151))
                        paint.textSize=t*0.19f
                        canvas.drawText(sign,l+t*0.08f,p+t*0.83f,paint)
                    }
                }
                if(c.ordered){
                    fill(Color.argb(115,250,182,56))
                    canvas.drawRect(l+2,p+2,l+t-2,p+t-2,paint)
                    paint.style=Paint.Style.STROKE;paint.strokeWidth=max(2f,t*0.05f)
                    paint.color=Color.rgb(248,211,103)
                    canvas.drawRect(l+2,p+2,l+t-2,p+t-2,paint)
                    paint.style=Paint.Style.FILL
                }
                if(c.kind==RockKind.TUNNEL){
                    fill(Color.rgb(133,104,75))
                    canvas.drawRect(l,p+t*0.83f,l+t,p+t*0.90f,paint)
                }
            }
            if(y%10==0){
                val py=top+y*t
                fill(Color.argb(220,13,13,15))
                canvas.drawRoundRect(RectF(4f,py,100f*resources.displayMetrics.density,
                    py+22f*resources.displayMetrics.density),4f,4f,paint)
                fill(Color.WHITE);paint.textSize=12f*resources.displayMetrics.scaledDensity
                canvas.drawText((y*world.config.metersPerCell).toString()+" м",
                    12f*resources.displayMetrics.density,
                    py+16f*resources.displayMetrics.density,paint)
            }
        }
        val now=android.os.SystemClock.uptimeMillis()
        var animating=false
        minerTracks.keys.retainAll(world.miners().map{it.id}.toSet())
        for(worker in world.miners()){
            val track=minerTracks.getOrPut(worker.id){
                Mine2MotionTrack(worker.x.toFloat(),worker.y.toFloat(),515L)
            }
            track.target(worker.x.toFloat(),worker.y.toFloat(),now)
            val moving=track.moving(now)
            if(moving)animating=true
            val position=track.position(now)
            val cx=left+(position.x+0.5f)*t
            val cy=top+(position.y+0.45f)*t
            if(cx+t<0f || cx-t>width || cy+t<0f || cy-t>height)continue
            val phase=(now%500L).toFloat()*(2.0*kotlin.math.PI).toFloat()/500f
            val bob=if(moving)kotlin.math.abs(kotlin.math.sin(phase))*t*0.05f else 0f
            fill(Color.argb(125,4,11,19))
            canvas.drawOval(RectF(cx-t*0.18f,cy+t*0.21f,cx+t*0.18f,cy+t*0.29f),paint)
            fill(Color.rgb(60,147,182))
            canvas.drawRoundRect(RectF(cx-t*0.12f,cy-bob,cx+t*0.12f,
                cy+t*0.19f-bob),t*0.04f,t*0.04f,paint)
            fill(Color.rgb(249,203,139))
            canvas.drawCircle(cx,cy-t*0.10f-bob,t*0.13f,paint)
            fill(Color.rgb(246,196,61))
            canvas.drawRect(cx-t*0.15f,cy-t*0.24f-bob,
                cx+t*0.15f,cy-t*0.16f-bob,paint)
            if(worker.mining){
                animating=true
                paint.color=Color.rgb(212,222,220)
                paint.strokeWidth=t*0.045f
                val arm=kotlin.math.sin(phase)*t*0.11f
                canvas.drawLine(cx+t*0.10f,cy,cx+t*0.30f,
                    cy-t*0.18f+arm,paint)
            }
            if(t>24f){
                fill(Color.WHITE);paint.textSize=t*0.19f
                canvas.drawText(worker.id.toString(),cx-t*0.09f,cy+t*0.14f,paint)
            }
        }
        // Survey ring expands over a larger 8-cell radius with a subtle glow.
        scanAt?.let {center->
            val age=now-scanStarted
            if(age in 0..1400L){
                val fraction=(age.toFloat()/1400f).coerceIn(0f,1f)
                val cx=left+(center.x+0.5f)*t
                val cy=top+(center.y+0.5f)*t
                paint.style=Paint.Style.STROKE
                paint.strokeWidth=max(2f,t*0.07f)
                paint.color=Color.argb(((1f-fraction)*160).toInt().coerceIn(0,255),
                    232,174,67)
                canvas.drawCircle(cx,cy,(1f+8f*fraction)*t,paint)
                paint.style=Paint.Style.FILL
                animating=true
            }else if(age>1400L)scanAt=null
        }
        // Boundaries remain legible even when zoomed into the middle of the mine.
        fill(Color.argb(200,8,8,9))
        val density=resources.displayMetrics.density
        val sideTitleSize=10f*resources.displayMetrics.scaledDensity
        paint.textSize=sideTitleSize
        if(wallL in 0f..width.toFloat()){
            paint.color=Color.rgb(217,166,89)
            canvas.drawRect(wallL-1.5f,0f,wallL+1.5f,height.toFloat(),paint)
        }
        if(wallR in 0f..width.toFloat()){
            paint.color=Color.rgb(217,166,89)
            canvas.drawRect(wallR-1.5f,0f,wallR+1.5f,height.toFloat(),paint)
        }
        val leftCells=max(0,((width*0.5f-left)/t).toInt())
        val rightCells=max(0,world.config.width-leftCells-1)
        fill(Color.argb(205,11,11,12))
        canvas.drawRoundRect(RectF(4*density,6*density,width-4*density,
            29*density),4*density,4*density,paint)
        paint.color=Color.rgb(212,174,110)
        paint.textSize=sideTitleSize
        canvas.drawText("◀ Граница: $leftCells кл.",10*density,22*density,paint)
        val labelRight="Граница: $rightCells кл. ▶"
        canvas.drawText(labelRight,width-10*density-paint.measureText(labelRight),
            22*density,paint)
        if(animating && isAttachedToWindow)postInvalidateDelayed(33L)
        if(mode==Mode.DIG && down!=null && current!=null){
            val a=down!!;val b=current!!
            val l=left+min(a.x,b.x)*t;val p=top+min(a.y,b.y)*t
            val r=left+(max(a.x,b.x)+1)*t;val bottom=top+(max(a.y,b.y)+1)*t
            fill(Color.argb(66,253,203,78));canvas.drawRect(l,p,r,bottom,paint)
            paint.color=Color.rgb(255,215,111);paint.strokeWidth=3f
            paint.style=Paint.Style.STROKE
            canvas.drawRect(l,p,r,bottom,paint)
            paint.style=Paint.Style.FILL
        }
    }
    override fun onTouchEvent(e:MotionEvent):Boolean{
        scale.onTouchEvent(e)
        when(e.actionMasked){
            MotionEvent.ACTION_DOWN->{
                lastX=e.x;lastY=e.y;firstX=e.x;firstY=e.y
                moved=false;multi=false;down=cellAt(e.x,e.y);current=down
                invalidate();return true
            }
            MotionEvent.ACTION_POINTER_DOWN->{multi=true;down=null;current=null;return true}
            MotionEvent.ACTION_MOVE->{
                if(e.pointerCount==1&&!scale.isInProgress&&!multi){
                    if(hypot(e.x-firstX,e.y-firstY)>9f*resources.displayMetrics.density)moved=true
                    if(mode==Mode.PAN&&moved){
                        panX+=e.x-lastX;panY+=e.y-lastY
                    }
                    if(mode==Mode.DIG)current=cellAt(e.x,e.y)
                    lastX=e.x;lastY=e.y;invalidate()
                }
                return true
            }
            MotionEvent.ACTION_UP->{
                if(!multi&&!scale.isInProgress){
                    val last=cellAt(e.x,e.y)
                    if(mode==Mode.DIG)down?.let{onPlan?.invoke(it,last)}
                    if(mode==Mode.SURVEY)onSurvey?.invoke(last)
                }
                down=null;current=null;invalidate();return true
            }
            MotionEvent.ACTION_CANCEL->{down=null;current=null;invalidate();return true}
        }
        return true
    }
}
