package com.dailycorp.nativegame

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class City001RoadNetworkRegressionTest {
    @Test fun connectedPilotRoadsAcrossMultipleWorldSeeds() {
        for (seed in listOf(20261020L, 98761L, 123456789L, 517102L)) {
            val city = CityGenerator.makeCities(seed).first()
            val base = CityGenerator.plan(city)
            val layout = City001Layout.plan(city)
            assertTrue(layout.roads.containsAll(base.roads))
            val visited = mutableSetOf<Point>()
            val queue = ArrayDeque<Point>()
            val origin = base.roads.first()
            visited.add(origin)
            queue.add(origin)
            while (queue.isNotEmpty()) {
                val p = queue.removeFirst()
                for (next in listOf(Point(p.x+1,p.y),Point(p.x-1,p.y),
                    Point(p.x,p.y+1),Point(p.x,p.y-1))) {
                    if (next in layout.roads && visited.add(next)) queue.add(next)
                }
            }
            assertEquals("Disconnected streets for seed $seed", layout.roads.size, visited.size)
            assertEquals(city.lots, layout.lots)
            for (lot in city.lots) {
                assertTrue("Lost road gate in seed $seed", lot.gate in layout.roads)
            }
        }
    }
}
