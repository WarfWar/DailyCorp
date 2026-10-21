package com.dailycorp.nativegame

import org.junit.Assert.*
import org.junit.Test

class Mine2EconomyIntegrationTest {
    @Test fun cumulativeDeliveredOreIsCreditedOnlyOnce(){
        val game=GameEngine.newGame(10101L)
        val lot=game.city(1).lots.first{it.kind==BuildingKind.MINE}
        assertTrue(game.purchaseMine(1,lot.id))
        val mine=game.company(1).mines.getValue(lot.id)
        assertEquals(5,game.applyMine2Delivery(1,lot.id,mapOf("iron" to 5)))
        assertEquals(5,mine.loading["iron"])
        assertEquals(0,game.applyMine2Delivery(1,lot.id,mapOf("iron" to 5)))
        assertEquals(5,mine.loading["iron"])
        assertEquals(6,game.applyMine2Delivery(1,lot.id,mapOf("iron" to 8,"clay" to 3)))
        assertEquals(8,mine.loading["iron"])
        assertEquals(3,mine.loading["clay"])
        assertEquals(0,game.applyMine2Delivery(1,lot.id,mapOf("iron" to 5)))
        assertEquals(8,mine.loading["iron"])
    }
    @Test fun activeMine2DisablesOnlyThatLegacyMine(){
        val game=GameEngine.newGame(37337L)
        val mineLot=game.city(1).lots.first{it.kind==BuildingKind.MINE}
        assertTrue(game.purchaseMine(1,mineLot.id))
        val mine=game.company(1).mines.getValue(mineLot.id)
        val floor=game.mineFloor(1,mineLot.id)!!
        floor.blocks[4][15]=MineBlock(MineTerrain.ROCK,hardness=1,ordered=true)
        mine.mine2ProductionEnabled=true
        game.tick(6)
        assertEquals(0,floor.excavated)
        mine.mine2ProductionEnabled=false
        game.tick(6)
        assertEquals(1,floor.excavated)
    }
    @Test fun oldCartSnapshotDelayNoLongerCausesHalts(){
        val game=GameEngine.newGame(5151L)
        val mineLot=game.city(1).lots.first{it.kind==BuildingKind.MINE}
        assertTrue(game.purchaseMine(1,mineLot.id))
        val floor=game.mineFloor(1,mineLot.id)!!
        val cart=floor.carts.single()
        val start=cart.x
        floor.piles.add(MinePile(MineWorld.ENTRANCE_X+4,MineWorld.ENTRANCE_Y,
            "iron",12))
        cart.delay=1 // stale 0.13 save should not pause cart
        game.tick()
        assertEquals(start+1,cart.x)
        assertEquals(0,cart.delay)
        game.tick()
        assertEquals(start+2,cart.x)
        game.tick()
        assertEquals(start+3,cart.x)
    }
    @Test fun legacyCartMotionHasConstantSpeedWithinEachCell(){
        val track=MotionTrack(0f,0f,1000L)
        track.target(1f,0f,0L)
        assertEquals(.25f,track.position(250L).x,.001f)
        assertEquals(.50f,track.position(500L).x,.001f)
        assertEquals(.75f,track.position(750L).x,.001f)
        track.target(2f,0f,1000L)
        assertEquals(1.25f,track.position(1250L).x,.001f)
        assertEquals(1.50f,track.position(1500L).x,.001f)
    }
    @Test fun oreFromMine2CanUseExistingTrucksEvenWhenNotOriginalOre(){
        val game=GameEngine.newGame(80158L)
        val city=game.city(1)
        val mineLot=city.lots.first{it.kind==BuildingKind.MINE}
        val warehouse=city.lots.first{it.kind==BuildingKind.WAREHOUSE}
        assertTrue(game.purchaseMine(1,mineLot.id))
        val mine=game.company(1).mines.getValue(mineLot.id)
        mine.mine2ProductionEnabled=true
        val unexpected=(Catalog.basicMinerals.map{it.id}-mine.ores.toSet()).first()
        assertEquals(4,game.applyMine2Delivery(1,mineLot.id,mapOf(unexpected to 4)))
        assertTrue(unexpected in game.mineProducts(1,mineLot.id))
        val route=TruckRoute(RouteType.MINE_WAREHOUSE,1,mineLot.id,warehouse.id,
            unexpected)
        assertTrue(game.canAssign(route))
        mine.mine2ProductionEnabled=false
        assertFalse(game.canAssign(route))
    }

}
