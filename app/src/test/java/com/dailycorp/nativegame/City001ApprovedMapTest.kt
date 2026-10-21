package com.dailycorp.nativegame

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class City001ApprovedMapTest {
    @Test fun newGamesHaveExactlyTheApprovedThirteenCity001Sites() {
        for (worldSeed in listOf(20261020L, 98761L, 123456789L)) {
            val cities = CityGenerator.makeCities(worldSeed)
            val city = cities.first()
            val counts = city.lots.groupingBy { it.kind }.eachCount()
            assertEquals(3, counts[BuildingKind.MINE])
            assertEquals(2, counts[BuildingKind.FACTORY])
            assertEquals(4, counts[BuildingKind.WAREHOUSE])
            assertEquals(1, counts[BuildingKind.RESEARCH])
            assertEquals(1, counts[BuildingKind.MUNICIPAL])
            assertEquals(1, counts[BuildingKind.ENERGY])
            assertEquals(1, counts[BuildingKind.MARKET])
            assertEquals(13, city.lots.size)
            val bound = ApprovedCity001Art.mappedSites(city)
            assertEquals(ApprovedCity001Art.siteCount(), bound.size)
            assertEquals(city.lots.map { it.id }.toSet(), bound.map { it.first.id }.toSet())
            for ((lot, spot) in bound) {
                assertEquals(lot.kind, spot.kind)
                assertTrue(spot.px in 0f..ApprovedCity001Art.WIDTH)
                assertTrue(spot.py in 0f..ApprovedCity001Art.HEIGHT)
            }
            // City records after the pilot still receive procedural terrain.
            assertEquals(48, cities.size)
            assertFalse(CityGenerator.plan(cities[1]).roads.isEmpty())
        }
    }

    @Test fun oldCityWithDifferentLotManifestDoesNotPretendToMatchPainting() {
        val original = CityGenerator.makeCities(20261020L).first()
        val incomplete = original.copy(lots = original.lots.dropLast(1))
        assertTrue(ApprovedCity001Art.mappedSites(incomplete).size < 13)
        // Rendering skips the painting when sites don't match; the old saved
        // economic coordinates are kept intact by City001Layout.
        assertEquals(incomplete.lots, City001Layout.plan(incomplete).lots)
    }

    @Test fun companyOwnedStatusUsesSavedLotIds() {
        val game = GameEngine.newGame()
        val city = game.city(1)
        val company = game.company(1)
        val ownedWarehouse = city.lots.first { it.kind == BuildingKind.WAREHOUSE }
        assertTrue(ownedWarehouse.id in company.warehouses)
        assertTrue(ApprovedCity001Art.mappedSites(city).any {
            it.first.id == ownedWarehouse.id && it.second.kind == BuildingKind.WAREHOUSE
        })
    }
}
