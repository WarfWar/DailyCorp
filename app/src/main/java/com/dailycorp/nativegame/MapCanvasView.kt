package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
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
    private val biomeCache=mutableMapOf<Int,Array<Array<Biome>>>()
    private val continentBiomes by lazy {
        Array(72){ y -> Array(96){ x ->
            BiomeGenerator.world(engine.state.seed,x,y)
        }}
    }
    private val cityPins=mutableMapOf<Int,Point>()
    // Only the atlas with validated isolated diamonds/props is decoded.
    // Do not allocate the old postcard/diaroma atlases in this map renderer.
    private val styleB=WorldStyleBArt(context)
    private val urbanCache=mutableMapOf<Int,Set<Point>>()
    private var worldTexture:Bitmap?=null
    private var worldTexturePrepared=false
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
    private fun urbanZones(plan:MapPlan):Set<Point> = urbanCache.getOrPut(cityId) {
        buildSet{
            for(p in plan.roads)for(dy in -1..1)for(dx in -1..1)
                add(Point(p.x+dx,p.y+dy))
            addAll(plan.homes)
            addAll(plan.lots.map{it.pos})
        }
    }
    private fun onScreen(x:Float,y:Float,margin:Float=140f):Boolean =
        x>=-margin && x<=width+margin && y>=-margin && y<=height+margin
    private fun cityBiomes():Array<Array<Biome>> = biomeCache.getOrPut(cityId) {
        val seed=engine.city(cityId).seed
        Array(CityGenerator.HEIGHT){ y ->
            Array(CityGenerator.WIDTH){ x -> BiomeGenerator.city(seed,x,y) }
        }
    }
    private fun biomeColor(b:Biome,x:Int,y:Int,seed:Long):Int {
        val base=BiomeGenerator.tint(b)
        val n=x.toLong()*7919L+y.toLong()*3011L+seed
        val jitter=(((n xor (n ushr 17)) and 7L).toInt()-3)*0.010f
        return Color.rgb(
            (Color.red(base)*(1f+jitter)).toInt().coerceIn(0,255),
            (Color.green(base)*(1f+jitter)).toInt().coerceIn(0,255),
            (Color.blue(base)*(1f+jitter)).toInt().coerceIn(0,255))
    }
    private fun biomeAccent(canvas:Canvas,b:Biome,x:Int,y:Int,
        cx:Float,cy:Float,rx:Float,ry:Float) {
        val signature=(x*47+y*31+cityId*13) and 15
        if(signature>3)return
        when(b){
            Biome.FOREST -> {
                fill(Color.rgb(26,84,55))
                val shift=(signature-1.5f)*rx*0.14f
                shape.reset();shape.moveTo(cx+shift,cy-ry*0.68f)
                shape.lineTo(cx+shift+rx*0.17f,cy+ry*0.37f)
                shape.lineTo(cx+shift-rx*0.17f,cy+ry*0.37f)
                shape.close();canvas.drawPath(shape,paint)
            }
            Biome.MOUNTAINS -> {
                fill(Color.rgb(104,113,112))
                shape.reset();shape.moveTo(cx,cy-ry*0.66f)
                shape.lineTo(cx+rx*0.38f,cy+ry*0.36f)
                shape.lineTo(cx-rx*0.38f,cy+ry*0.36f)
                shape.close();canvas.drawPath(shape,paint)
            }
            Biome.LAKE,Biome.RIVER -> line(canvas,cx-rx*0.26f,cy,
                cx+rx*0.24f,cy,Color.argb(140,227,246,246),max(1f,ry*0.09f))
            else -> {}
        }
    }
    private fun worldRect():RectF {
        val w=width*0.94f*zoom;val h=w*0.75f
        val cx=width*0.5f+panX;val cy=height*0.5f+panY
        return RectF(cx-w/2f,cy-h/2f,cx+w/2f,cy+h/2f)
    }
    private fun cityWorldPoint(id:Int):Point = cityPins.getOrPut(id){
        val row=(id-1)/8;val col=(id-1)%8
        val sx=9+col*11;val sy=10+row*10
        var best=Point(sx,sy)
        var score=Int.MAX_VALUE
        for(dy in -10..10)for(dx in -10..10){
            val x=(sx+dx).coerceIn(2,93)
            val y=(sy+dy).coerceIn(2,69)
            val biome=continentBiomes[y][x]
            if(biome==Biome.OCEAN||biome==Biome.LAKE||biome==Biome.RIVER)continue
            val distance=dx*dx+dy*dy+(if(biome==Biome.COAST)8 else 0)
            if(distance<score){score=distance;best=Point(x,y)}
        }
        best
    }
    override fun onDraw(canvas:Canvas) {
        super.onDraw(canvas)
        canvas.drawColor(if(continentMode)Color.rgb(31,75,95) else Color.rgb(52,88,74))
        if(continentMode)drawContinent(canvas) else drawCity(canvas)
    }
    private fun worldStyleBitmap():Bitmap? {
        if(worldTexturePrepared)return worldTexture
        worldTexturePrepared=true
        if(!styleB.hasMaterials)return null
        // Continent stays 96x72 top-down. Composite 6912 material squares
        // one time, not on every frame and zoom.
        val cell=12
        return try {
            val w=96*cell
            val h=72*cell
            val result=Bitmap.createBitmap(w,h,Bitmap.Config.RGB_565)
            val target=Canvas(result)
            for(y in 0 until 72)for(x in 0 until 96){
                styleB.drawContinentCell(target,continentBiomes[y][x],x,y,
                    x*cell.toFloat(),y*cell.toFloat(),cell.toFloat())
            }
            // The map is not pixel art: smooth only the transitions between
            // ocean/river/lake and dry land. A coastline of 12-px boxes looked
            // like a Minecraft stair-step at tablet resolution.
            val pixels=IntArray(w*h)
            result.getPixels(pixels,0,w,0,0,w,h)
            fun wet(x:Int,y:Int):Float {
                if(x !in 0..95 || y !in 0..71)return 1f
                return when(continentBiomes[y][x]){
                    Biome.OCEAN,Biome.RIVER,Biome.LAKE->1f
                    else->0f
                }
            }
            for(py in 0 until h){
                val gy=py.toFloat()/cell-0.5f
                val cy=kotlin.math.floor(gy).toInt()
                val vy=gy-cy
                for(px in 0 until w){
                    val gx=px.toFloat()/cell-0.5f
                    val cx=kotlin.math.floor(gx).toInt()
                    val vx=gx-cx
                    val top=wet(cx,cy)*(1f-vx)+wet(cx+1,cy)*vx
                    val bottom=wet(cx,cy+1)*(1f-vx)+wet(cx+1,cy+1)*vx
                    val water=top*(1f-vy)+bottom*vy
                    if(water<=0.23f || water>=0.77f)continue
                    val idx=py*w+px
                    val base=pixels[idx]
                    val amount=(kotlin.math.abs(water-0.5f)*2f)
                        .coerceIn(0f,1f)
                    val alpha=(1f-amount)*0.86f
                    // Blend toward a shoreline palette; keep the original
                    // surface texture visible away from the water boundary.
                    val coast=if(water>0.52f) Color.rgb(47,119,153)
                        else Color.rgb(192,188,136)
                    val inv=1f-alpha
                    pixels[idx]=Color.rgb(
                        (Color.red(base)*inv+Color.red(coast)*alpha).toInt(),
                        (Color.green(base)*inv+Color.green(coast)*alpha).toInt(),
                        (Color.blue(base)*inv+Color.blue(coast)*alpha).toInt())
                }
            }
            result.setPixels(pixels,0,w,0,0,w,h)
            result.also{worldTexture=it}
        }catch (_:Exception){null}
    }
    private fun drawContinent(canvas:Canvas){
        val rect=worldRect()
        val tw=rect.width()/96f
        val th=rect.height()/72f
        val seed=engine.state.seed
        // Same geography and city coordinates, now with Style B materials.
        val texture=worldStyleBitmap()
        if(texture!=null){
            fill(Color.WHITE)
            paint.isFilterBitmap=true
            canvas.drawBitmap(texture,null,rect,paint)
        }else{
            for(y in 0 until 72)for(x in 0 until 96){
                fill(biomeColor(continentBiomes[y][x],x,y,seed))
                val sx=rect.left+x*tw;val sy=rect.top+y*th
                canvas.drawRect(sx,sy,sx+tw+0.55f,sy+th+0.55f,paint)
            }
        }
        // Biome silhouettes are sparse and only placed inside their native regions.
        for(y in 4 until 68 step 4)for(x in 4 until 92 step 4){
            val biome=continentBiomes[y][x]
            if(biome !in listOf(Biome.FOREST,Biome.MOUNTAINS,Biome.SNOW,Biome.DESERT))
                continue
            if(continentBiomes[y][x+2]!=biome)continue
            val px=rect.left+(x+0.5f)*tw
            val py=rect.top+(y+0.5f)*th
            biomeAccent(canvas,biome,x,y,px,py,tw*2.4f,th*2.4f)
        }
        // Whole-scene illustration cards don't belong on a 96x72 world map.
        // Native biomes and city pins remain; object sprites stay in city scale.
        val d=resources.displayMetrics.density
        for(city in engine.state.cities){
            val (x,y)=cityPin(city.id)
            if(!onScreen(x,y,35f))continue
            val selected=city.id==cityId
            fill(if(selected)Color.rgb(255,190,90) else Color.WHITE)
            canvas.drawCircle(x,y,(if(selected)6f else 4f)*d,paint)
            if(selected || city.id%8==0){
                fill(Color.argb(218,11,41,56))
                val labelX=(x+8*d).coerceIn(7*d,width-102*d)
                canvas.drawRoundRect(RectF(labelX,y-12*d,
                    labelX+94*d,y+6*d),4*d,4*d,paint)
                text(canvas,city.name,labelX+5*d,y+2*d,10f,Color.WHITE,selected)
            }
        }
        fill(Color.argb(235,7,34,49))
        canvas.drawRoundRect(RectF(8*d,8*d,width-8*d,57*d),10*d,10*d,paint)
        text(canvas,"КОНТИНЕНТ · 48 ГОРОДОВ",18*d,29*d,15f,Color.WHITE,true)
        text(canvas,"Леса · горы · реки · озёра · побережье",18*d,47*d,
            11f,Color.rgb(198,223,232))
    }
    private fun cityPin(id:Int):Pair<Float,Float>{
        val cell=cityWorldPoint(id)
        val r=worldRect()
        return Pair(r.left+(cell.x+0.5f)*r.width()/96f,
            r.top+(cell.y+0.5f)*r.height()/72f)
    }
    private fun drawCity(canvas:Canvas){
        val d=resources.displayMetrics.density
        val plan=cachedPlan()
        val halfW=25f*zoom*d
        val halfH=14.5f*zoom*d
        val seed=engine.city(cityId).seed
        val biomes=cityBiomes()
        val occupiedLots=plan.lots.map{it.pos}.toHashSet()
        val urbanLots=urbanZones(plan)
        // Continuous climate zones, with no noisy atlas photos per city cell.
        for(depth in 0 until plan.width+plan.height-1){
            for(x in max(0,depth-plan.height+1)..min(plan.width-1,depth)){
                val y=depth-x
                val pos=Point(x,y)
                val (sx,sy)=projected(pos)
                if(!onScreen(sx,sy,halfW*2))continue
                val occupied=pos in plan.roads || pos in occupiedLots
                val natural=biomes[y][x]
                // Construction needs stable urban ground; a sandy surface tile
                // on every city lot was producing huge patchy beige chessboards.
                // Keep actual deserts away from settlements; do not mutate biome
                // generation, building lots, or the saved map.
                val urban=pos in urbanLots
                val b=when {
                    occupied && (natural==Biome.LAKE || natural==Biome.RIVER) -> Biome.PLAINS
                    urban && (natural==Biome.DESERT || natural==Biome.COAST) -> Biome.PLAINS
                    else -> natural
                }
                if(!styleB.drawCityTile(canvas,b,x,y,sx,sy,
                        halfW+0.62f,halfH+0.62f)) {
                    diamond(canvas,sx,sy,halfW+0.62f,halfH+0.62f,
                        biomeColor(b,x,y,seed))
                    if(!occupied)biomeAccent(canvas,b,x,y,sx,sy,halfW,halfH)
                }
                if(!occupied && zoom>=0.85f){
                    val deco=(x*47+y*31+cityId*13) and 15
                    when{
                        b==Biome.FOREST && deco==0 ->
                            styleB.drawDecor(canvas,33,sx,sy+halfH,
                                halfW*1.10f,halfH*2.3f)
                        b==Biome.FOREST && deco==1 ->
                            styleB.drawDecor(canvas,40,sx,sy+halfH,
                                halfW*1.65f,halfH*2.75f)
                        b==Biome.MOUNTAINS && deco==2 ->
                            styleB.drawDecor(canvas,41,sx,sy+halfH,
                                halfW*1.6f,halfH*2.7f)
                        b==Biome.PLAINS && deco==3 ->
                            styleB.drawDecor(canvas,35,sx,sy+halfH,
                                halfW*0.9f,halfH*2f)
                    }
                }
            }
        }
        // Use only transparent, individually isolated native props.
        // Large Pack 8/10 illustrations and relief chunks require a height-map;
        // inserting them as stand-alone city sprites created the visible cuts.
        if(zoom>=0.95f)for(y in 2 until plan.height step 6)
            for(x in 2 until plan.width step 6){
                val pos=Point(x,y)
                if(pos in plan.roads || pos in occupiedLots || pos in plan.homes)continue
                val b=biomes[y][x]
                val marker=(x*31+y*19+cityId*13) and 7
                val decor=when{
                    b==Biome.FOREST && marker<=2 -> 32 // small fir
                    b==Biome.FOREST && marker==3 -> 33 // cluster
                    b==Biome.MOUNTAINS && marker<=2 -> 37 // rock
                    b==Biome.PLAINS && marker==1 -> 39 // flowers
                    else -> -1
                }
                if(decor>=0){
                    val (sx,sy)=projected(pos)
                    if(onScreen(sx,sy,halfW*2f))
                        styleB.drawDecor(canvas,decor,sx,sy+halfH*0.55f,
                            halfW*0.75f,halfH*1.55f)
                }
            }
        // Roads follow the same saved graph but are DRAWN AS LANES, not
        // full-width opaque tile diamonds. No intersecting illustrations,
        // stamps, or marks over the buildings.
        val asphalt=Color.rgb(85,99,103)
        val edge=Color.rgb(57,72,75)
        val roadWidth=max(5f,halfH*0.83f)
        val roadDirs=listOf(Point(1,0),Point(0,1))
        for(p in plan.roads){
            val (sx,sy)=projected(p)
            if(!onScreen(sx,sy,halfW*2f))continue
            val linked=roadDirs.map { Point(p.x+it.x,p.y+it.y) }
                .filter{it in plan.roads}
            if(linked.isEmpty()){
                fill(asphalt)
                canvas.drawCircle(sx,sy,roadWidth*0.53f,paint)
            }else{
                for(other in linked){
                    val (tx,ty)=projected(other)
                    line(canvas,sx,sy,tx,ty,edge,roadWidth+2.1f*d)
                    line(canvas,sx,sy,tx,ty,asphalt,roadWidth)
                    if(zoom>=1.15f){
                        line(canvas,sx+(tx-sx)*0.42f,sy+(ty-sy)*0.42f,
                            sx+(tx-sx)*0.58f,sy+(ty-sy)*0.58f,
                            Color.argb(125,233,227,203),max(0.9f,zoom*d*0.65f))
                    }
                }
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
                if(zoom<0.78f || at in plan.roads)continue
                val variety=(at.x*37+at.y*83+cityId*11) and 7
                // Source home_*.png includes labels printed INSIDE each sprite.
                // Procedural houses avoid unreadable embedded captions and
                // have a consistent physical footprint with nearby factories.
                val wall=when(variety%4){
                    0->Color.rgb(204,197,178)
                    1->Color.rgb(174,190,177)
                    2->Color.rgb(182,180,193)
                    else->Color.rgb(199,180,166)
                }
                val height=(9f+(variety%3)*2.8f)*zoom*d
                drawBuilding(canvas,x,y,
                    7.3f*zoom*d,4.8f*zoom*d,
                    wall,height,variety,false)
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
                diamond(canvas,x,y+5f*zoom*d,w*0.98f,h*0.98f,
                    if(owned)Color.rgb(142,158,121) else Color.rgb(188,181,144))
                if(owned) {
                    val height=when(lot.kind){
                        BuildingKind.FACTORY -> 24f
                        BuildingKind.MINE -> 16f
                        BuildingKind.WAREHOUSE -> 16f
                        BuildingKind.MARKET -> 14f
                        BuildingKind.ENERGY -> 28f
                        BuildingKind.MUNICIPAL -> 25f
                        BuildingKind.RESEARCH -> 30f
                    }
                    drawBuilding(canvas,x,y,w*0.70f,h*0.80f,
                        main,height*zoom*d,lot.id%4,true)
                } else {
                    fill(Color.argb(75,236,207,149))
                    diamond(canvas,x,y+3f*zoom*d,w*0.68f,h*0.78f,
                        Color.rgb(154,164,139))
                    line(canvas,x-5f*zoom*d,y,x+5f*zoom*d,y,
                        Color.rgb(239,244,220),2.4f*zoom*d)
                    line(canvas,x,y-5f*zoom*d,x,y+5f*zoom*d,
                        Color.rgb(239,244,220),2.4f*zoom*d)
                }
                if(zoom>=0.95f){
                    val name="${lot.kind.title} ${lot.id+1}"
                    val labelW=max(56f*d,min(136f*d,name.length*5.7f*d))
                    val bx=x-labelW/2f
                    val by=y+23f*zoom*d
                    if(by<59f*d)continue // top status panel owns this region
                    fill(Color.argb(235,14,48,65))
                    canvas.drawRoundRect(RectF(bx,by,bx+labelW,by+20f*d),5f*d,5f*d,paint)
                    text(canvas,name,bx+5f*d,by+14f*d,10f,Color.WHITE)
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
        // Consistent window rhythm on both facades. All elements are drawn
        // from the same geometry, unlike legacy 64px illustrations with captions.
        if(zoom>0.70f){
            val density=resources.displayMetrics.density
            val windows=if(big)3 else 1
            fill(Color.rgb(229,221,170))
            for(i in 1..windows){
                val t=i.toFloat()/(windows+1f)
                val px=x+w*t
                val py=y+h*(1f-t)-height*0.53f
                val ww=max(1.2f,2.0f*zoom*density)
                val wh=max(1.5f,2.5f*zoom*density)
                canvas.drawRect(px-ww,py-wh,px+ww,py+wh,paint)
            }
            if(big){
                fill(Color.rgb(84,107,110))
                canvas.drawRect(x+w*0.50f-2f*zoom*density,
                    y-h-height-1f*zoom*density,
                    x+w*0.50f+2f*zoom*density,y-h-height+5f*zoom*density,paint)
            }
        }
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
