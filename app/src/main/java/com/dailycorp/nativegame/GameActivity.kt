package com.dailycorp.nativegame

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Color
import android.graphics.Typeface
import android.content.res.ColorStateList
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.io.ObjectInputStream
import java.io.ObjectOutputStream

/** Native Android UI: small focused dialogs, deterministic rendering, pure Kotlin simulation. */
class GameActivity : Activity() {
    private lateinit var game: GameEngine
    private lateinit var map: MapCanvasView
    private lateinit var topText: TextView
    private lateinit var secondaryText: TextView
    private lateinit var actions: LinearLayout
    private val handler = Handler(Looper.getMainLooper())
    private var ticks = 0
    private val bg = Color.rgb(9,39,56)
    private val accent = Color.rgb(27,105,146)
    private val gold = Color.rgb(235,174,80)
    private val uiTick = object : Runnable {
        override fun run() {
            game.tick()
            ticks++
            if(ticks % 15 == 0) save()
            refresh()
            handler.postDelayed(this,1000)
        }
    }
    override fun onCreate(savedInstanceState:Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor=bg
        window.navigationBarColor=bg
        game=loadGame()
        GameSession.engine=game
        buildUi()
    }
    override fun onResume(){
        super.onResume()
        if(::game.isInitialized) {
            handler.removeCallbacks(uiTick)
            handler.postDelayed(uiTick,1000)
        }
    }
    override fun onPause(){
        handler.removeCallbacks(uiTick)
        super.onPause()
        save()
    }
    override fun onDestroy(){handler.removeCallbacks(uiTick);save();super.onDestroy()}
    private fun loadGame():GameEngine = try {
        ObjectInputStream(openFileInput("dailycorp-native-v1.save")).use { stream ->
            val state=stream.readObject() as GameState
            GameEngine(state)
        }
    } catch(_:Exception) { GameEngine.newGame() }
    private fun save(){
        try { ObjectOutputStream(openFileOutput("dailycorp-native-v1.save",MODE_PRIVATE)).use{it.writeObject(game.state)} }
        catch(_:Exception) { /* Never interrupt a live game for a failed local write. */ }
    }
    private fun density(value:Int):Int=(value*resources.displayMetrics.density).toInt()
    private fun text(size:Float,bold:Boolean=false):TextView=TextView(this).apply{
        setTextColor(Color.WHITE); textSize=size
        if(bold)typeface=Typeface.DEFAULT_BOLD
        gravity=Gravity.CENTER_VERTICAL
    }
    private fun button(title:String,onTap:()->Unit):Button=Button(this).apply{
        text=title; textSize=11f; isAllCaps=false; setTextColor(Color.WHITE)
        backgroundTintList=ColorStateList.valueOf(accent)
        setPadding(density(4),0,density(4),0)
        minWidth=density(88); minHeight=density(42)
        setOnClickListener { onTap() }
    }
    private fun buildUi(){
        val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(bg)}
        val head=LinearLayout(this).apply{
            orientation=LinearLayout.VERTICAL;setPadding(density(14),density(10),density(14),density(9));setBackgroundColor(bg)
        }
        topText=text(20f,true)
        secondaryText=text(12f)
        secondaryText.setTextColor(Color.rgb(176,211,221))
        head.addView(topText);head.addView(secondaryText)
        root.addView(head)
        map=MapCanvasView(this,game)
        map.onCityTap={ id ->
            map.cityId=id
            map.continentMode=false
            updateActions();refresh()
        }
        map.onLotTap={lot -> showLot(lot)}
        root.addView(map,LinearLayout.LayoutParams(-1,0,1f))
        val scroll=HorizontalScrollView(this).apply{
            isHorizontalScrollBarEnabled=false
            setBackgroundColor(bg)
        }
        actions=LinearLayout(this).apply{
            orientation=LinearLayout.HORIZONTAL;gravity=Gravity.CENTER_VERTICAL
            setPadding(density(7),density(5),density(7),density(6))
        }
        scroll.addView(actions)
        root.addView(scroll,LinearLayout.LayoutParams(-1,density(62)))
        // Android 15+ draws behind status/navigation bars unless insets are applied.
        root.setOnApplyWindowInsetsListener{view,insets->
            view.setPadding(0,insets.systemWindowInsetTop,0,insets.systemWindowInsetBottom)
            insets
        }
        setContentView(root)
        updateActions();refresh()
    }
    private fun updateActions(){
        actions.removeAllViews()
        fun add(name:String,callback:()->Unit){
            val b=button(name,callback)
            val lp=LinearLayout.LayoutParams(-2,density(49));lp.marginEnd=density(5)
            actions.addView(b,lp)
        }
        if(map.continentMode){
            add("Город 001"){map.cityId=1;map.continentMode=false;updateActions();refresh()}
            add("Научный центр"){showResearch()}
            add("Компания"){showCompany()}
            add("Транспорт"){showTrucks()}
            add("Контракты"){showContracts()}
        } else {
            add("← Континент"){map.continentMode=true;updateActions();refresh()}
            add("Шахты"){showSites(BuildingKind.MINE)}
            add("Научный центр"){showResearch()}
            add("Заводы"){showSites(BuildingKind.FACTORY)}
            add("Склады"){showSites(BuildingKind.WAREHOUSE)}
            add("Транспорт"){showTrucks()}
            add("Контракты"){showContracts()}
            add("Компания"){showCompany()}
        }
    }
    private fun refresh(){
        topText.text="DAILYCORP · NATIVE"
        secondaryText.text="${money(game.state.money)}   ·  Эпоха ${game.state.era}/10   ·  Наука ${game.state.science}   ·  Груз ${game.state.totalShipped}"
        map.invalidate()
    }
    private fun money(n:Long):String="%,d ₽".format(n).replace(',',' ')
    private fun message(v:String){Toast.makeText(this,v,Toast.LENGTH_SHORT).show();refresh()}
    private fun choices(title:String,values:List<String>,chosen:(Int)->Unit){
        if(values.isEmpty()){AlertDialog.Builder(this).setTitle(title).setMessage("Пока нет доступных вариантов.")
            .setPositiveButton("Хорошо",null).show();return}
        AlertDialog.Builder(this).setTitle(title).setItems(values.toTypedArray()){ _,index -> chosen(index) }
            .setNegativeButton("Закрыть",null).show()
    }
    private fun showSites(kind:BuildingKind){
        val sites=game.city(map.cityId).lots.filter{it.kind==kind}
        choices("${kind.title} · ${game.city(map.cityId).name}",sites.map{l ->
            val owner=game.company(map.cityId)
            val bought=when(kind){
                BuildingKind.MINE -> l.id in owner.mines
                BuildingKind.FACTORY -> l.id in owner.factories
                BuildingKind.WAREHOUSE -> l.id in owner.warehouses
                else -> true
            }
            "${kind.title} ${l.id+1}  ·  ${if(bought)"приобретён" else "купить"}"
        }){showLot(sites[it])}
    }
    private fun showLot(lot:Lot){
        val company=game.company(map.cityId)
        val purchased=when(lot.kind){
            BuildingKind.MINE -> lot.id in company.mines
            BuildingKind.FACTORY -> lot.id in company.factories
            BuildingKind.WAREHOUSE -> lot.id in company.warehouses
            else -> true
        }
        val options=when(lot.kind){
            BuildingKind.MINE -> if(purchased)arrayOf("Шахта 2.0 · прототип","Шахта 1.0 · рабочая","Нанять шахтёра") else arrayOf("Купить шахту")
            BuildingKind.FACTORY -> if(purchased)arrayOf("Производство","Изменить рецепт") else arrayOf("Купить завод")
            BuildingKind.WAREHOUSE -> if(purchased)arrayOf("Посмотреть склад") else arrayOf("Купить склад")
            BuildingKind.MARKET -> arrayOf("Продать ресурсы")
            BuildingKind.MUNICIPAL -> arrayOf("Контракты города")
            BuildingKind.ENERGY -> arrayOf("Информация")
            BuildingKind.RESEARCH -> arrayOf("Древо науки")
        }
        AlertDialog.Builder(this).setTitle("${lot.kind.title} №${lot.id+1}").setItems(options){_,which ->
            when(lot.kind){
                BuildingKind.MINE -> if(!purchased){message(if(game.purchaseMine(map.cityId,lot.id))"Шахта приобретена" else "Недостаточно средств")}
                    else when(which){0->showMine2(lot);1->showMine(lot);else->upgradeMine(lot)}
                BuildingKind.FACTORY -> if(!purchased){message(if(game.purchaseFactory(map.cityId,lot.id))"Завод приобретён" else "Недостаточно средств")}
                    else if(which==0)showFactory(lot) else chooseRecipe(lot)
                BuildingKind.WAREHOUSE -> if(!purchased){message(if(game.purchaseWarehouse(map.cityId,lot.id))"Склад приобретён" else "Недостаточно средств")}
                    else showStorage()
                BuildingKind.MARKET -> sellResources()
                BuildingKind.MUNICIPAL -> showContracts()
                BuildingKind.ENERGY -> showText("Энергетика","Энергетические сети будут развиваться вместе с новыми технологическими эпохами.")
                BuildingKind.RESEARCH -> showResearch()
            }
            save();refresh()
        }.setNegativeButton("Назад",null).show()
    }
    private fun showText(title:String,body:String){AlertDialog.Builder(this).setTitle(title).setMessage(body)
        .setPositiveButton("ОК",null).show()}
    private fun showMine2(lot:Lot){
        GameSession.engine=game
        GameSession.cityId=map.cityId
        GameSession.mineLotId=lot.id
        startActivity(Intent(this,Mine2PreviewActivity::class.java)
            .putExtra("cityId",map.cityId).putExtra("lotId",lot.id))
    }
    private fun showMine(lot:Lot){
        GameSession.engine=game
        GameSession.cityId=map.cityId
        GameSession.mineLotId=lot.id
        startActivity(Intent(this,MineActivity::class.java)
            .putExtra("cityId",map.cityId).putExtra("lotId",lot.id))
    }
    private fun upgradeMine(lot:Lot){
        message(if(game.hireMiner(map.cityId,lot.id))"Шахтёр нанят" else "Недостаточно средств или лимит работников")
    }
    private fun showFactory(lot:Lot){
        val factory=game.company(map.cityId).factories.getValue(lot.id)
        val recipe=Catalog.recipes[factory.recipeId]
        val stored=factory.inputs.entries.joinToString("\n"){"${Catalog.name(it.key)}: ${it.value}"}
        showText("Завод №${lot.id+1}","Рецепт: ${Catalog.name(factory.recipeId)}\nТребуется: ${recipe?.ingredients}\nВходные материалы:\n${stored.ifEmpty{"Нет материалов"}}")
    }
    private fun chooseRecipe(lot:Lot){
        val options=Catalog.recipes.values.toList()
        choices("Выбрать продукцию",options.map{"${Catalog.name(it.output)} · ${it.ingredients.entries.joinToString{r->"${Catalog.name(r.key)} ×${r.value}"}}"}){
            message(if(game.setRecipe(map.cityId,lot.id,options[it].output))"Рецепт обновлён" else "Ошибка")
            save()
        }
    }
    private fun showStorage(){
        val company=game.company(map.cityId)
        val lines=company.storage.entries.filter{it.value>0}.sortedBy{it.key}
            .joinToString("\n"){"${Catalog.name(it.key)}: ${it.value}"}
        showText("Склад · ${game.city(map.cityId).name}",lines.ifEmpty{"Склад пуст. Назначь грузовик: шахта → склад."})
    }
    private fun sellResources(){
        val company=game.company(map.cityId)
        val items=company.storage.entries.filter{it.value>0}
        choices("Рынок: продать материалы",items.map{"${Catalog.name(it.key)} ×${it.value} · ${money(it.value.toLong()*(Catalog.byId[it.key]?.basePrice?:1))}"}){index ->
            val (key,count)=items[index]
            val price=Catalog.byId[key]?.basePrice?:1
            game.state.money+=count.toLong()*price;company.storage.remove(key)
            save();message("Продано на ${money(count.toLong()*price)}")
        }
    }
    private fun showContracts(){
        val entries=game.state.contracts.filter{it.cityId==map.cityId}
        choices("Контракты · ${game.city(map.cityId).name}",entries.map{item->
            "${Catalog.name(item.material)} ${item.delivered}/${item.amount} · ${money(item.reward.toLong())}" +
                if(item.complete)" ✓" else ""
        }){index -> showContract(entries[index])}
    }
    private fun showContract(contract:Contract){
        val cityStorage=game.company(contract.cityId).storage
        val detail="Требуется: ${Catalog.name(contract.material)} ×${contract.amount}\n"+
            "Поставлено: ${contract.delivered}/${contract.amount}\n"+
            "На складе: ${cityStorage[contract.material]?:0}\n"+
            "Награда: ${money(contract.reward.toLong())}\nДеньги и наука начисляются только после доставки грузовиком."
        AlertDialog.Builder(this).setTitle("Контракт №${contract.id}").setMessage(detail)
            .setPositiveButton(if(contract.complete)"Готово" else "Назначить машину") { _,_->
                if(!contract.complete)chooseContractTruck(contract)
            }.setNegativeButton("Назад",null).show()
    }
    private fun chooseContractTruck(contract:Contract){
        val trucks=game.state.trucks
        choices("Выбрать свободный грузовик",trucks.map{"#${it.id} · ${if(it.route==null)"свободен" else "есть маршрут"}"}){index ->
            val truck=trucks[index]
            if(truck.route!=null){message("Сначала сними маршрут у грузовика");return@choices}
            val stores=game.city(contract.cityId).lots.filter{it.id in game.company(contract.cityId).warehouses}
            choices("Со склада",stores.map{"Склад №${it.id+1}"}){storeIndex ->
                val r=TruckRoute(RouteType.WAREHOUSE_CONTRACT,contract.cityId,stores[storeIndex].id,contract.id,contract.material)
                message(if(game.assignTruck(truck.id,r))"Доставка назначена. Отправка после появления ресурса." else "Маршрут недоступен")
                save()
            }
        }
    }
    private fun showTrucks(){
        val trucks=game.state.trucks
        val items=trucks.map {t ->
            "Грузовик #${t.id} · ${t.route?.mode?.title ?: "без назначения"} · ${if(t.timeLeft>0)"в пути ${t.timeLeft}с" else "ожидает"}"
        } + "＋ Купить грузовик"
        choices("Транспорт · ${trucks.size} машин",items){index ->
            if(index==trucks.size){message(if(game.hireTruck())"Грузовик куплен без маршрута" else "Не хватает денег");save()}
            else showTruck(trucks[index])
        }
    }
    private fun showTruck(truck:Truck){
        val route=truck.route
        val detail=if(route==null)"Грузовик в ангаре. Автоназначение отключено."
            else "${route.mode.title}\n${game.city(route.cityId).name}\nРесурс: ${Catalog.name(route.material)}\nГруз: ${truck.carrying} ед."
        AlertDialog.Builder(this).setTitle("Грузовик #${truck.id}").setMessage(detail)
            .setPositiveButton(if(route==null)"Выбрать маршрут" else "Изменить") { _,_ ->
                if(route!=null && !game.unassignTruck(truck.id))message("Дождись завершения рейса")
                else chooseRouteMode(truck)
            }.setNeutralButton("Снять маршрут"){_,_->
                message(if(game.unassignTruck(truck.id))"Маршрут снят" else "Грузовик ещё в пути")
                save()
            }.setNegativeButton("Назад",null).show()
    }
    private fun chooseRouteMode(truck:Truck){
        val modes=RouteType.entries
        choices("Тип доставки",modes.map{it.title}){index ->
            val mode=modes[index]
            val (sources,destinations)=game.routeOptions(map.cityId,mode)
            if(sources.isEmpty()||destinations.isEmpty()){
                message("Сначала приобрети шахту/склад и завод или выбери контракт")
                return@choices
            }
            choices("Откуда забрать груз?",sources.map{"${it.kind.title} №${it.id+1}"}){srcIndex ->
                val source=sources[srcIndex]
                choices("Куда доставить?",destinations.map{it.second}){dstIndex ->
                    val dest=destinations[dstIndex]
                    val materials=when(mode){
                        RouteType.MINE_FACTORY,RouteType.MINE_WAREHOUSE -> game.company(map.cityId).mines.getValue(source.id).ores
                        RouteType.WAREHOUSE_FACTORY -> Catalog.recipes[game.company(map.cityId).factories.getValue(dest.first).recipeId]?.ingredients?.keys?.toList()?:emptyList()
                        RouteType.WAREHOUSE_CONTRACT -> listOf(game.state.contracts.first{it.id==dest.first}.material)
                    }
                    val valid=materials.filter{game.canAssign(TruckRoute(mode,map.cityId,source.id,dest.first,it))}
                    choices("Какой ресурс перевозить?",valid.map{Catalog.name(it)}){materialIndex ->
                        val route=TruckRoute(mode,map.cityId,source.id,dest.first,valid[materialIndex])
                        message(if(game.assignTruck(truck.id,route))"Маршрут назначен: ${mode.title}" else "Не получилось назначить маршрут")
                        save()
                    }
                }
            }
        }
    }
    private fun showResearch(){
        GameSession.engine=game
        startActivity(Intent(this,ResearchActivity::class.java))
    }
    private fun showCompany(){
        val c=game.company(map.cityId)
        val info="Баланс: ${money(game.state.money)}\nЭпоха: ${game.state.era}/10\n"+
            "Наука: ${game.state.science}\nГородов: ${game.state.cities.size}\n"+
            "Каталог ресурсов: ${Catalog.materials.size}\nШахт: ${c.mines.size}\n"+
            "Заводов: ${c.factories.size}\nСкладов: ${c.warehouses.size}\nГрузовиков: ${game.state.trucks.size}\n"+
            "Перевезено: ${game.state.totalShipped} ед."
        AlertDialog.Builder(this).setTitle("DailyCorp · компания").setMessage(info)
            .setPositiveButton("Древо науки") { _,_ -> showResearch() }
            .setNeutralButton("Следующая эпоха") { _,_ ->
                message(if(game.buyEra())"Открыта эпоха ${game.state.era}!" else "Сначала исследуй горное дело эпохи. Нужно ${game.state.era*100} науки и ${money(game.state.era*500L)}")
                save()
            }.setNegativeButton("Закрыть",null).show()
    }
}
