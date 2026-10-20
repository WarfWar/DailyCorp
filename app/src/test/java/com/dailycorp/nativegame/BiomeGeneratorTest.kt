package com.dailycorp.nativegame

import org.junit.Assert.*
import org.junit.Test

/** Biome generation must be reproducible, locally connected and economy-safe. */
class BiomeGeneratorTest {
    @Test fun worldIsPersistentAndHasActualCoasts() {
        val seed=20261020L
        val samples=(0 until 72).flatMap { y ->
            (0 until 96).map { x -> BiomeGenerator.world(seed,x,y) }
        }
        assertTrue(samples.count { it==Biome.OCEAN }>150)
        assertTrue(samples.count { it!=Biome.OCEAN }>500)
        assertTrue(samples.contains(Biome.COAST))
        assertTrue(samples.toSet().size>=4)
        assertEquals(BiomeGenerator.world(seed,48,35),
            BiomeGenerator.world(seed,48,35))
    }
    @Test fun adjacentTilesPreferCoherentBiomesRatherThanNoise() {
        val seed=1234321L
        var same=0;var comparisons=0
        for(y in 5..56)for(x in 5..82){
            val cur=BiomeGenerator.world(seed,x,y)
            val next=BiomeGenerator.world(seed,x+1,y)
            same+=if(cur==next)1 else 0
            comparisons++
        }
        assertTrue("World must have large continuous regions",same>comparisons*0.66)
        for(citySeed in listOf(13L,222L,131221L,20261020L)){
            var neighbors=0;var equal=0
            for(y in 0 until 34)for(x in 0 until 35){
                neighbors++
                if(BiomeGenerator.city(citySeed,x,y)==
                    BiomeGenerator.city(citySeed,x+1,y))equal++
            }
            assertTrue("City biome fields should be locally coherent",
                equal>neighbors*0.60)
        }
    }
    @Test fun cityPlansStillKeepAllOriginalRoadsAndLots() {
        val game=GameEngine.newGame(20261020L)
        for(city in game.state.cities){
            val plan=CityGenerator.plan(city)
            assertEquals(city.lots,plan.lots)
            for(lot in city.lots){
                assertFalse(lot.pos in plan.roads)
                assertTrue(lot.gate in plan.roads)
            }
        }
    }
}
