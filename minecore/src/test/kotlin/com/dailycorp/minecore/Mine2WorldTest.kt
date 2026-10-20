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
    @Test fun surveyingCostsMoneyWithoutBillingFailuresOrRepeats(){
        val world=Mine2World.create(config)
        val invalid=world.surveyPaid(3,125,999999L)
        assertFalse(invalid.successful)
        assertEquals(0L,invalid.charged)
        assertEquals(0,world.surveysPerformed)
        val x=config.width/2+5
        val y=8
        val quote=world.surveyQuote(x,y)
        assertTrue(quote.valid)
        assertTrue(quote.price>=250L)
        assertFalse(world.surveyPaid(x,y,quote.price-1).successful)
        assertEquals(0,world.surveysPerformed)
        val paid=world.surveyPaid(x,y,quote.price)
        assertTrue(paid.successful)
        assertEquals(quote.price,paid.charged)
        assertTrue(paid.cellsRevealed>0)
        assertEquals(1,world.surveysPerformed)
        val duplicate=world.surveyPaid(x,y,100000L)
        assertFalse(duplicate.successful)
        assertEquals(0L,duplicate.charged)
        assertEquals(1,world.surveysPerformed)
        val next=world.surveyQuote(x+4,y+2)
        assertTrue(next.valid)
        assertTrue(next.price>quote.price)
    }
    @Test fun minersTravelOpenCorridorsRatherThanTeleportThroughRock(){
        val world=Mine2World.create(config)
        val center=config.width/2
        val target=CellPos(center+4,4)
        assertEquals(1,world.orderArea(target,target))
        val first=world.step()
        assertEquals(1,first.minersMoved)
        assertEquals(center+1,world.miners().first().x)
        assertEquals(0,world.totalExcavated)
        repeat(35){world.step()}
        assertEquals(RockKind.TUNNEL,world.cell(target.x,target.y)!!.kind)
        assertTrue(world.totalExcavated>=1)
        assertTrue(world.hireMiner())
        assertEquals(2,world.miners().size)
    }
    @Test fun paidSurveysAndMinersSurviveSaveReload(){
        val world=Mine2World.create(config)
        assertTrue(world.surveyPaid(config.width/2+5,8,10000L).successful)
        assertTrue(world.hireMiner())
        val expectedPrice=world.surveyQuote(config.width/2+9,10).price
        val bytes=ByteArrayOutputStream()
        ObjectOutputStream(bytes).use{it.writeObject(world)}
        val loaded=ObjectInputStream(ByteArrayInputStream(bytes.toByteArray()))
            .use{it.readObject() as Mine2World}
        assertEquals(1,loaded.surveysPerformed)
        assertEquals(2,loaded.miners().size)
        assertEquals(expectedPrice,loaded.surveyQuote(config.width/2+9,10).price)
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
    @Test fun oreVeinsKeepConnectedShapesButIndividualCellQuantitiesDiffer(){
        val generated=Mine2World.create(Mine2Config(983311L,40,168))
        val kinds=mutableMapOf<String,MutableSet<Int>>()
        for(y in 5 until 160)for(x in 1..38){
            val c=generated.cell(x,y)!!
            if(c.resource!=null && c.kind==RockKind.ORE)
                kinds.getOrPut(c.resource!!){mutableSetOf()}.add(c.deposit)
        }
        assertTrue("Each deposit must vary, even within a vein",
            kinds.values.any { it.size>=4 })
        assertTrue("Geology must contain different raw materials",kinds.size>=4)
        assertTrue(kinds.values.flatten().all {it>0})
        val replay=Mine2World.create(Mine2Config(983311L,40,168))
        for(y in 0 until 168)for(x in 0 until 40)
            assertEquals(generated.cell(x,y)!!.deposit,replay.cell(x,y)!!.deposit)
    }
    @Test fun enlargedSurveyCreatesDarkenedPartiallyExploredRegion(){
        val world=Mine2World.create(config)
        val x=config.width/2+6
        val y=8
        val offer=world.surveyQuote(x,y)
        assertTrue(offer.valid)
        assertTrue("Larger radius should reveal substantial area",offer.newCells>45)
        assertEquals(450L+(y*5/25)*20L,offer.price)
        val scan=world.surveyPaid(x,y,offer.price)
        assertTrue(scan.successful)
        assertTrue(world.isSurveyDim(x+7,y))
        world.reveal(x+7,y,2)
        assertFalse(world.isSurveyDim(x+7,y))
        assertFalse(world.surveyPaid(x,y,999999L).successful)
    }
    @Test fun oreYieldsOneUnitPerCompletedCycleAndKeepsOrderUntilEmpty(){
        var world:Mine2World?=null
        val x=config.width/2+1
        // Topmost ore eligible for mining immediately beside the shaft.
        for(seed in 1L..300L) {
            val candidate=Mine2World.create(config.copy(seed=seed))
            if(candidate.cell(x,5)?.kind==RockKind.ORE){
                world=candidate;break
            }
        }
        val mine=world?:error("Expected to discover at least one ore node")
        val target=CellPos(x,5)
        val initial=mine.cell(x,5)!!.deposit
        assertTrue("Ore node should contain multiple units",initial>1)
        assertTrue(mine.toggleCellOrder(target))
        assertTrue(mine.cell(x,5)!!.ordered)
        var gathered=0
        for(i in 0 until 1200) {
            val previous=mine.stockpile.values.sum()
            mine.step(drillPower=2)
            val delta=mine.stockpile.values.sum()-previous
            assertTrue("No tick can pull the entire ore vein at once",delta in 0..1)
            gathered+=delta
            if(gathered==1){
                assertEquals(initial-1,mine.cell(x,5)!!.deposit)
                assertEquals(RockKind.ORE,mine.cell(x,5)!!.kind)
                assertTrue(mine.cell(x,5)!!.ordered)
                break
            }
        }
        assertEquals(1,gathered)
        var ticks=0
        while(mine.cell(x,5)!!.kind==RockKind.ORE && ticks++<1200)
            mine.step(drillPower=2)
        assertEquals(RockKind.TUNNEL,mine.cell(x,5)!!.kind)
        assertEquals(initial,mine.stockpile.values.sum())
        assertFalse(mine.cell(x,5)!!.ordered)
    }
    @Test fun selectingOneCellCanAlsoCancelItsExistingDigOrder(){
        val world=Mine2World.create(config)
        val p=CellPos(config.width/2+1,4)
        assertTrue(world.toggleCellOrder(p))
        assertEquals(1,world.pendingCount())
        assertFalse(world.toggleCellOrder(p))
        assertEquals(0,world.pendingCount())
        assertFalse(world.toggleCellOrder(CellPos(0,4)))
    }
    @Test fun upgradingMineRaisesLimitAndSurvivesSave(){
        val world=Mine2World.create(config)
        assertEquals(8,world.crewLimit)
        assertEquals(1,world.shaftLevel)
        assertEquals(1300L,world.upgradePrice())
        repeat(7){assertTrue(world.hireMiner())}
        assertFalse(world.hireMiner())
        assertTrue(world.upgradeShaft())
        assertEquals(12,world.crewLimit)
        repeat(4){assertTrue(world.hireMiner())}
        assertFalse(world.hireMiner())
        val output=ByteArrayOutputStream()
        ObjectOutputStream(output).use{it.writeObject(world)}
        val restored=ObjectInputStream(ByteArrayInputStream(output.toByteArray()))
            .use{it.readObject() as Mine2World}
        assertEquals(12,restored.crewLimit)
        assertEquals(12,restored.miners().size)
    }

}
