package com.dailycorp.nativegame

import java.io.Serializable
import java.util.Random
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Pure JVM rules: UI and Android imports are forbidden in this file. */
data class Point(val x: Int, val y: Int) : Serializable

enum class BuildingKind(val title: String) : Serializable {
    MINE("Шахта"), FACTORY("Завод"), WAREHOUSE("Склад"),
    MARKET("Рынок"), MUNICIPAL("Мэрия"), ENERGY("Энергия"),
    RESEARCH("Исследовательский центр")
}

data class Lot(val id: Int, val kind: BuildingKind, val pos: Point, val gate: Point) : Serializable

data class City(val id: Int, val name: String, val specialization: String, val seed: Long,
    val population: Int, val lots: List<Lot>) : Serializable

data class MapPlan(val width: Int, val height: Int, val roads: Set<Point>, val lots: List<Lot>,
    val homes: List<Point>, val center: Point) : Serializable

data class Material(val id: String, val name: String, val era: Int, val basePrice: Int) : Serializable

data class Recipe(val output: String, val ingredients: Map<String, Int>, val seconds: Int) : Serializable

data class MineState(val lotId: Int, val depth: Int, val ores: List<String>,
    val reserves: MutableMap<String, Int>, var workers: Int = 1,
    val loading: MutableMap<String, Int> = mutableMapOf(), var cooldown: Int = 0,
    var interior: UndergroundMine? = null) : Serializable {
    companion object { private const val serialVersionUID: Long = -9128487685651322306L }
}

data class FactoryState(val lotId: Int, var recipeId: String = "steel",
    val inputs: MutableMap<String, Int> = mutableMapOf(), var progress: Int = 0) : Serializable

data class CityCompany(val mines: MutableMap<Int, MineState> = mutableMapOf(),
    val factories: MutableMap<Int, FactoryState> = mutableMapOf(),
    val warehouses: MutableSet<Int> = mutableSetOf(),
    val storage: MutableMap<String, Int> = mutableMapOf()) : Serializable

enum class RouteType(val title: String) : Serializable {
    MINE_FACTORY("Шахта → завод"), MINE_WAREHOUSE("Шахта → склад"),
    WAREHOUSE_FACTORY("Склад → завод"), WAREHOUSE_CONTRACT("Склад → контракт")
}

data class TruckRoute(val mode: RouteType, val cityId: Int, val sourceLot: Int,
    val targetId: Int, val material: String) : Serializable

data class Truck(val id: Int, var level: Int = 1, var route: TruckRoute? = null,
    var timeLeft: Int = 0, var carrying: Int = 0, var returning: Boolean = false) : Serializable

data class Contract(val id: Int, val cityId: Int, val material: String,
    val amount: Int, val reward: Int, var delivered: Int = 0) : Serializable {
    val complete: Boolean get() = delivered >= amount
}

data class GameState(val seed: Long, val cities: List<City>, val companies: MutableMap<Int, CityCompany>,
    val trucks: MutableList<Truck>, val contracts: MutableList<Contract>,
    var money: Long = 26000, var era: Int = 1, var science: Int = 0,
    var totalShipped: Long = 0, var gameSeconds: Long = 0,
    var unlockedResearch: MutableSet<String>? = mutableSetOf()) : Serializable {
    companion object { private const val serialVersionUID: Long = -7769203087618670042L }
}

object Catalog {
    // First eight are stable compatibility IDs for economy and logistics.
    val base = listOf(
        Material("coal", "Уголь", 1, 12), Material("copper", "Медь", 1, 28),
        Material("iron", "Железо", 1, 42), Material("gold", "Золото", 1, 110),
        Material("steel", "Сталь", 2, 160), Material("wire", "Провода", 2, 60),
        Material("parts", "Механизмы", 3, 495), Material("electronics", "Электроника", 4, 470)
    )
    private val families = listOf("Боксит", "Никель", "Цинк", "Свинец", "Вольфрам", "Кобальт",
        "Титан", "Литий", "Графит", "Кварц", "Сера", "Уран", "Платина", "Серебро",
        "Марганец", "Хром", "Молибден", "Олово", "Кремний", "Редкоземельный концентрат")
    val basicMinerals = listOf(
        Material("clay","Глина",1,9),
        Material("sand","Песок",1,8),
        Material("gravel","Гравий",1,12),
        Material("granite","Гранит",1,23),
        Material("salt","Соль",1,20),
        Material("sulfur","Сера",2,38),
        Material("shale","Сланец",1,15)
    )
    val manufactured = listOf(
        Material("brick","Кирпич",1,70),
        Material("glass","Стекло",2,110),
        Material("cement","Цемент",2,135),
        Material("concrete","Бетон",2,220),
        Material("ceramics","Керамика",3,260),
        Material("chemicals","Химикаты",3,330),
        Material("alloy","Сплав",4,450),
        Material("machine_parts","Промышленные детали",4,710),
        Material("construction_kit","Строительный комплект",3,850)
    )
    val materials: List<Material> = base + basicMinerals + manufactured + families.flatMapIndexed { i, family ->
        (1..12).map { grade ->
            Material("ore_${i}_$grade", "$family · сорт $grade", 1 + (grade-1)/2, 35 + i*9 + grade*13)
        }
    }
    val byId = materials.associateBy { it.id }
    val recipes: Map<String, Recipe> = linkedMapOf(
        "brick" to Recipe("brick", mapOf("clay" to 4,"coal" to 1), 14),
        "glass" to Recipe("glass", mapOf("sand" to 5,"coal" to 2), 19),
        "cement" to Recipe("cement", mapOf("granite" to 2,"clay" to 3,"coal" to 2), 21),
        "concrete" to Recipe("concrete", mapOf("cement" to 2,"sand" to 4,"gravel" to 4), 24),
        "steel" to Recipe("steel", mapOf("iron" to 3, "coal" to 2), 18),
        "wire" to Recipe("wire", mapOf("copper" to 3), 14),
        "ceramics" to Recipe("ceramics",mapOf("clay" to 4,"sand" to 2,"salt" to 1), 22),
        "chemicals" to Recipe("chemicals",mapOf("sulfur" to 3,"salt" to 2,"coal" to 1), 28),
        "parts" to Recipe("parts", mapOf("steel" to 3, "wire" to 2,"glass" to 1), 28),
        "alloy" to Recipe("alloy",mapOf("steel" to 2,"sulfur" to 1,"granite" to 2), 33),
        "machine_parts" to Recipe("machine_parts",mapOf("alloy" to 2,"parts" to 2), 38),
        "electronics" to Recipe("electronics", mapOf("gold" to 2, "wire" to 3,"glass" to 1), 32),
        "construction_kit" to Recipe("construction_kit", mapOf("brick" to 3,
            "concrete" to 2,"steel" to 2,"glass" to 1), 44)
    )
    fun name(id: String) = byId[id]?.name ?: id
}

/** Stable city plans: roads are finalized before buying/building lots. */
object CityGenerator {
    const val WIDTH = 36
    const val HEIGHT = 34
    private val roadDirs = listOf(Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1))
    fun plan(seed: Long, lotsPerCity: Map<BuildingKind, Int>): MapPlan {
        val random = Random(seed)
        val axisX = listOf(5, 12, 19, 26, 32).map { it + random.nextInt(3)-1 }
        val axisY = listOf(5, 12, 19, 26, 30).map { it + random.nextInt(3)-1 }
        val roads = mutableSetOf<Point>()
        for (y in axisY) for (x in 2 until WIDTH-2) roads.add(Point(x,y))
        for (x in axisX) for (y in 2 until HEIGHT-2) roads.add(Point(x,y))
        repeat(5) { n ->
            val ix = random.nextInt(4); val iy = random.nextInt(4)
            if (n % 2 == 0) {
                val y = (axisY[iy] + axisY[iy+1]) / 2
                for (x in axisX[ix]..axisX[ix+1]) roads.add(Point(x,y))
            } else {
                val x = (axisX[ix] + axisX[ix+1]) / 2
                for (y in axisY[iy]..axisY[iy+1]) roads.add(Point(x,y))
            }
        }
        val used = mutableSetOf<Point>()
        val center = Point(axisX[2], axisY[2])
        for (dx in -2..2) for (dy in -2..2) used.add(Point(center.x+dx,center.y+dy))
        val lots = mutableListOf<Lot>()
        var lotId = 0
        for (kind in BuildingKind.entries) {
            val count = lotsPerCity[kind] ?: 0
            repeat(count) {
                val candidates = mutableListOf<Pair<Point, Point>>()
                for (y in 3 until HEIGHT-3) for (x in 3 until WIDTH-3) {
                    val p = Point(x,y)
                    if (p in used || p in roads) continue
                    val entry = roadDirs.asSequence().map { Point(x+it.x,y+it.y) }.firstOrNull { it in roads }
                    if (entry != null && lots.none { lot ->
                            val q = lot.pos
                            (q.x-x)*(q.x-x)+(q.y-y)*(q.y-y) < 10
                        }) candidates.add(p to entry)
                }
                if (candidates.isNotEmpty()) {
                    val chosen = candidates[random.nextInt(candidates.size)]
                    used.add(chosen.first)
                    lots.add(Lot(lotId++,kind,chosen.first,chosen.second))
                }
            }
        }
        val homes = mutableListOf<Point>()
        repeat(170) {
            val p = Point(random.nextInt(WIDTH-6)+3, random.nextInt(HEIGHT-6)+3)
            if (p !in roads && p !in used && lots.none { l ->
                    abs(l.pos.x-p.x) <= 1 && abs(l.pos.y-p.y) <= 1
                } && homes.none { h -> h == p }) {
                homes.add(p)
                used.add(p)
            }
        }
        return MapPlan(WIDTH,HEIGHT,roads,lots,homes,center)
    }
    fun makeCities(seed: Long, amount: Int = 48): List<City> {
        val random = Random(seed)
        val specials = listOf("Горнодобывающий", "Промышленный", "Портовый", "Научный",
            "Аграрный", "Технологический", "Столичный", "Торговый")
        return (1..amount).map { id ->
            val citySeed = random.nextLong() and Long.MAX_VALUE
            val specialization = specials[(id-1)%specials.size]
            val counts = mapOf(
                BuildingKind.MINE to 3+random.nextInt(6),
                BuildingKind.FACTORY to 2+random.nextInt(4),
                BuildingKind.WAREHOUSE to 2+random.nextInt(3),
                BuildingKind.MARKET to 1,
                BuildingKind.MUNICIPAL to 1,
                BuildingKind.ENERGY to 1,
                BuildingKind.RESEARCH to 1
            )
            val map = plan(citySeed,counts)
            City(id, "Город %03d".format(id),specialization,citySeed,3500+random.nextInt(24000),map.lots)
        }
    }
    fun plan(city: City): MapPlan = plan(city.seed,BuildingKind.entries.associateWith { k -> city.lots.count { it.kind==k } })
}

class GameEngine(val state: GameState) {
    companion object {
        fun newGame(seed: Long = 20261020L): GameEngine {
            val cities = CityGenerator.makeCities(seed)
            val companies = cities.associate { it.id to CityCompany() }.toMutableMap()
            companies[1]!!.warehouses.add(cities.first().lots.first { it.kind == BuildingKind.WAREHOUSE }.id)
            val contracts = cities.flatMap { city ->
                listOf("coal","iron","copper","gold","steel","wire").mapIndexed { index, material ->
                    val amount = 5 + index * 3
                    val reward = amount * (Catalog.byId[material]!!.basePrice * 2) + 250
                    Contract(city.id * 100 + index, city.id, material, amount, reward)
                }
            }.toMutableList()
            return GameEngine(GameState(seed,cities,companies,mutableListOf(Truck(1)),contracts))
        }
    }
    fun city(id: Int): City = state.cities.first { it.id == id }
    fun company(cityId: Int): CityCompany = state.companies.getValue(cityId)
    fun lot(cityId: Int, lotId: Int): Lot? = city(cityId).lots.firstOrNull { it.id == lotId }
    fun purchaseMine(cityId: Int, lotId: Int): Boolean {
        val l = lot(cityId,lotId) ?: return false
        if (l.kind != BuildingKind.MINE || company(cityId).mines.containsKey(lotId)) return false
        val price = 450L + lotId*85L
        if (state.money < price) return false
        val random = Random(city(cityId).seed xor (lotId.toLong()*9973))
        val depth = 6 + random.nextInt(75)
        val randomOres=Catalog.materials.asSequence().filter { it.id.startsWith("ore_") &&
            it.era <= max(state.era,2) }.map {it.id}.toList()
        val sampledBasics=Catalog.basicMinerals.map{it.id}
            .shuffled(kotlin.random.Random(random.nextInt())).take(4)
        val mineralIds=(listOf("coal","iron","copper","gold") + sampledBasics +
            randomOres.shuffled(kotlin.random.Random(random.nextInt())).take(4)).distinct()
        val reserves = mineralIds.associateWith { 15 + random.nextInt(26) * depth }.toMutableMap()
        company(cityId).mines[lotId] = MineState(lotId,depth,mineralIds,reserves)
        state.money -= price
        return true
    }
    fun purchaseFactory(cityId: Int, lotId: Int): Boolean {
        val l=lot(cityId,lotId) ?: return false
        if (l.kind!=BuildingKind.FACTORY || company(cityId).factories.containsKey(lotId) || state.money<1250) return false
        state.money-=1250; company(cityId).factories[lotId]=FactoryState(lotId)
        return true
    }
    fun purchaseWarehouse(cityId: Int, lotId: Int): Boolean {
        val l=lot(cityId,lotId) ?: return false
        if (l.kind!=BuildingKind.WAREHOUSE || lotId in company(cityId).warehouses || state.money<700) return false
        state.money-=700; company(cityId).warehouses.add(lotId)
        return true
    }
    fun setRecipe(cityId: Int, lotId: Int, recipe: String): Boolean {
        val factory=company(cityId).factories[lotId] ?: return false
        if (!Catalog.recipes.containsKey(recipe)) return false
        factory.recipeId=recipe;factory.progress=0;return true
    }
    fun hireTruck(): Boolean {
        val cost=800L+state.trucks.size*350L
        if(state.money<cost || state.trucks.size >= 40) return false
        state.money-=cost;state.trucks.add(Truck((state.trucks.maxOfOrNull{it.id}?:0)+1));return true
    }
    fun canAssign(route: TruckRoute): Boolean {
        val c=company(route.cityId)
        val src=lot(route.cityId,route.sourceLot) ?: return false
        val dst=lot(route.cityId,route.targetId)
        val material=route.material
        return when(route.mode) {
            RouteType.MINE_FACTORY -> src.kind==BuildingKind.MINE && src.id in c.mines &&
                dst?.kind==BuildingKind.FACTORY && dst.id in c.factories &&
                c.mines.getValue(src.id).ores.contains(material) &&
                Catalog.recipes[c.factories.getValue(dst.id).recipeId]?.ingredients?.containsKey(material)==true
            RouteType.MINE_WAREHOUSE -> src.kind==BuildingKind.MINE && src.id in c.mines &&
                dst?.kind==BuildingKind.WAREHOUSE && dst.id in c.warehouses &&
                c.mines.getValue(src.id).ores.contains(material)
            RouteType.WAREHOUSE_FACTORY -> src.kind==BuildingKind.WAREHOUSE && src.id in c.warehouses &&
                dst?.kind==BuildingKind.FACTORY && dst.id in c.factories &&
                Catalog.recipes[c.factories.getValue(dst.id).recipeId]?.ingredients?.containsKey(material)==true
            RouteType.WAREHOUSE_CONTRACT -> src.kind==BuildingKind.WAREHOUSE && src.id in c.warehouses &&
                state.contracts.any { it.id==route.targetId && it.cityId==route.cityId &&
                    it.material==material && !it.complete }
        }
    }
    fun assignTruck(truckId: Int, route: TruckRoute): Boolean {
        val truck=state.trucks.firstOrNull{it.id==truckId}?:return false
        if(truck.carrying>0 || truck.timeLeft>0 || !canAssign(route))return false
        truck.route=route;truck.returning=false;return true
    }
    fun unassignTruck(truckId:Int):Boolean {
        val truck=state.trucks.firstOrNull{it.id==truckId}?:return false
        if(truck.timeLeft>0 || truck.carrying>0)return false
        truck.route=null;return true
    }
    fun buyEra():Boolean {
        if (!ScienceTree.canAdvanceEra(state)) return false
        state.science -= state.era*100
        state.money -= state.era*500L
        state.era++
        return true
    }
    fun research(id:String):Boolean = ScienceTree.unlock(state,id)
    fun mineFloor(cityId:Int,lotId:Int):UndergroundFloor? {
        val mine = company(cityId).mines[lotId] ?: return null
        return MineWorld.floor(mine,city(cityId).seed xor lotId.toLong())
    }
    fun dig(cityId:Int,lotId:Int,x:Int,y:Int):Boolean {
        val mine = company(cityId).mines[lotId] ?: return false
        return MineWorld.toggleDig(mine,city(cityId).seed xor lotId.toLong(),x,y)
    }
    fun hireMiner(cityId:Int,lotId:Int):Boolean {
        val mine = company(cityId).mines[lotId] ?: return false
        val cost = 200L * mine.workers
        if(mine.workers>=12 || state.money<cost)return false
        state.money-=cost;mine.workers++
        mineFloor(cityId,lotId)
        return true
    }
    fun buyMineCart(cityId:Int,lotId:Int):Boolean {
        val mine = company(cityId).mines[lotId] ?: return false
        val underground = MineWorld.interior(mine)
        val cost = 240L * underground.cartsOwned
        if(underground.cartsOwned>=8 || state.money<cost)return false
        state.money-=cost;underground.cartsOwned++
        mineFloor(cityId,lotId)
        return true
    }
    fun improveDrill(cityId:Int,lotId:Int):Boolean {
        val mine = company(cityId).mines[lotId] ?: return false
        val underground = MineWorld.interior(mine)
        val price = 250L*underground.drillLevel
        if (underground.drillLevel>=8 || state.money<price)return false
        state.money-=price;underground.drillLevel++
        return true
    }
    fun improveMineCart(cityId:Int,lotId:Int):Boolean {
        val mine = company(cityId).mines[lotId] ?: return false
        val underground = MineWorld.interior(mine)
        val price = 300L*underground.cartLevel
        if(underground.cartLevel>=8 || state.money<price)return false
        state.money-=price;underground.cartLevel++
        return true
    }
    fun deepenMine(cityId:Int,lotId:Int):Boolean {
        val mine = company(cityId).mines[lotId] ?: return false
        val underground = MineWorld.interior(mine)
        val current = mineFloor(cityId,lotId) ?: return false
        val cost = 250L*underground.unlockedFloor
        if(underground.unlockedFloor >= mine.depth || current.excavated<6 || state.money<cost)return false
        state.money-=cost;underground.unlockedFloor++
        underground.activeFloor=underground.unlockedFloor
        mineFloor(cityId,lotId)
        return true
    }
    fun selectMineFloor(cityId:Int,lotId:Int,number:Int):Boolean {
        val mine = company(cityId).mines[lotId] ?: return false
        return MineWorld.changeFloor(mine,city(cityId).seed xor lotId.toLong(),number)
    }
    fun routeOptions(cityId:Int,mode:RouteType): Pair<List<Lot>,List<Pair<Int,String>>> {
        val c=company(cityId)
        val sourceKind=if(mode==RouteType.MINE_FACTORY || mode==RouteType.MINE_WAREHOUSE)BuildingKind.MINE else BuildingKind.WAREHOUSE
        val sources=city(cityId).lots.filter { it.kind==sourceKind &&
            (if(sourceKind==BuildingKind.MINE)it.id in c.mines else it.id in c.warehouses) }
        val destinations=when(mode){
            RouteType.MINE_WAREHOUSE -> city(cityId).lots.filter {it.id in c.warehouses && it.kind==BuildingKind.WAREHOUSE}
                .map {it.id to "Склад №${it.id}"}
            RouteType.MINE_FACTORY,RouteType.WAREHOUSE_FACTORY -> city(cityId).lots.filter {it.id in c.factories && it.kind==BuildingKind.FACTORY}
                .map {it.id to "Завод №${it.id}"}
            RouteType.WAREHOUSE_CONTRACT -> state.contracts.filter {it.cityId==cityId && !it.complete}
                .map {it.id to "Контракт #${it.id}: ${Catalog.name(it.material)}"}
        }
        return sources to destinations
    }
    private fun sourceInventory(route:TruckRoute):MutableMap<String,Int> {
        val c=company(route.cityId)
        return if(route.mode==RouteType.MINE_FACTORY || route.mode==RouteType.MINE_WAREHOUSE)
            c.mines.getValue(route.sourceLot).loading else c.storage
    }
    fun tick(seconds:Int=1,excludedMineCityId:Int=-1,excludedMineLotId:Int=-1) {
        repeat(seconds.coerceIn(0,1000)) {
            state.gameSeconds++
            for (city in state.cities) {
                val c=company(city.id)
                for(mine in c.mines.values){
                    if(city.id==excludedMineCityId && mine.lotId==excludedMineLotId)continue
                    MineWorld.step(mine,city.seed xor mine.lotId.toLong(),
                        ScienceTree.drillBoost(state),ScienceTree.cartBoost(state),
                        ScienceTree.geologyBoost(state))
                }
                for(factory in c.factories.values){
                    val recipe=Catalog.recipes[factory.recipeId]?:continue
                    if(recipe.ingredients.any{(item,amount)->(factory.inputs[item]?:0)<amount}){factory.progress=0;continue}
                    factory.progress+=1+ScienceTree.productionBoost(state)
                    if(factory.progress>=recipe.seconds){
                        for((item,amount) in recipe.ingredients)factory.inputs[item]=factory.inputs.getValue(item)-amount
                        c.storage[recipe.output]=(c.storage[recipe.output]?:0)+1
                        factory.progress=0
                    }
                }
            }
            for(truck in state.trucks){
                val route=truck.route?:continue
                if(!canContinue(truck,route))continue
                if(truck.timeLeft>0){
                    truck.timeLeft--
                    if(truck.timeLeft==0){
                        if(truck.returning){truck.returning=false}
                        else deliver(truck,route)
                    }
                    continue
                }
                if(truck.returning)continue
                if(truck.carrying>0){ deliver(truck,route);continue }
                val inventory=sourceInventory(route)
                val available=inventory[route.material]?:0
                val needed=when(route.mode){
                    RouteType.MINE_FACTORY,RouteType.WAREHOUSE_FACTORY -> {
                        val factory=company(route.cityId).factories.getValue(route.targetId)
                        40-(factory.inputs[route.material]?:0)
                    }
                    RouteType.MINE_WAREHOUSE -> 200-(company(route.cityId).storage[route.material]?:0)
                    RouteType.WAREHOUSE_CONTRACT -> state.contracts.first {it.id==route.targetId}.let{it.amount-it.delivered}
                }
                val onRoad=state.trucks.filter {it!==truck && it.route?.mode==route.mode &&
                    it.route?.cityId==route.cityId && it.route?.targetId==route.targetId &&
                    it.route?.material==route.material && it.carrying>0}.sumOf{it.carrying}
                val amount=min(min(available,max(0,needed-onRoad)),
                    4+truck.level*3+ScienceTree.logisticsBoost(state)*2)
                if(amount<=0)continue
                inventory[route.material]=available-amount
                truck.carrying=amount
                val from=lot(route.cityId,route.sourceLot)?.pos ?:continue
                val to=lot(route.cityId,route.targetId)?.pos ?:from
                truck.timeLeft=max(2,(abs(from.x-to.x)+abs(from.y-to.y))*2/
                    (truck.level+ScienceTree.logisticsBoost(state)))
            }
        }
    }
    private fun canContinue(truck:Truck,route:TruckRoute):Boolean {
        if(route.mode==RouteType.WAREHOUSE_CONTRACT && state.contracts.firstOrNull{it.id==route.targetId}?.complete==true) {
            if(truck.carrying>0){
                val c=company(route.cityId)
                c.storage[route.material]=(c.storage[route.material]?:0)+truck.carrying
                truck.carrying=0
            }
            truck.route=null;truck.timeLeft=0;truck.returning=false
            return false
        }
        return true
    }
    private fun deliver(truck:Truck,route:TruckRoute){
        val amount=truck.carrying
        if(amount==0)return
        val c=company(route.cityId)
        when(route.mode){
            RouteType.MINE_FACTORY,RouteType.WAREHOUSE_FACTORY -> {
                val inputs=c.factories.getValue(route.targetId).inputs
                inputs[route.material]=(inputs[route.material]?:0)+amount
            }
            RouteType.MINE_WAREHOUSE -> c.storage[route.material]=(c.storage[route.material]?:0)+amount
            RouteType.WAREHOUSE_CONTRACT -> {
                val contract=state.contracts.first{it.id==route.targetId}
                val valid=min(amount,contract.amount-contract.delivered)
                contract.delivered+=valid
                if(valid<amount)c.storage[route.material]=(c.storage[route.material]?:0)+(amount-valid)
                if(contract.complete){state.money+=contract.reward;state.science+=30+ScienceTree.contractScienceBoost(state)}
            }
        }
        state.totalShipped+=amount
        truck.carrying=0
        truck.returning=true
        truck.timeLeft=2
    }
}
