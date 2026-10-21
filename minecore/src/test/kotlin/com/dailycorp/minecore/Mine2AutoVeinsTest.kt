package com.dailycorp.minecore

import org.junit.Assert.*
import org.junit.Test
import java.io.*

class Mine2AutoVeinsTest {
    private data class PairOfOre(val a:CellPos,val b:CellPos)
    private fun adjacentOre(w:Mine2World):PairOfOre {
        for(y in 5 until 70) for(x in 2 until w.config.width-4) {
            val a=w.cell(x,y)!!
            val b=w.cell(x+1,y)!!
            if(a.kind==RockKind.ORE && b.kind==RockKind.ORE &&
                a.resource!=null && b.resource!=null &&
                Mine2VeinAutomation.family(a.resource!!)==
                    Mine2VeinAutomation.family(b.resource!!))
                return PairOfOre(CellPos(x,y),CellPos(x+1,y))
        }
        error("Expected a connected ore pair in deterministic geology")
    }
    private fun world()=Mine2World.create(Mine2Config(444L,40,144))

    @Test fun oneTapQueuesConnectedVisibleOreAndTappingAgainCancelsTheWholePlan(){
        val w=world()
        val (a,b)=adjacentOre(w)
        w.cell(a.x,a.y)!!.explored=true
        w.cell(b.x,b.y)!!.explored=true
        assertTrue(w.autoVeinEnabled)
        assertTrue(w.toggleVeinOrder(a))
        assertTrue(w.cell(a.x,a.y)!!.ordered)
        assertTrue(w.cell(b.x,b.y)!!.ordered)
        assertEquals(1,w.activeVeinPlans())
        assertFalse(w.toggleVeinOrder(a))
        assertFalse(w.cell(a.x,a.y)!!.ordered)
        assertFalse(w.cell(b.x,b.y)!!.ordered)
        assertEquals(0,w.activeVeinPlans())
    }

    @Test fun hiddenOreIsNotClaimedUntilDiscoveredThenExpandsPlan(){
        val w=world()
        val (a,b)=adjacentOre(w)
        w.cell(a.x,a.y)!!.explored=true
        w.cell(b.x,b.y)!!.explored=false
        assertTrue(w.toggleVeinOrder(a))
        assertFalse("Undiscovered ore must not be auto-ordered",w.cell(b.x,b.y)!!.ordered)
        w.reveal(b.x,b.y,0)
        assertTrue(w.cell(b.x,b.y)!!.ordered)
        assertEquals(1,w.activeVeinPlans())
        assertTrue(w.cancelOrders()>=2)
        assertEquals(0,w.activeVeinPlans())
    }

    @Test fun disablingAutoVeinStopsPlansButManualOrdersStillWork(){
        val w=world()
        val (a,b)=adjacentOre(w)
        w.cell(a.x,a.y)!!.explored=true
        w.cell(b.x,b.y)!!.explored=true
        assertTrue(w.toggleVeinOrder(a))
        w.setAutoVeinEnabled(false)
        assertFalse(w.autoVeinEnabled)
        assertEquals(0,w.activeVeinPlans())
        assertFalse(w.cell(b.x,b.y)!!.ordered)
        assertTrue(w.toggleVeinOrder(a))
        assertFalse(w.cell(b.x,b.y)!!.ordered)
        assertFalse(w.toggleVeinOrder(a))
        w.setAutoVeinEnabled(true)
        assertTrue(w.autoVeinEnabled)
    }

    @Test fun oreGradeIsNotASeparateSpeciesAndNonOreTypesDoNotMerge(){
        assertEquals("ore_7",Mine2VeinAutomation.family("ore_7_1"))
        assertEquals("ore_7",Mine2VeinAutomation.family("ore_7_12"))
        assertNotEquals(Mine2VeinAutomation.family("ore_7_12"),
            Mine2VeinAutomation.family("ore_8_12"))
        assertNotEquals("ore_7",Mine2VeinAutomation.family("coal"))
        assertEquals("salt",Mine2VeinAutomation.family("salt"))
    }

    @Test fun unfinishedAutoPlanAndPreferenceSurviveExistingJavaSaveFormat(){
        val w=world()
        val (a,b)=adjacentOre(w)
        w.cell(a.x,a.y)!!.explored=true
        w.cell(b.x,b.y)!!.explored=false
        assertTrue(w.toggleVeinOrder(a))
        val bytes=ByteArrayOutputStream()
        ObjectOutputStream(bytes).use{it.writeObject(w)}
        val loaded=ObjectInputStream(ByteArrayInputStream(bytes.toByteArray()))
            .use{it.readObject() as Mine2World}
        assertTrue(loaded.autoVeinEnabled)
        assertEquals(1,loaded.activeVeinPlans())
        loaded.reveal(b.x,b.y,0)
        assertTrue(loaded.cell(b.x,b.y)!!.ordered)
        loaded.setAutoVeinEnabled(false)
        val again=ByteArrayOutputStream()
        ObjectOutputStream(again).use{it.writeObject(loaded)}
        val restored=ObjectInputStream(ByteArrayInputStream(again.toByteArray()))
            .use{it.readObject() as Mine2World}
        assertFalse(restored.autoVeinEnabled)
        assertEquals(0,restored.activeVeinPlans())
    }
}
