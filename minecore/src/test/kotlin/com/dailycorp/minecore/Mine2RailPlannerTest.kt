package com.dailycorp.minecore

import org.junit.Assert.*
import org.junit.Test
import java.io.*

class Mine2RailPlannerTest {
    private fun world()=Mine2World.create(Mine2Config(9982L,40,144))
    private fun corridor(w:Mine2World,from:Int,to:Int,y:Int=3){
        for(x in from..to){
            w.cell(x,y)!!.apply {kind=RockKind.TUNNEL;explored=true}
        }
    }
    @Test fun quoteUsesOnlyDiscoveredWalkableCellsAndRejectsNoOp(){
        val w=world()
        val t=w.transport()
        val center=w.config.width/2
        val end=CellPos(center+7,3)
        assertFalse(t.quoteRailProject(w,end).valid)
        corridor(w,center+5,center+7)
        val quote=t.quoteRailProject(w,end)
        assertTrue(quote.reason,quote.valid)
        assertEquals(listOf(CellPos(center+5,3),CellPos(center+6,3),end),quote.path)
        assertEquals(180L,quote.price)
        assertFalse(t.quoteRailProject(w,CellPos(center+4,3)).valid)
        assertTrue(t.startRailProject(w,quote))
        assertFalse(t.quoteRailProject(w,CellPos(center+9,3)).valid)
        assertEquals(0,t.totalRailBuilt)
        w.step()
        assertTrue(t.railAt(CellPos(center+5,3)))
        assertFalse(t.railAt(CellPos(center+6,3)))
        repeat(2){w.step()}
        assertTrue(t.railAt(end))
        assertEquals(3,t.totalRailBuilt)
        assertEquals(0,t.railProjects().single().remaining)
    }
    @Test fun hiddenOrBlockedCorridorNeverGetsRailFree(){
        val w=world();val t=w.transport()
        val center=w.config.width/2
        corridor(w,center+5,center+7)
        w.cell(center+6,3)!!.explored=false
        assertFalse(t.quoteRailProject(w,CellPos(center+7,3)).valid)
        w.cell(center+6,3)!!.explored=true
        w.cell(center+6,3)!!.kind=RockKind.ORE
        assertFalse(t.quoteRailProject(w,CellPos(center+7,3)).valid)
    }
    @Test fun quotedPriceIncludesDynamicPerSegmentRailCost(){
        val w=world();val t=w.transport()
        val center=w.config.width/2
        corridor(w,center+5,center+18)
        val q=t.quoteRailProject(w,CellPos(center+18,3))
        assertTrue(q.valid)
        assertEquals(14,q.path.size)
        assertEquals(14*60L+2*10L,q.price)
    }
    @Test fun pendingProjectSurvivesJavaSerialization(){
        val w=world();val t=w.transport()
        val center=w.config.width/2
        corridor(w,center+5,center+8)
        val q=t.quoteRailProject(w,CellPos(center+8,3))
        assertTrue(t.startRailProject(w,q))
        w.step()
        val data=ByteArrayOutputStream()
        ObjectOutputStream(data).use{it.writeObject(w)}
        val copy=ObjectInputStream(ByteArrayInputStream(data.toByteArray()))
            .use{it.readObject() as Mine2World}
        assertEquals(1,copy.transport().railProjects().single().nextIndex)
        repeat(3){copy.step()}
        assertTrue(copy.transport().railAt(CellPos(center+8,3)))
        assertEquals(q.price,copy.transport().railProjects().single().paid)
    }
}
