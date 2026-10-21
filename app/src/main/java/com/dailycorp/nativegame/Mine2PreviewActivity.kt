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
    private fun syncDelivered(){
        val totals=world.existingTransport()?.delivered?:return
        game.applyMine2Delivery(cityId,lotId,totals)
    }
    private fun save(){
        if(readOnly || !::world.isInitialized)return
        try{
            // First persist cumulative physical delivery totals to Mine2.
            // Then credit only their unapplied delta in the city save.
            val temp=File(filesDir,name()+".tmp")
            ObjectOutputStream(temp.outputStream()).use{it.writeObject(world)}
            if(!temp.renameTo(File(filesDir,name())))error("save rename failed")
            syncDelivered()
            GameSession.save(this)
        }catch (_:Exception){
            Toast.makeText(this,"Не удалось сохранить шахту 2.0",Toast.LENGTH_SHORT).show()
        }
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
        if(!readOnly){
            mine.mine2ProductionEnabled=true
            syncDelivered()
            GameSession.save(this)
        }
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
        view.onRail={p->
            if(readOnly){
                Toast.makeText(this,"Сохранение недоступно",Toast.LENGTH_SHORT).show()
            }else{
                val transport=world.transport()
                when{
                    !transport.canBuildRail(world,p) ->
                        Toast.makeText(this,"Рельсы можно класть только в открытом тоннеле рядом с готовым путём",
                            Toast.LENGTH_LONG).show()
                    game.state.money<transport.railPrice() ->
                        Toast.makeText(this,"Не хватает денег на рельсы",Toast.LENGTH_SHORT).show()
                    else -> {
                        val cost=transport.railPrice()
                        if(transport.buildRail(world,p)){
                            game.state.money-=cost
                            save()
                            Toast.makeText(this,"Рельсы построены · −"+cost+" ₽",
                                Toast.LENGTH_SHORT).show()
                            refresh();view.invalidate()
                        }
                    }
                }
            }
        }
        view.onLift={p->showLiftConstruction(world.transport().quoteLift(world,p.x,p.y))}
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
        add("🛤 Рельсы"){
            view.mode=if(view.mode==Mine2PreviewView.Mode.RAIL)
                Mine2PreviewView.Mode.NORMAL else Mine2PreviewView.Mode.RAIL
            Toast.makeText(this,
                if(view.mode==Mine2PreviewView.Mode.RAIL)
                    "Коснись проложенного тоннеля рядом с рельсами · стоимость от 60 ₽"
                else "Строительство рельсов выключено",
                Toast.LENGTH_SHORT).show()
            refresh()
        }
        add("＋ Вагонетка"){
            if(readOnly){
                Toast.makeText(this,"Сохранение недоступно",Toast.LENGTH_SHORT).show()
            }else{
                val transport=world.transport()
                val price=transport.cartPrice()
                android.app.AlertDialog.Builder(this)
                    .setTitle("Шахтная вагонетка · "+price+" ₽")
                    .setMessage("Вместимость: "+transport.cartCapacity()+
                        " ед.\nДоступно: "+transport.carts.size+"/8"+
                        "\nВагонетка ездит только по построенным рельсам."+
                        "\nПосле возврата к стволу руда попадает в городскую погрузку.")
                    .setPositiveButton("Купить"){_,_->
                        if(game.state.money<price){
                            Toast.makeText(this,"Недостаточно денег",Toast.LENGTH_SHORT).show()
                        }else if(transport.hireCart()){
                            game.state.money-=price
                            save()
                            Toast.makeText(this,"Вагонетка добавлена",Toast.LENGTH_SHORT).show()
                        }else{
                            Toast.makeText(this,"Достигнут лимит вагонеток",Toast.LENGTH_SHORT).show()
                        }
                        refresh();view.invalidate()
                    }.setNegativeButton("Отмена",null).show()
            }
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
        add("↑ Грузовой лифт"){showLiftUpgrade()}
        add("📊 Отчёт"){showMineStats()}
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
    private fun showLiftUpgrade(){
        if(readOnly){
            Toast.makeText(this,"Сохранение недоступно",Toast.LENGTH_SHORT).show()
            return
        }
        val transport=world.transport()
        if(!transport.canUpgradeLift()){
            Toast.makeText(this,"Подъёмник улучшен до максимума",Toast.LENGTH_SHORT).show()
            return
        }
        val price=transport.liftUpgradeCost()
        val inventory=game.company(cityId).storage
        val needed=linkedMapOf(
            "construction_kit" to transport.liftLevel,
            "epoch_"+minOf(game.state.era,transport.liftLevel)+"_6" to 1
        )
        val detail=needed.entries.joinToString("\n"){(id,count)->
            Catalog.name(id)+" ×"+count+" (на складе "+(inventory[id]?:0)+")"
        }
        android.app.AlertDialog.Builder(this)
            .setTitle("Грузовой лифт · уровень "+transport.liftLevel+" → "+
                (transport.liftLevel+1))
            .setMessage("Цена: "+price+" ₽\n"+detail+
                "\n\nПропускная способность: "+transport.liftCapacity()+
                " → "+(transport.liftCapacity()+1)+" вагонеток за 0,5 секунды.")
            .setPositiveButton("Улучшить"){_,_->
                when {
                    game.state.money<price ->
                        Toast.makeText(this,"Недостаточно денег",Toast.LENGTH_SHORT).show()
                    needed.any{(id,count)->(inventory[id]?:0)<count} ->
                        Toast.makeText(this,"Нужны заводские комплектующие",
                            Toast.LENGTH_LONG).show()
                    transport.upgradeLift() ->{
                        game.state.money-=price
                        for((id,count) in needed)
                            inventory[id]=inventory.getValue(id)-count
                        save()
                        Toast.makeText(this,"Подъёмник улучшен",Toast.LENGTH_SHORT).show()
                    }
                }
                refresh()
            }.setNegativeButton("Отмена",null).show()
    }
    private fun showMineStats(){
        val transport=world.existingTransport()
        val piles=transport?.piles?.values?.sumOf{it.values.sum()}?:0
        val totalWagons=transport?.carts?.size?:0
        val loadedWagons=transport?.carts?.count{it.amount>0}?:0
        val tasks=world.pendingCount()
        val cause=when {
            tasks==0 && piles==0 -> "Нет заказов на добычу"
            totalWagons==0 && piles>0 -> "Не хватает вагонеток"
            (transport?.idleWithoutRailV4?:0L)>0L && piles>0 ->
                "Недостаточно рельсов к месту добычи"
            tasks>0 && world.miners().none{it.mining} ->
                "Проходчики в пути или нет доступного фронта"
            loadedWagons>0 -> "Идёт вывоз руды"
            else -> "Работа продолжается"
        }
        android.app.AlertDialog.Builder(this)
            .setTitle("Производственный отчёт")
            .setMessage("Добыча за 60 секунд: "+world.orePerMinute()+
                " ед.\nТоннелей пройдено: "+world.totalExcavated+
                "\nЗаданий на проходку: "+tasks+
                "\nПроходчики: "+world.miners().size+
                "\nПод землёй: "+world.stockpile.values.sum()+" ед."+
                "\nОткрытые штабели: "+piles+" ед."+
                "\nВагонетки: "+totalWagons+", загружено: "+loadedWagons+
                "\nПодъёмник: уровень "+(transport?.liftLevel?:1)+
                ", "+(transport?.liftCapacity()?:1)+" ваг./такт"+
                "\nРейсов с грузом: "+(transport?.loadedTripsV4?:0L)+
                "\nШагов вагонеток: "+(transport?.cartTravelStepsV4?:0L)+
                "\nТактов без рельсов: "+(transport?.idleWithoutRailV4?:0L)+
                "\nТактов перегрузки лифта: "+(transport?.liftCongestionTicksV4?:0L)+
                "\n\nСостояние: "+cause)
            .setPositiveButton("Закрыть",null).show()
    }
    private fun refresh(){
        val label=when(view.mode){
            Mine2PreviewView.Mode.SURVEY ->
                "Разведка: нажми на точку сканирования; обзор работает постоянно"
            Mine2PreviewView.Mode.RAIL ->
                "Рельсы: нажми на доступный тоннель рядом с уже построенным путём"
            Mine2PreviewView.Mode.LIFT -> "Лифт: выбери координату X и нужную глубину"
            else -> "Проведи пальцем — обзор; нажми на породу — назначить/отменить добычу"
        }
        val transport=world.existingTransport()
        val delivered=transport?.delivered?.values?.sum()?:0
        val carts=transport?.carts?.size?:0
        val rails=transport?.rails?.size?:0
        status.text="Глубина "+(world.config.depthCells*world.config.metersPerCell)+
            " м · Пройдено "+world.totalExcavated+
            " · Заданий "+world.pendingCount()+
            "\nШахта ур."+world.shaftLevel+" · Проходчики "+world.miners().size+
            "/"+world.crewLimit+" · Разведок "+world.surveysPerformed+
            " · Баланс "+game.state.money+" ₽"+
            "\nДобыча "+world.orePerMinute()+" ед/мин · Лифт ур."+
            (transport?.liftLevel?:1)+
            "\nПод землёй "+world.stockpile.values.sum()+
            " · Доставлено "+delivered+" · Вагонетки "+carts+" · Рельсы "+rails+
            "\nРазведка: от 450 ₽, радиус 8 кл."+
            "\n"+(if(readOnly)"Ошибка сохранения: действия отключены"
                else "Руда поступает в погрузку после рейса вагонетки")+
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
