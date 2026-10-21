package com.dailycorp.nativegame

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class City001LayoutTest {
    private val city = CityGenerator.makeCities(20261020L).first()

    @Test fun pilotKeepsEconomicLotIdsAndSavedCoordinates() {
        val plan = City001Layout.plan(city)
        val base = CityGenerator.plan(city)
        assertEquals(36, plan.width)
        assertEquals(34, plan.height)
        assertEquals(city.lots, plan.lots)
        assertTrue(plan.roads.containsAll(base.roads))
        for (lot in city.lots) {
            assertFalse("City 001 road crossed lot ${lot.id}", lot.pos in plan.roads)
            assertTrue("Lot ${lot.id} lost its road gate", lot.gate in plan.roads)
        }
        assertTrue("City ring should change the map", plan.roads.size > base.roads.size)
    }

    @Test fun pilotIsDeterministicAndDoesNotPlaceSceneryOnGameplaySites() {
        val plan = City001Layout.plan(city)
        assertEquals(plan, City001Layout.plan(city))
        val decorations = City001Layout.decorations(plan, city.seed)
        assertEquals(decorations, City001Layout.decorations(plan, city.seed))
        assertTrue("Pilot needs visible landscaping", decorations.isNotEmpty())
        for (prop in decorations) {
            assertFalse(prop.at in plan.roads)
            assertFalse(prop.at in plan.homes)
            assertFalse(city.lots.any { it.pos == prop.at })
            assertTrue(prop.sprite.startsWith("infra.") || prop.sprite.startsWith("buildings."))
        }
    }

    @Test fun otherCitiesStillUseOriginalGenerator() {
        val secondCity = CityGenerator.makeCities(20261020L)[1]
        val oldPlan = CityGenerator.plan(secondCity)
        assertEquals(secondCity.lots, oldPlan.lots)
        assertFalse(oldPlan.roads.isEmpty())
    }
}
