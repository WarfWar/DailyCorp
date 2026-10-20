package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/** A custom 2D renderer. No engine, no Android UI dependencies in game rules. */
class MapCanvasView(context: Context, private val engine: GameEngine) : View(context) {
    var cityId: Int = 1
        set(value) { field = value; panX = 0f; panY = 0f; zoom = 1.0f; invalidate() }
    var continentMode: Boolean = true
        set(value) { field = value; panX = 0f; panY = 0f; zoom = if(value) 1.0f else 1.0f; invalidate() }
    var onCityTap: (Int) -> Unit = {}
    var onLotTap: (Lot) -> Unit = {}
    private val cache = mutableMapOf<Int, MapPlan>()
    private val art = GameArt(context)
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val shape = Path()
    private var panX = 0f
    private var panY = 0f
    private var zoom = 1f
    private var lastX = 0f
    private var lastY = 0f
    private var downX = 0f
    private var downY = 0f
    private var dragged = false
    private val scale = ScaleGestureDetector(context,object:ScaleGestureDetector.SimpleOnScaleGestureListener(){
        override fun onScale(detector: ScaleGestureDetector): Boolean {
            zoom = (zoom * detector.scaleFactor).coerceIn(if(continentMode)0.75f else 0.65f,if(continentMode)3f else 2.9f)
            invalidate(); return true
        }
    })

    private fun fill(color: Int) { paint.color=color;paint.style=Paint.Style.FILL;paint.strokeWidth=1f }
    private fun line(canvas:Canvas,x1:Float,y1:Float,x2:Float,y2:Float,color:Int,width:Float){
        fill(color);paint.strokeWidth=width;paint.strokeCap=Paint.Cap.ROUND;canvas.drawLine(x1,y1,x2,y2,paint)
    }
    private fun text(canvas:Canvas,value:String,x:Float,y:Float,sp:Float,color:Int,bold:Boolean=false){
        fill(color);paint.textSize=sp*resources.displayMetrics.density;paint.isFakeBoldText=bold
        canvas.drawText(value,x,y,paint);paint.isFakeBoldText=false
    }
    private fun diamond(canvas:Canvas,cx:Float,cy:Float,rx:Float,ry:Float,color:Int){
        fill(color);shape.reset();shape.moveTo(cx,cy-ry);shape.lineTo(cx+rx,cy)
        shape.lineTo(cx,cy+ry);shape.lineTo(cx-rx,cy);shape.close();canvas.drawPath(shape,paint)
    }
    private fun projected(p:Point): Pair<Float,Float> {
        val halfW=25f*zoom*resources.displayMetrics.density
        val halfH=14.5f*zoom*resources.displayMetrics.density
        return Pair(width/2f+panX+(p.x-p.y)*halfW,
            height/2f+panY+(p.x+p.y-33f)*halfH)
    }
    private fun cachedPlan():MapPlan=cache.getOrPut(cityId){ CityGenerator.plan(engine.city(cityId)) }
    private fun onScreen(x:Float,y:Float,margin:Float=140f):Boolean =
        x>=-margin && x<=width+margin && y>=-margin && y<=height+margin
    private fun terrainSprite(x:Int,y:Int,seed:Long):String {
        val value=(((x/3)*173+(y/4)*97+((seed xor (seed ushr 15)).toInt())) and 127)
        return when {
            value<=3 -> "continent.mountains"
            value<=8 -> "continent.forest"
            value==9 -> "continent.lake"
            value==10 -> "continent.rocky_coast"
            value==11 -> "continent.swamp"
            else -> "continent.meadow"
        }
    }
    private fun terrain(x:Int,y:Int,seed:Long):Int {
        val v=(((x*17+y*29+((seed xor (seed ushr 16)).toInt())) xor ((x/4)*3079 + (y/5)*991)) and 31)
        return when {
            v==0 -> Color.rgb(116,171,115)
            v<7 -> Color.rgb(133,188,120)
            v<15 -> Color.rgb(141,197,123)
            else -> Color.rgb(146,202,129)
        }
    }
    override fun onDraw(canvas:Canvas) {
        super.onDraw(canvas)
        canvas.drawColor(Color.rgb(31,75,95))
        if(continentMode)drawContinent(canvas) else drawCity(canvas)
    }
    private fun drawContinent(canvas:Canvas){
        val cx=width/2f+panX;val cy=height/2f+panY
        val unit=resources.displayMetrics.density*zoom
        val rx=min(width,height)*0.45f*zoom
        val ry=rx*0.67f
        // Entire continent: several inset organic coast bands, independent of tile renderer.
        diamond(canvas,cx,cy,rx*1.1f,ry*1.13f,Color.rgb(47,143,175))
        diamond(canvas,cx,cy,rx,ry,Color.rgb(112,169,116))
        diamond(canvas,cx-rx*0.07f,cy-ry*0.03f,rx*0.81f,ry*0.82f,Color.rgb(137,190,119))
        diamond(canvas,cx+rx*0.13f,cy+ry*0.04f,rx*0.48f,ry*0.40f,Color.rgb(167,191,126))
        // Illustrated continent patches from the supplied biome atlas.
        val scenery=listOf("continent.forest","continent.lake","continent.mountains",
            "continent.river_curve","continent.swamp","continent.beach",
            "continent.meadow","continent.highway","continent.industrial_edge",
            "continent.volcano","continent.snow","continent.rocky_coast",
            "continent.port","continent.river_bridge","continent.trainline")
        for(i in scenery.indices){
            val col=i%5
            val row=i/5
            val tx=cx+(col-2f)*rx*0.38f
            val ty=cy+(row-1f)*ry*0.66f
            val tw=rx*0.40f; val th=ry*0.72f
            if(onScreen(tx,ty,tw))art.draw(canvas,scenery[i],tx,ty,tw,th)
        }
        for(city in engine.state.cities){
            val (x,y)=cityPin(city.id)
            if(!onScreen(x,y,25f))continue
            val active=city.id==cityId
            fill(if(active)Color.rgb(255,190,90) else Color.WHITE)
            canvas.drawCircle(x,y,(if(active)6.5f else 4.5f)*unit,paint)
            if(active || city.id%8==0){
                val title=city.name
                fill(Color.argb(225,14,49,67))
                canvas.drawRoundRect(RectF(x+7*unit,y-10*unit,x+(if(active)99 else 88)*unit,y+6*unit),5*unit,5*unit,paint)
                text(canvas,title,x+12*unit,y+2*unit,10f,Color.WHITE,active)
            }
        }
        text(canvas,"КОНТИНЕНТ  ·  ${engine.state.cities.size} ГОРОДОВ",16*resources.displayMetrics.density,31*resources.displayMetrics.density,14f,Color.WHITE,true)
        text(canvas,"Коснись города или увеличь карту двумя пальцами",16*resources.displayMetrics.density,height-16*resources.displayMetrics.density,11f,Color.WHITE)
    }
    private fun cityPin(id:Int):Pair<Float,Float>{
        val unit=resources.displayMetrics.density*zoom
        val row=(id-1)/8
        val col=(id-1)%8
        val jitterX=((id*83)%9-4)*1.5f
        val jitterY=((id*67)%9-4)*1.2f
        return Pair(width/2f+panX+(col-3.5f)*38f*unit+jitterX*unit,
            height/2f+panY+(row-2.5f)*34f*unit+jitterY*unit)
    }
    private fun drawCity(canvas:Canvas){
        val d=resources.displayMetrics.density
        val plan=cachedPlan()
        val halfW=25f*zoom*d
        val halfH=14.5f*zoom*d
        for(depth in 0 until plan.width+plan.height-1){
            for(x in max(0,depth-plan.height+1)..min(plan.width-1,depth)){
                val y=depth-x
                val (sx,sy)=projected(Point(x,y))
                if(!onScreen(sx,sy,halfW*2))continue
                diamond(canvas,sx,sy,halfW+0.45f,halfH+0.45f,terrain(x,y,engine.city(cityId).seed))
                if(zoom>=0.76f){
                    // Crop atlas art to the isometric diamond; no square seams or overlaps.
                    val saved=canvas.save()
                    shape.reset();shape.moveTo(sx,sy-halfH);shape.lineTo(sx+halfW,sy)
                    shape.lineTo(sx,sy+halfH);shape.lineTo(sx-halfW,sy);shape.close()
                    canvas.clipPath(shape)
                    art.draw(canvas,terrainSprite(x,y,engine.city(cityId).seed),
                        sx-halfW,sy-halfH,sx+halfW,sy+halfH)
                    canvas.restoreToCount(saved)
                }
            }
        }
        // Roads only occupy reserved cells. They never pass through any lot.
        for(p in plan.roads){
            val (x,y)=projected(p)
            if(!onScreen(x,y,halfW*2))continue
            for(delta in listOf(Point(1,0),Point(0,1))){
                val target=Point(p.x+delta.x,p.y+delta.y)
                if(target !in plan.roads)continue
                val (tx,ty)=projected(target)
                line(canvas,x,y,tx,ty,Color.rgb(225,219,204),17f*zoom*d)
                line(canvas,x,y,tx,ty,Color.rgb(78,97,110),13f*zoom*d)
                if(zoom>0.85f)line(canvas,x,y,tx,ty,Color.rgb(240,231,201),1f*zoom*d)
            }
        }
        // The road network remains topologically connected; modular road decals
        // show junctions and curves without changing pathfinding or lot locations.
        for(p in plan.roads){
            if((p.x+p.y)%2!=0)continue
            val (rx,ry)=projected(p)
            if(!onScreen(rx,ry,halfW*3))continue
            val neighbours=listOf(Point(1,0),Point(-1,0),Point(0,1),Point(0,-1))
                .count {Point(p.x+it.x,p.y+it.y) in plan.roads}
            val roadAsset=when(neighbours){
                4->"infra.road_cross"
                3->"infra.road_t"
                2->"infra.road_straight"
                else->"infra.road_curve"
            }
            if(neighbours>=3 || (p.x+p.y)%4==0) {
                art.draw(canvas,roadAsset,rx-halfW*1.18f,ry-halfH*1.45f,
                    rx+halfW*1.18f,ry+halfH*1.45f)
            }
        }
        val scenery=mutableListOf<Triple<Point,Lot?,Boolean>>()
        for(home in plan.homes)scenery.add(Triple(home,null,true))
        for(lot in plan.lots)scenery.add(Triple(lot.pos,lot,false))
        scenery.sortWith(compareBy({it.first.x+it.first.y},{it.first.x}))
        for((at,lot,isHome) in scenery){
            val (x,y)=projected(at)
            if(!onScreen(x,y,100f*d))continue
            if(isHome){
                if(zoom<0.72f)continue
                val n=((at.x*47+at.y*19)%4)
                val key=when(n%3){
                    0->"buildings.home_1"
                    1->"buildings.home_5"
                    else->"buildings.home_10"
                }
                if(!art.draw(canvas,key,x-17f*zoom*d,y-22f*zoom*d,
                        x+17f*zoom*d,y+9f*zoom*d)){
                    drawBuilding(canvas,x,y,8*zoom*d,7*zoom*d,
                        Color.rgb(210,206,182),11f*zoom*d,n,false)
                }
            }else if(lot!=null){
                val c=engine.company(cityId)
                val owned=when(lot.kind){
                    BuildingKind.MINE -> lot.id in c.mines
                    BuildingKind.FACTORY -> lot.id in c.factories
                    BuildingKind.WAREHOUSE -> lot.id in c.warehouses
                    else -> true
                }
                val main=when(lot.kind){
                    BuildingKind.MINE -> Color.rgb(179,139,91)
                    BuildingKind.FACTORY -> Color.rgb(148,160,176)
                    BuildingKind.WAREHOUSE -> Color.rgb(105,158,182)
                    BuildingKind.MARKET -> Color.rgb(218,162,95)
                    BuildingKind.MUNICIPAL -> Color.rgb(202,185,147)
                    BuildingKind.ENERGY -> Color.rgb(142,172,158)
                    BuildingKind.RESEARCH -> Color.rgb(108,151,190)
                }
                val w=20f*zoom*d;val h=12f*zoom*d
                diamond(canvas,x,y+4f*zoom*d,w*1.2f,h*1.5f,
                    if(owned)Color.rgb(210,204,163) else Color.rgb(194,185,152))
                if(owned) {
                    val sprite=art.buildingKey(lot.kind,lot.id)
                    if(!art.draw(canvas,sprite,x-39f*zoom*d,y-53f*zoom*d,
                            x+39f*zoom*d,y+12f*zoom*d)){
                        drawBuilding(canvas,x,y,w,h,main,27f*zoom*d,lot.id%4,true)
                    }
                } else {
                    line(canvas,x-6*zoom*d,y,x+6*zoom*d,y,Color.rgb(240,244,224),3f*zoom*d)
                    line(canvas,x,y-6*zoom*d,x,y+6*zoom*d,Color.rgb(240,244,224),3f*zoom*d)
                }
                if(zoom>=0.83f){
                    val name="${lot.kind.title} ${lot.id+1}"
                    val labelW= max(75f*d,min(150f*d,name.length*7f*d))
                    val bx=x-labelW/2f
                    val by=y+23f*zoom*d
                    fill(Color.argb(235,14,48,65))
                    canvas.drawRoundRect(RectF(bx,by,bx+labelW,by+20f*d),5f*d,5f*d,paint)
                    text(canvas,name,bx+6f*d,by+14f*d,11f,Color.WHITE)
                }
            }
        }
        fill(Color.argb(236,8,41,59))
        canvas.drawRoundRect(RectF(8f*d,8f*d,width-8f*d,53f*d),12f*d,12f*d,paint)
        val city=engine.city(cityId)
        text(canvas,"${city.name} · ${city.specialization}",20f*d,28f*d,15f,Color.WHITE,true)
        text(canvas,"Жители ${city.population}  ·  Участков ${city.lots.size}  ·  шахт ${engine.company(cityId).mines.size}",20f*d,45f*d,10f,Color.rgb(191,216,221))
    }
    private fun drawBuilding(canvas:Canvas,x:Float,y:Float,w:Float,h:Float,color:Int,height:Float,style:Int,big:Boolean){
        val wallDark=blend(color,Color.BLACK,0.24f)
        val roof=blend(color,Color.WHITE,0.22f)
        fill(wallDark)
        shape.reset();shape.moveTo(x-w,y);shape.lineTo(x,y+h);shape.lineTo(x,y+h-height)
        shape.lineTo(x-w,y-height);shape.close();canvas.drawPath(shape,paint)
        fill(color)
        shape.reset();shape.moveTo(x,y+h);shape.lineTo(x+w,y);shape.lineTo(x+w,y-height)
        shape.lineTo(x,y+h-height);shape.close();canvas.drawPath(shape,paint)
        fill(roof)
        shape.reset();shape.moveTo(x-w,y-height);shape.lineTo(x,y-h-height)
        shape.lineTo(x+w,y-height);shape.lineTo(x,y+h-height);shape.close();canvas.drawPath(shape,paint)
        if(big && zoom>0.75f){
            val d=resources.displayMetrics.density
            fill(Color.rgb(240,232,191))
            canvas.drawRect(x+2*zoom*d,y-9*zoom*d,x+7*zoom*d,y-4*zoom*d,paint)
        }
    }
    private fun blend(a:Int,b:Int,ratio:Float):Int {
        val inv=1f-ratio
        return Color.rgb((Color.red(a)*inv+Color.red(b)*ratio).toInt(),
            (Color.green(a)*inv+Color.green(b)*ratio).toInt(),
            (Color.blue(a)*inv+Color.blue(b)*ratio).toInt())
    }
    override fun onTouchEvent(event:MotionEvent):Boolean {
        scale.onTouchEvent(event)
        when(event.actionMasked){
            MotionEvent.ACTION_DOWN -> {lastX=event.x;lastY=event.y;downX=lastX;downY=lastY;dragged=false;return true}
            MotionEvent.ACTION_POINTER_DOWN -> {dragged=true;return true}
            MotionEvent.ACTION_MOVE -> {
                if(event.pointerCount==1 && !scale.isInProgress){
                    val dx=event.x-lastX;val dy=event.y-lastY
                    if(hypot(event.x-downX,event.y-downY)>12f*resources.displayMetrics.density)dragged=true
                    if(dragged){panX+=dx;panY+=dy;invalidate()}
                    lastX=event.x;lastY=event.y
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                if(!dragged && !scale.isInProgress){
                    if(continentMode){
                        val closest=engine.state.cities.map{it.id to cityPin(it.id)}
                            .minByOrNull{hypot(it.second.first-event.x,it.second.second-event.y)}
                        if(closest!=null && hypot(closest.second.first-event.x,closest.second.second-event.y)<25f*resources.displayMetrics.density*zoom)
                            onCityTap(closest.first)
                    }else{
                        val chosen=cachedPlan().lots.minByOrNull{ val (x,y)=projected(it.pos);hypot(x-event.x,y-event.y) }
                        if(chosen!=null){val (x,y)=projected(chosen.pos)
                            if(hypot(x-event.x,y-event.y)<34f*resources.displayMetrics.density*zoom)onLotTap(chosen)
                        }
                    }
                }
                return true
            }
        }
        return true
    }
}
