package com.dailycorp.nativegame

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Base64
import java.util.zip.GZIPInputStream

/** Confirms Terrain v3 is a real, loadable GLB and retains all 13 save IDs. */
class City001TerrainV3Test {
    @Test fun genuineV3TerrainAndThirteenIndependentSites() {
        val source = File("src/main/assets/dailycorp/3d/city001_terrain_v3.glb.gz.b64")
        assertTrue(source.exists())
        val packed = Base64.getMimeDecoder().decode(source.readText().trim())
        val binary = GZIPInputStream(ByteArrayInputStream(packed)).use { it.readBytes() }
        val bb = ByteBuffer.wrap(binary).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(0x46546c67, bb.getInt(0))
        assertEquals(2, bb.getInt(4))
        assertEquals(binary.size, bb.getInt(8))
        val jsonSize = bb.getInt(12)
        assertEquals(0x4e4f534a, bb.getInt(16))
        val gltf = String(binary,20,jsonSize,Charsets.UTF_8)
        for (name in listOf("TERRAIN_GEO","CLIFFS_COAST_REAL",
            "ISLETS_ROCK","RIVERS_river_east","RIVERS_river_west",
            "QUARRIES_mine1_quarry","QUARRIES_mine2_quarry",
            "QUARRIES_mine3_quarry")) {
            assertTrue("Missing real geometry: $name", gltf.contains(name))
        }
        for ((kind, count) in listOf("MINE" to 3, "FACTORY" to 2,
            "WAREHOUSE" to 4, "RESEARCH" to 1,
            "MUNICIPAL" to 1, "ENERGY" to 1, "MARKET" to 1)) {
            for (ordinal in 0 until count)
                assertTrue("Missing LOT_${kind}_${ordinal}",gltf.contains("LOT_${kind}_${ordinal}"))
        }
    }

    @Test fun referencePixelAnchorsHaveNotMovedInTerrainPass() {
        val manifest = File("src/main/assets/dailycorp/3d/city001_terrain_v3.json").readText()
        assertTrue(manifest.contains("dailycorp.city001.terrain.v3"))
        val knownPixels = listOf(
            1190 to 222, 553 to 151, 1342 to 641,
            549 to 407, 337 to 537,
            1006 to 700, 775 to 572, 232 to 600, 396 to 724,
            324 to 254, 790 to 262, 1070 to 398, 831 to 413
        )
        for ((x,y) in knownPixels) {
            val needle = Regex("\\\"referencePixel\\\"\\s*:\\s*\\[$x,\\s*$y\\]")
            assertTrue("Lost fixed site at ($x, $y)",needle.containsMatchIn(manifest))
        }
        val city=CityGenerator.makeCities(20261020L).first()
        assertEquals(13,city.lots.size)
    }
}
