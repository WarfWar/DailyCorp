package com.dailycorp.minecore

import org.junit.Assert.*
import org.junit.Test
import java.io.*

class Mine2LiftSystemTest {
    private fun world()=Mine2World.create(Mine2Config(228811L,40,144))

    @Test fun quotesAndConstructionPreserveSaveState(){
        val w=world()
        val t=w.transport()
        val x=w.config.width/2+3
        assertFalse(t.quoteLift(w,x,7).valid)
        assertFalse(t.quoteLift(w,x+7,30).valid)
        val q=t.quoteLift(w,x,28)
        assertTrue(q.reason,q.valid)
        assertTrue(t.startLift(w,q))
        assertFalse(t.quoteLift(w,x,28).valid)
        repeat(5){w.step()}
        assertEquals(7,t.lifts().single().builtToY)
        val bytes=ByteArrayOutputStream()
        ObjectOutputStream(bytes).use{it.writeObject(w)}
        val copy=ObjectInputStream(ByteArrayInputStream(bytes.toByteArray())).use{
            it.readObject() as Mine2World
        }
        assertEquals(7,copy.transport().lifts().single().builtToY)
        repeat(21){copy.step()}
        assertTrue(copy.transport().lifts().single().completed)
        assertTrue(copy.transport().railAt(CellPos(x,28)))
    }
    @Test fun deepOreOnlyCreditsAfterWagonAndLiftReturn(){
        val w=world()
        val t=w.transport()
        val x=w.config.width/2+3
        assertTrue(t.startLift(w,t.quoteLift(w,x,28)))
        repeat(26){w.step()}
        val station=CellPos(x,28)
        val work=CellPos(x+1,28)
        w.cell(work.x,work.y)!!.apply{
            kind=RockKind.TUNNEL;explored=true
        }
        assertTrue(t.buildRail(w,work))
        assertTrue(t.hireCart(station))
        w.stockpile["iron"]=9
        t.addPile(work,"iron",9)
        repeat(4){w.step()}
        assertEquals(0,t.delivered.values.sum())
        repeat(280){w.step()}
        assertEquals(9,t.delivered["iron"])
        assertEquals(0,w.stockpile["iron"])
        assertEquals(9,t.lifts().single().totalDelivered)
    }

}
