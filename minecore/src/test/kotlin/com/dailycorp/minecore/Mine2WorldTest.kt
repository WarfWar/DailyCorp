package com.dailycorp.minecore

import org.junit.Assert.*
import org.junit.Test
import java.io.*

class Mine2WorldTest {
    private val config=Mine2Config(seed=444L,width=40,depthCells=144)
    @Test fun deterministicGeologyAndSeamlessChunks(){
        val a=Mine2World.create(config)
        val b=Mine2World.create(config)
        for(y in 0 until 144)for(x in 0 until 40){
            val c=a.cell(x,y)!!
            val d=b.cell(x,y)!!
            assertEquals(c.kind,d.kind)
            assertEquals(c.resource,d.resource)
            assertEquals(c.grade,d.grade)
        }
        val adjacent=a.cell(17,23)!!
        val next=a.cell(17,24)!!
        assertNotNull(adjacent)
        assertNotNull(next)
        assertEquals(RockKind.BEDROCK,a.cell(0,80)!!.kind)
        assertEquals(RockKind.BEDROCK,a.cell(10,143)!!.kind)
    }
    @Test fun onlyExploredCellsMayBeMarkedAndFrontiersMustConnect(){
        val world=Mine2World.create(config)
        assertFalse(world.cell(9,70)!!.explored)
        assertEquals(0,world.orderArea(CellPos(9,70),CellPos(12,73)))
        val entry=config.width/2
        val before=world.cell(entry+1,4)!!
        assertTrue(before.explored)
        assertEquals(1,world.orderArea(CellPos(entry+1,4),CellPos(entry+1,4)))
        val left=world.pendingCount()
        assertEquals(1,left)
        repeat(30){world.step()}
        assertEquals(RockKind.TUNNEL,world.cell(entry+1,4)!!.kind)
        assertEquals(0,world.pendingCount())
        assertTrue(world.totalExcavated>=1)
    }
    @Test fun surveyConsumesLimitedChargesAndRequiresAReachableKnownArea(){
        val world=Mine2World.create(config)
        assertEquals(0,world.survey(3,125))
        assertEquals(4,world.surveysLeft)
        assertTrue(world.survey(config.width/2+5,8)>0)
        assertEquals(3,world.surveysLeft)
    }
    @Test fun saveRestoresOrdersExcavationsAndLocalStockpile(){
        val world=Mine2World.create(config)
        val x=config.width/2+1
        world.orderArea(CellPos(x,4),CellPos(x,4))
        repeat(35){world.step()}
        val raw=ByteArrayOutputStream()
        ObjectOutputStream(raw).use{it.writeObject(world)}
        val restored=ObjectInputStream(ByteArrayInputStream(raw.toByteArray()))
            .use{it.readObject() as Mine2World}
        assertEquals(world.config,restored.config)
        assertEquals(world.totalExcavated,restored.totalExcavated)
        assertEquals(world.stockpile,restored.stockpile)
        assertEquals(world.cell(x,4)!!.kind,restored.cell(x,4)!!.kind)
    }
    @Test fun rectangularPlansAreBoundedAndCancelable(){
        val world=Mine2World.create(config)
        assertEquals(0,world.orderArea(CellPos(1,3),CellPos(39,31)))
        val entry=config.width/2
        val queued=world.orderArea(CellPos(entry-5,4),CellPos(entry+5,8))
        assertTrue(queued>0)
        assertEquals(queued,world.cancelOrders())
        assertEquals(0,world.pendingCount())
    }
}
