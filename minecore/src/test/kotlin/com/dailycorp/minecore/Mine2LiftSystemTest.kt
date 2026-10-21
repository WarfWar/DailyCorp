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
}
