package com.dailycorp.nativegame

import java.io.*
import kotlin.math.abs

fun main() {
    check(Catalog.materials.size == 248) { "Resource catalog must have 248 distinct materials" }
    check(Catalog.materials.map {it.id}.toSet().size == 248)
    val engine = GameEngine.newGame(123456L)
    val state = engine.state
    check(state.cities.size == 48)
    val first = state.cities.first()
    val second = state.cities[1]
    val plan = CityGenerator.plan(first)
    val twice = CityGenerator.plan(first)
    check(plan.roads == twice.roads && plan.lots == twice.lots)
    check(plan.roads != CityGenerator.plan(second).roads)
    for (city in state.cities) {
        val cityPlan=CityGenerator.plan(city)
        check(city.lots == cityPlan.lots) {"Unstable city lots: ${city.id}"}
        check(city.lots.count{it.kind == BuildingKind.MINE} >= 3)
        for(lot in city.lots) {
            check(lot.pos !in cityPlan.roads) {"Road over plot: ${city.id}/${lot.id}"}
            check(lot.gate in cityPlan.roads)
            check(abs(lot.pos.x-lot.gate.x)+abs(lot.pos.y-lot.gate.y)==1)
        }
    }
    val mine=first.lots.first{it.kind == BuildingKind.MINE}
    val factory=first.lots.first{it.kind == BuildingKind.FACTORY}
    val store=first.lots.first{it.kind == BuildingKind.WAREHOUSE}
    check(state.trucks.size == 1 && state.trucks[0].route == null)
    check(engine.purchaseMine(1,mine.id))
    check(engine.purchaseFactory(1,factory.id))
    check(store.id in engine.company(1).warehouses)
    val mc=engine.company(1).mines.getValue(mine.id)
    check(mc.depth in 6..80 && mc.ores.size >= 4)
    mc.loading["iron"] = 7
    mc.loading["coal"] = 7
    val truck=state.trucks.first()
    check(!engine.canAssign(TruckRoute(RouteType.MINE_FACTORY,1,mine.id,factory.id,"gold")))
    check(engine.assignTruck(truck.id,TruckRoute(RouteType.MINE_FACTORY,1,mine.id,factory.id,"iron")))
    engine.tick(180)
    check(engine.company(1).factories.getValue(factory.id).inputs.getOrDefault("iron",0)>=7)
    check(engine.unassignTruck(truck.id))
    check(engine.assignTruck(truck.id,TruckRoute(RouteType.MINE_FACTORY,1,mine.id,factory.id,"coal")))
    engine.tick(180)
    check(engine.company(1).storage.getOrDefault("steel",0)>0) { "Factory didn't produce steel" }
    mc.loading["coal"] = 0
    mc.reserves["coal"] = 0
    engine.tick(240)
    check(engine.unassignTruck(truck.id))
    mc.loading["gold"]=4
    check(engine.assignTruck(truck.id,TruckRoute(RouteType.MINE_WAREHOUSE,1,mine.id,store.id,"gold")))
    engine.tick(180)
    check(engine.company(1).storage.getOrDefault("gold",0)>=4)
    check(engine.unassignTruck(truck.id))
    engine.company(1).storage["coal"]=12
    check(engine.assignTruck(truck.id,TruckRoute(RouteType.WAREHOUSE_FACTORY,1,store.id,factory.id,"coal")))
    engine.tick(180)
    check(engine.unassignTruck(truck.id))
    val contract=state.contracts.first{it.cityId==1 && it.material=="coal"}
    engine.company(1).storage["coal"]=contract.amount+5
    check(engine.assignTruck(truck.id,TruckRoute(RouteType.WAREHOUSE_CONTRACT,1,store.id,contract.id,"coal")))
    val before=state.money
    engine.tick(1)
    check(state.money==before) {"Premature contract payout"}
    engine.tick(150)
    check(contract.complete && state.money >= before + contract.reward) {"Contract was not completed with physical shipments"}
    check(truck.route == null) {"Completed contract must clear assignment"}
    check(state.science>=30)
    val bytes=ByteArrayOutputStream()
    ObjectOutputStream(bytes).use {it.writeObject(state)}
    val restored=ObjectInputStream(ByteArrayInputStream(bytes.toByteArray())).use{it.readObject() as GameState}
    check(restored.cities.size==48 && restored.trucks[0].route==null)
    println("NATIVE CORE PASSED: 48 deterministic cities, 248 resources, roads clear of lots, 4 logistics modes, factory, contracts and persistence")
}
