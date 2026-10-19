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

    @Test fun sequentialResearchAndEraGates() {
        val game=GameEngine.newGame(101L)
        game.state.science=15000
        assertFalse(game.buyEra())
        assertFalse(game.research("mining_2"))
        assertTrue(game.research("mining_1"))
        assertTrue(game.research("transport_1"))
        assertTrue(ScienceTree.cartBoost(game.state))
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
}
