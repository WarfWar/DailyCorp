package com.dailycorp.nativegame

import org.junit.Assert.*
import org.junit.Test

class TinTitaniumSpriteMappingTest {
    @Test fun tinAndTitaniumHaveDistinctKeysForAllResourceGrades(){
        for(grade in 1..12){
            val tin=MineBlockAtlas.textureForMaterial("ore_17_"+grade)
            val titanium=MineBlockAtlas.textureForMaterial("ore_6_"+grade)
            assertEquals("ore_tin",tin)
            assertEquals("ore_titanium",titanium)
            assertNotEquals(tin,titanium)
        }
        assertEquals("ore_tin",MineBlockAtlas.textureForMaterial("tin"))
        assertEquals("ore_titanium",MineBlockAtlas.textureForMaterial("titanium"))
    }
}
