package com.dailycorp.nativegame

import org.junit.Assert.*
import org.junit.Test

class StyleBOreMappingTest {
    @Test fun tinAndTitaniumUseDifferentAtlasKeysAndMineralFamilies(){
        assertEquals("ore_tin",MineBlockAtlas.textureForMaterial("ore_17_1"))
        assertEquals("ore_tin",MineBlockAtlas.textureForMaterial("ore_17_12"))
        assertEquals("ore_titanium",MineBlockAtlas.textureForMaterial("ore_6_1"))
        assertEquals("ore_titanium",MineBlockAtlas.textureForMaterial("ore_6_12"))
        assertNotEquals(MineBlockAtlas.textureForMaterial("ore_17_3"),
            MineBlockAtlas.textureForMaterial("ore_6_3"))
    }
}
