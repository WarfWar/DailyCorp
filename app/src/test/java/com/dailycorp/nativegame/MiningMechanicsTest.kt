package com.dailycorp.nativegame

import org.junit.Test
import org.junit.Assert.*
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream

class MiningMechanicsTest {
    @Test fun workersExcavateAndCartsDeliverOnlyAfterOrders() {
        val game=GameEngine.newGame(112233L)
        val mineId=game.city(1).lots.first{it.kind==BuildingKind.MINE}.id
        assertTrue(game.purchaseMine(1,mineId))
        val mine=game.company(1).mines.getValue(mineId)
        val floor=game.mineFloor(1,mineId)!!
        val before=mine.reserves["iron"] ?: 0
        floor.blocks[4][15] = MineBlock(MineTerrain.ORE,"iron",2,1)
        game.tick(15)
        assertEquals(0,floor.excavated)
        assertEquals(0,mine.loading["iron"]?:0)
        assertTrue(game.dig(1,mineId,15,4))
        game.tick(95)
        assertEquals(MineTerrain.TUNNEL,floor.blocks[4][15].terrain)
        assertTrue(floor.excavated>=1)
        assertTrue((mine.loading["iron"]?:0)>=2)
        assertEquals(before-2,mine.reserves["iron"]?:0)
        assertFalse(floor.blocks[4][15].ordered)
    }

    @Test fun mineEquipmentFloorsAndSaveRestore() {
        val game=GameEngine.newGame(778899L)
        val id=game.city(1).lots.first{it.kind==BuildingKind.MINE}.id
        assertTrue(game.purchaseMine(1,id))
        assertTrue(game.hireMiner(1,id))
        assertTrue(game.buyMineCart(1,id))
        assertTrue(game.improveDrill(1,id))
        assertTrue(game.improveMineCart(1,id))
        val mine=game.company(1).mines.getValue(id)
        assertEquals(2,game.mineFloor(1,id)!!.workers.size)
        assertEquals(2,game.mineFloor(1,id)!!.carts.size)
        assertFalse(game.deepenMine(1,id))
        game.mineFloor(1,id)!!.excavated=6
        assertTrue(game.deepenMine(1,id))
        assertEquals(2,MineWorld.interior(mine).activeFloor)
        assertTrue(game.selectMineFloor(1,id,1))
        val memory=ByteArrayOutputStream()
        ObjectOutputStream(memory).use{it.writeObject(game.state)}
        val copied=ObjectInputStream(ByteArrayInputStream(memory.toByteArray()))
            .use{it.readObject() as GameState}
        val restored=GameEngine(copied)
        assertEquals(2,MineWorld.interior(restored.company(1).mines.getValue(id)).unlockedFloor)
        assertEquals(2,restored.mineFloor(1,id)!!.workers.size)
    }

    @Test fun interpolatedPositionsMoveBetweenCellsWithoutTeleporting() {
        val track=MotionTrack(3f,2f,1000L)
        track.target(4f,2f,0L)
        assertEquals(3f,track.position(0L).x,0.001f)
        assertEquals(3.5f,track.position(500L).x,0.001f)
        assertEquals(4f,track.position(1000L).x,0.001f)
        assertFalse(track.animating(1000L))
        track.target(5f,2f,1100L)
        assertTrue(track.position(1500L).x>4f)
        // A new tick during walking continues from the previous visible point.
        val displayed=track.position(1600L).x
        track.target(6f,2f,1600L)
        assertEquals(displayed,track.position(1600L).x,0.001f)
        assertEquals(6f,track.position(2700L).x,0.001f)
    }

    @Test fun researchTreeContainsEightBranchesPerEraAndBonusesStack() {
        val game=GameEngine.newGame(2323L)
        assertEquals(80,ScienceTree.nodes.size)
        assertEquals(80,ScienceTree.nodes.map{it.id}.toSet().size)
        for(era in 1..10){
            assertEquals(8,ScienceTree.nodes.count{it.era==era})
        }
        game.state.science=99999
        assertFalse(game.research("automation_1"))
        assertTrue(game.research("mining_1"))
        assertTrue(game.research("transport_1"))
        assertTrue(game.research("geology_1"))
        assertTrue(game.research("metallurgy_1"))
        assertTrue(game.research("energy_1"))
        assertTrue(game.research("automation_1"))
        assertTrue(game.research("logistics_1"))
        assertTrue(game.research("science_1"))
        assertEquals(2,ScienceTree.drillBoost(game.state))
        assertEquals(2,ScienceTree.cartBoost(game.state))
        assertEquals(1,ScienceTree.geologyBoost(game.state))
        assertEquals(2,ScienceTree.productionBoost(game.state))
        assertEquals(1,ScienceTree.logisticsBoost(game.state))
        assertEquals(3,ScienceTree.contractScienceBoost(game.state))
    }

    @Test fun sequentialResearchAndEraGates() {
        val game=GameEngine.newGame(101L)
        game.state.science=15000
        assertFalse(game.buyEra())
        assertFalse(game.research("mining_2"))
        assertTrue(game.research("mining_1"))
        assertTrue(game.research("transport_1"))
        assertTrue(ScienceTree.cartBoost(game.state)>0)
        for (era in 1..9) {
            if(era>1) {
                assertTrue(game.research("mining_"+era))
                assertTrue(game.research("transport_"+era))
            }
            assertTrue(game.buyEra())
        }
        assertEquals(10,game.state.era)
        assertFalse(game.buyEra())
    }
    @Test fun continuousMovementDoesNotPauseAtIntermediateCell(){
        val track=Mine2MotionTrack(2f,4f,510L)
        track.target(3f,4f,1000L)
        val a=track.position(1125L).x
        val b=track.position(1250L).x
        val c=track.position(1375L).x
        assertTrue(a>2f)
        assertEquals(b-a,c-b,0.001f)
        val mid=track.position(1500L).x
        track.target(4f,4f,1500L)
        assertEquals(mid,track.position(1500L).x,0.001f)
        assertTrue(track.position(1600L).x>mid)
    }
    @Test fun expandedIndustrialRecipesAreCompleteAndMoreResourceIntensive(){
        val raw=Catalog.basicMinerals.map{it.id}.toSet()
        assertEquals(setOf("clay","sand","gravel","granite","salt","sulfur","shale"),raw)
        for(recipe in Catalog.recipes.values){
            assertTrue(recipe.output in Catalog.byId)
            assertTrue(recipe.ingredients.isNotEmpty())
            for(material in recipe.ingredients.keys)assertTrue(material in Catalog.byId)
        }
        assertTrue((Catalog.recipes["steel"]?.ingredients?.get("iron")?:0)>=3)
        assertTrue(Catalog.recipes.containsKey("construction_kit"))
        assertTrue(Catalog.recipes.containsKey("concrete"))
        val game=GameEngine.newGame(20261020L)
        val mine=game.city(1).lots.first{it.kind==BuildingKind.MINE}
        assertTrue(game.purchaseMine(1,mine.id))
        val ores=game.company(1).mines.getValue(mine.id).ores
        assertTrue(ores.any{it in raw})
    }

}
