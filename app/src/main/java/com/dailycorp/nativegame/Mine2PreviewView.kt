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
        RockKind.SOIL->Color.rgb(128,86,58)
        RockKind.ROCK->Color.rgb(105,104,110)
        RockKind.HARD_ROCK->Color.rgb(78,83,98)
        RockKind.DEEP_ROCK->Color.rgb(46,54,72)
        RockKind.BEDROCK->Color.rgb(18,26,37)
        RockKind.ORE->Color.rgb(140,105,66)
        RockKind.TUNNEL->Color.rgb(22,41,52)
        RockKind.SHAFT->Color.rgb(24,49,66)
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
            else->"mine.quartz"
        }
    }
    override fun onDraw(canvas:Canvas){
        canvas.drawColor(Color.rgb(9,24,37))
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
                fill(if(c.explored)color(c) else Color.rgb(11,25,39))
                canvas.drawRect(l,p,l+t+0.6f,p+t+0.6f,paint)
                if(!c.explored)continue
                if(zoom>0.53f)art.draw(canvas,asset(c),l,p,l+t+0.5f,p+t+0.5f)
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
                fill(Color.argb(190,9,30,46))
                canvas.drawRoundRect(RectF(4f,py,100f*resources.displayMetrics.density,
                    py+22f*resources.displayMetrics.density),4f,4f,paint)
                fill(Color.WHITE);paint.textSize=12f*resources.displayMetrics.scaledDensity
                canvas.drawText((y*world.config.metersPerCell).toString()+" м",
                    12f*resources.displayMetrics.density,
                    py+16f*resources.displayMetrics.density,paint)
            }
        }
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
