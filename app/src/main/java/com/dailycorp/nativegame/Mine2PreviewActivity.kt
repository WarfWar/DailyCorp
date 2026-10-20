package com.dailycorp.nativegame

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Color
import android.content.res.ColorStateList
import android.view.Gravity
import android.widget.*
import com.dailycorp.minecore.*
import java.io.File
import java.io.ObjectInputStream
import java.io.ObjectOutputStream

/** Isolated Mine 2.0 playable prototype; the old mine economy remains untouched. */
class Mine2PreviewActivity:Activity(){
    private lateinit var game:GameEngine
    private lateinit var world:Mine2World
    private lateinit var view:Mine2PreviewView
    private lateinit var status:TextView
    private var cityId=1
    private var lotId=-1
    private var readOnly=false
    private var steps=0
    private val handler=Handler(Looper.getMainLooper())
    private val timer=object:Runnable{
        override fun run(){
            if(::world.isInitialized){
                world.step()
                steps++
                if(steps%2==0)game.tick(excludedMineCityId=cityId,excludedMineLotId=lotId)
                if(steps%20==0)save()
                refresh()
                view.invalidate()
            }
            handler.postDelayed(this,500)
        }
    }
    private fun px(n:Int)=(n*resources.displayMetrics.density).toInt()
    private fun action(title:String,callback:()->Unit):Button=Button(this).apply{
        text=title;isAllCaps=false;textSize=12f;setTextColor(Color.WHITE)
        backgroundTintList=ColorStateList.valueOf(Color.rgb(48,46,43))
        setOnClickListener{callback()}
    }
    private fun name()="mine2_v1_city_"+cityId+"_lot_"+lotId+".save"
    private fun load(config:Mine2Config):Mine2World{
        val source=File(filesDir,name())
        if(!source.exists())return Mine2World.create(config)
        return try{
            val value=ObjectInputStream(source.inputStream()).use{it.readObject() as Mine2World}
            if(value.config==config)value else{
                readOnly=true;Mine2World.create(config)
            }
        }catch(_:Exception){
            // Keep unrecognized/corrupt files intact, never silently overwrite.
            readOnly=true;Mine2World.create(config)
        }
    }
    private fun save(){
        if(readOnly || !::world.isInitialized)return
        try{
            val temp=File(filesDir,name()+".tmp")
            ObjectOutputStream(temp.outputStream()).use{it.writeObject(world)}
            if(!temp.renameTo(File(filesDir,name())))error("save rename failed")
        }catch(_:Exception){}
        GameSession.save(this)
    }
    override fun onCreate(savedInstanceState:Bundle?){
        super.onCreate(savedInstanceState)
        cityId=intent.getIntExtra("cityId",GameSession.cityId)
        lotId=intent.getIntExtra("lotId",GameSession.mineLotId)
        game=GameSession.engine ?:try{
            GameEngine(ObjectInputStream(openFileInput("dailycorp-native-v1.save"))
                .use{it.readObject() as GameState})
        }catch(_:Exception){GameEngine.newGame()}
        GameSession.engine=game
        val mine=game.company(cityId).mines[lotId]
        if(mine==null){finish();return}
        val config=Mine2Config(
            seed=game.city(cityId).seed xor lotId.toLong()*9973L,
            width=52,
            depthCells=(mine.depth*8).coerceIn(120,1200),
            ores=mine.ores.ifEmpty{listOf("coal","iron","copper","gold")}
        )
        world=load(config)
        val root=LinearLayout(this).apply{
            orientation=LinearLayout.VERTICAL
            setBackgroundColor(Color.rgb(8,8,10))
        }
        val header=LinearLayout(this).apply{
            orientation=LinearLayout.VERTICAL
            setPadding(px(12),px(8),px(12),px(8))
        }
        header.addView(TextView(this).apply{
            text="ШАХТА 2.0 · ПОДЗЕМНЫЙ КОМПЛЕКС"
            textSize=19f;setTextColor(Color.rgb(246,224,181))
        })
        status=TextView(this).apply{
            textSize=12f;setTextColor(Color.rgb(187,185,178))
            setPadding(0,px(8),0,0)
        }
        header.addView(status)
        root.addView(header)
        view=Mine2PreviewView(this,world)
        view.onPlan={a,_->
            val c=world.cell(a.x,a.y)
            val ordered=world.toggleCellOrder(a)
            Toast.makeText(this,if(ordered)"Добыча назначена: "+
                (c?.resource?.let{Catalog.name(it)} ?: "порода")+
                " · осталось "+(c?.deposit?:0)+" ед."
                else "Задание снято",Toast.LENGTH_SHORT).show()
            refresh();view.invalidate()
        }
        view.onSelected={p,count->
            val cell=world.cell(p.x,p.y)
            Toast.makeText(this,
                (cell?.resource?.let{Catalog.name(it)}?:"Порода")+
                " · "+count+" ед. · нажми на клетку ещё раз",
                Toast.LENGTH_SHORT).show()
        }
        view.onSurvey={p->
            // Panning is always enabled. A paid scan is a one-shot tool.
            view.resetScanner()
            if(readOnly){
                Toast.makeText(this,"Сохранение недоступно: разведка отключена",
                    Toast.LENGTH_LONG).show()
            }else{
                val quote=world.surveyQuote(p.x,p.y)
                if(!quote.valid){
                    Toast.makeText(this,quote.reason,Toast.LENGTH_SHORT).show()
                }else{
                    android.app.AlertDialog.Builder(this)
                        .setTitle("Геологоразведка · "+quote.price+" ₽")
                        .setMessage("Глубина: "+(p.y*world.config.metersPerCell)+
                            " м\nПримерно "+quote.newCells+" новых клеток."+
                            "\nВаш баланс: "+game.state.money+" ₽."+
                            "\nОплата только за успешное сканирование.")
                        .setPositiveButton("Разведать"){_,_->
                            val result=world.surveyPaid(p.x,p.y,game.state.money)
                            if(result.successful){
                                game.state.money-=result.charged
                                GameSession.save(this)
                                save()
                                view.scanPulse(p)
                            }
                            Toast.makeText(this,
                                if(result.successful)
                                    "Разведано "+result.cellsRevealed+" клеток · −"+result.charged+" ₽"
                                else result.reason,Toast.LENGTH_LONG).show()
                            refresh();view.invalidate()
                        }
                        .setNegativeButton("Отмена",null).show()
                }
            }
        }
        root.addView(view,LinearLayout.LayoutParams(-1,0,1f))
        val scroll=HorizontalScrollView(this).apply{isHorizontalScrollBarEnabled=false}
        val bar=LinearLayout(this).apply{orientation=LinearLayout.HORIZONTAL;gravity=Gravity.CENTER_VERTICAL}
        fun add(t:String,cb:()->Unit){
            bar.addView(action(t,cb),LinearLayout.LayoutParams(-2,px(54)).apply{
                marginEnd=px(5)
            })
        }
        add("⌕ Разведка ₽"){view.mode=Mine2PreviewView.Mode.SURVEY;refresh()
            Toast.makeText(this,"Коснись точки сканирования · карту можно двигать",
                Toast.LENGTH_LONG).show()
        }
        add("＋ Шахтёр"){
            if(readOnly){
                Toast.makeText(this,"Сохранение недоступно",Toast.LENGTH_SHORT).show()
            }else{
                val price=450L+world.miners().size*200L
                android.app.AlertDialog.Builder(this)
                    .setTitle("Нанять проходчика · "+price+" ₽")
                    .setMessage("Шахтёры: "+world.miners().size+"/"+world.crewLimit+
                        "\nУлучшай шахтный комплекс, чтобы расширять штат.")
                    .setPositiveButton("Нанять"){_,_->
                        if(game.state.money<price){
                            Toast.makeText(this,"Недостаточно денег",Toast.LENGTH_SHORT).show()
                        }else if(world.hireMiner()){
                            game.state.money-=price
                            GameSession.save(this)
                            save()
                            Toast.makeText(this,"Шахтёр нанят",Toast.LENGTH_SHORT).show()
                        }else{
                            Toast.makeText(this,"Достигнут лимит",Toast.LENGTH_SHORT).show()
                        }
                        refresh();view.invalidate()
                    }.setNegativeButton("Отмена",null).show()
            }
        }
        add("↑ Улучшить шахту"){
            if(readOnly)Toast.makeText(this,"Сохранение недоступно",Toast.LENGTH_SHORT).show()
            else if(!world.canUpgrade())
                Toast.makeText(this,"Максимальный уровень шахты",Toast.LENGTH_SHORT).show()
            else{
                val price=world.upgradePrice()
                val supplies=game.company(cityId).storage
                val requirements=linkedMapOf<String,Int>()
                if(world.shaftLevel>=3){
                    requirements["concrete"]=3
                    requirements["construction_kit"]=1
                    // Advanced mine upgrades consume player-produced equipment.
                    val technologyEra=minOf(game.state.era,world.shaftLevel-1)
                    requirements["epoch_"+technologyEra+"_10"]=1
                    requirements["epoch_"+technologyEra+"_6"]=1
                }
                val supplyText=if(requirements.isEmpty())"Материалы пока не требуются."
                    else requirements.entries.joinToString("\n"){
                        Catalog.name(it.key)+" ×"+it.value+
                            " (склад: "+(supplies[it.key]?:0)+")"
                    }
                android.app.AlertDialog.Builder(this)
                    .setTitle("Шахта: уровень "+world.shaftLevel+" → "+(world.shaftLevel+1))
                    .setMessage("Цена: "+price+" ₽\nЛимит шахтёров: "+
                        world.crewLimit+" → "+(world.crewLimit+4)+
                        "\n"+supplyText)
                    .setPositiveButton("Улучшить"){_,_->
                        val enough=requirements.all{(item,count)->
                            (supplies[item]?:0)>=count
                        }
                        when {
                            game.state.money<price ->
                                Toast.makeText(this,"Недостаточно денег",Toast.LENGTH_SHORT).show()
                            !enough ->
                                Toast.makeText(this,"Не хватает строительных материалов",Toast.LENGTH_LONG).show()
                            world.upgradeShaft() -> {
                                game.state.money-=price
                                for((material,count) in requirements)
                                    supplies[material]=supplies.getValue(material)-count
                                GameSession.save(this)
                                save()
                                Toast.makeText(this,"Лимит шахтёров повышен до "+world.crewLimit,
                                    Toast.LENGTH_LONG).show()
                            }
                        }
                        refresh()
                    }.setNegativeButton("Назад",null).show()
            }
        }
        add("Отмена задач"){
            val n=world.cancelOrders()
            Toast.makeText(this,"Снято задач: "+n,Toast.LENGTH_SHORT).show()
            refresh();view.invalidate()
        }
        add("↓100 м"){view.moveDepth(20)}
        add("↑100 м"){view.moveDepth(-20)}
        add("К поверхности"){view.surface()}
        add("Назад"){finish()}
        scroll.addView(bar)
        root.addView(scroll,LinearLayout.LayoutParams(-1,px(65)))
        root.setOnApplyWindowInsetsListener{v,insets->
            v.setPadding(0,insets.systemWindowInsetTop,0,insets.systemWindowInsetBottom)
            insets
        }
        setContentView(root)
        refresh()
    }
    private fun refresh(){
        val label=if(view.mode==Mine2PreviewView.Mode.SURVEY)
            "Разведка: нажми на точку сканирования; обзор работает постоянно"
            else "Проведи пальцем — обзор; 2 нажатия на породу — назначить/отменить добычу"
        status.text="Глубина "+(world.config.depthCells*world.config.metersPerCell)+
            " м · Пройдено "+world.totalExcavated+
            " · Заданий "+world.pendingCount()+
            "\nШахта ур."+world.shaftLevel+" · Проходчики "+world.miners().size+
            "/"+world.crewLimit+" · Разведок "+world.surveysPerformed+
            " · Баланс "+game.state.money+" ₽"+
            "\nПробная руда "+world.stockpile.values.sum()+
            " · Разведка: от 450 ₽, радиус 8 кл."+
            "\n"+(if(readOnly)"Ошибка сохранения: действия отключены"
                else "ТЕСТ: пробная руда пока не поступает в экономику")+
            "\n"+label
    }
    override fun onResume(){
        super.onResume()
        if(::world.isInitialized){
            handler.removeCallbacks(timer)
            handler.postDelayed(timer,500)
        }
    }
    override fun onPause(){
        handler.removeCallbacks(timer);save();super.onPause()
    }
    override fun onDestroy(){handler.removeCallbacks(timer);super.onDestroy()}
}
