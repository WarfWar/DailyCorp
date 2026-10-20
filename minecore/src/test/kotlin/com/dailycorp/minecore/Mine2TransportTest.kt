package com.dailycorp.minecore

import org.junit.Assert.*
import org.junit.Test
import java.io.*

class Mine2TransportTest {
    private fun world()=Mine2World.create(
        Mine2Config(seed=77224L,width=40,depthCells=144)
    )
    @Test fun railsConnectOnlyToExistingTrackAndExcavatedCells(){
        val world=world()
        val depot=CellPos(world.config.width/2,3)
        val transport=world.transport()
        assertTrue(transport.railAt(depot))
        val first=CellPos(depot.x+5,3)
        val second=CellPos(depot.x+6,3)
        assertFalse(transport.canBuildRail(world,first)) // not excavated yet
        for(p in listOf(first,second)){
            val c=world.cell(p.x,p.y)!!
            c.kind=RockKind.TUNNEL
            c.explored=true
        }
        assertFalse(transport.canBuildRail(world,second))
        assertTrue(transport.canBuildRail(world,first))
        assertTrue(transport.buildRail(world,first))
        assertFalse(transport.buildRail(world,first))
        assertTrue(transport.canBuildRail(world,second))
        assertTrue(transport.buildRail(world,second))
    }
    @Test fun cartHaulsAllOreInCapacityLimitedTripsWithoutPausingOrTeleporting(){
        val world=world()
        val t=world.transport()
        val depot=CellPos(world.config.width/2,3)
        val work=CellPos(depot.x+5,3)
        world.cell(work.x,work.y)!!.apply{
            kind=RockKind.TUNNEL; explored=true
        }
        assertTrue(t.buildRail(world,work))
        assertTrue(t.hireCart())
        val cart=t.carts.single()
        val amount=13
        world.stockpile["iron"]=amount
        t.addPile(work,"iron",amount)
        var previous=CellPos(cart.x,cart.y)
        var deliveries=0
        var firstDeliveryAt=-1
        for(tick in 1..80){
            val outcome=t.step(world)
            deliveries+=outcome.sumOf{it.amount}
            val current=CellPos(cart.x,cart.y)
            val travel=kotlin.math.abs(current.x-previous.x)+
                kotlin.math.abs(current.y-previous.y)
            assertTrue("Cart moved more than one cell in a tick",travel<=1)
            if(firstDeliveryAt<0 && deliveries>0)firstDeliveryAt=tick
            if(tick<=5)assertEquals("Cart must move every tick along the rails",
                depot.x+tick,cart.x)
            previous=current
        }
        assertTrue(firstDeliveryAt>=12)
        assertEquals(amount,deliveries)
        assertEquals(amount,t.delivered["iron"])
        assertEquals(0,world.stockpile["iron"])
        assertTrue(t.piles.isEmpty())
        assertTrue(t.carts.single().amount==0)
    }
    @Test fun disconnectedWorksiteCannotBeHauledWithoutRails(){
        val world=world()
        val t=world.transport()
        assertTrue(t.hireCart())
        val at=CellPos(world.config.width/2+7,3)
        world.stockpile["copper"]=4
        t.addPile(at,"copper",4)
        repeat(30){assertTrue(t.step(world).isEmpty())}
        assertEquals(4,world.stockpile["copper"])
        assertTrue(t.delivered.isEmpty())
        assertEquals(4,t.piles.getValue(at).getValue("copper"))
    }
    @Test fun oldMiningStockpileBecomesStagedCargoButNotFreeDelivery(){
        val world=world()
        world.stockpile["gold"]=3
        val t=world.transport()
        assertEquals(3,t.piles.getValue(CellPos(world.config.width/2,3))["gold"])
        assertEquals(null,t.delivered["gold"])
        assertTrue(t.hireCart())
        assertTrue(t.step(world).isEmpty()) // load, not delivery
        assertEquals(3,world.stockpile["gold"])
        val unloaded=t.step(world)
        assertEquals(3,unloaded.single().amount)
        assertEquals(0,world.stockpile["gold"])
        assertEquals(3,t.delivered["gold"])
    }
    @Test fun railNetworkCartsCargoAndDeliveryLedgerPersistAcrossSave(){
        val world=world()
        val t=world.transport()
        assertTrue(t.hireCart())
        val pos=CellPos(world.config.width/2,4)
        world.stockpile["salt"]=8
        t.addPile(pos,"salt",8)
        repeat(5){t.step(world)}
        val bytes=ByteArrayOutputStream()
        ObjectOutputStream(bytes).use{it.writeObject(world)}
        val copy=ObjectInputStream(ByteArrayInputStream(bytes.toByteArray())).use{
            it.readObject() as Mine2World
        }
        assertEquals(t.rails,copy.transport().rails)
        assertEquals(t.delivered,copy.transport().delivered)
        assertEquals(t.carts.single().amount,copy.transport().carts.single().amount)
        repeat(20){copy.step()}
        assertEquals(8,copy.transport().delivered["salt"])
    }
}
