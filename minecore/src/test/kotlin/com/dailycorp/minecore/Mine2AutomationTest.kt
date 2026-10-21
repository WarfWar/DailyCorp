package com.dailycorp.minecore

import org.junit.Assert.*
import org.junit.Test
import java.io.*

class Mine2AutomationTest {
    private fun world()=Mine2World.create(Mine2Config(71224L,40,144))
    @Test fun dispatcherBalancesTwoNearbyStockpiles() {
        val world=world()
        val t=world.transport()
        val depot=world.config.width/2
        val left=CellPos(depot-3,3)
        val right=CellPos(depot+3,3)
        world.stockpile["iron"]=20
        t.addPile(left,"iron",10)
        t.addPile(right,"iron",10)
        assertTrue(t.hireCart())
        assertTrue(t.hireCart())
        t.step(world)
        val x=t.carts.map{it.x}.toSet()
        assertTrue("Two wagons should spread between available work sites",
            depot-1 in x && depot+1 in x)
        repeat(50){t.step(world)}
        assertEquals(20,t.delivered["iron"])
        assertEquals(0,world.stockpile["iron"])
        assertTrue(t.cartTravelStepsV4>0L)
        assertTrue(t.loadedTripsV4>=4)
    }
    @Test fun liftImprovementUnloadsMoreWagonsPerTick() {
        val world=world()
        val t=world.transport()
        repeat(3){assertTrue(t.hireCart())}
        world.stockpile["coal"]=15
        t.carts.forEach { it.material="coal";it.amount=5 }
        assertEquals(1,t.liftCapacity())
        val first=t.step(world)
        assertEquals(1,first.size)
        assertEquals(5,t.delivered["coal"])
        assertEquals(1L,t.liftCongestionTicksV4)
        assertEquals(1200L,t.liftUpgradeCost())
        assertTrue(t.upgradeLift())
        assertEquals(2,t.liftCapacity())
        val second=t.step(world)
        assertEquals(2,second.size)
        assertEquals(15,t.delivered["coal"])
        assertEquals(0,world.stockpile["coal"])
        assertTrue(t.carts.none{it.amount>0})
    }
    @Test fun disconnectedRailsCountStalledTimeWithoutInventingDeliveries() {
        val world=world()
        val t=world.transport()
        assertTrue(t.hireCart())
        world.stockpile["gold"]=4
        t.addPile(CellPos(world.config.width/2+8,3),"gold",4)
        repeat(8){assertTrue(t.step(world).isEmpty())}
        assertEquals(8L,t.idleWithoutRailV4)
        assertEquals(4,world.stockpile["gold"])
        assertTrue(t.delivered.isEmpty())
    }
    @Test fun liftLevelsAndDeliveryStatisticsSurviveSerialisation() {
        val w=world()
        val t=w.transport()
        assertTrue(t.upgradeLift())
        assertTrue(t.hireCart())
        val buf=ByteArrayOutputStream()
        ObjectOutputStream(buf).use{it.writeObject(w)}
        val read=ObjectInputStream(ByteArrayInputStream(buf.toByteArray())).use{
            it.readObject() as Mine2World
        }
        assertEquals(2,read.transport().liftLevel)
        assertEquals(2,read.transport().liftCapacity())
        assertEquals(1,read.transport().carts.size)
        assertEquals(w.config,read.config)
    }
    @Test fun miningRateIsBoundedByLatest120Ticks() {
        val w=world()
        assertEquals(0,w.orePerMinute())
        val p=CellPos(w.config.width/2+1,5)
        w.cell(p.x,p.y)!!.apply{
            explored=true
            kind=RockKind.ORE
            deposit=20
            hardness=1
        }
        assertTrue(w.toggleCellOrder(p))
        repeat(30){w.step()}
        assertTrue(w.orePerMinute()>0)
        assertTrue(w.orePerMinute()<=20)
        w.cancelOrders()
        repeat(125){w.step()}
        assertEquals(0,w.orePerMinute())
    }
}
