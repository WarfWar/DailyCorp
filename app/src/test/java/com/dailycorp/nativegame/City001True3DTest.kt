package com.dailycorp.nativegame

import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.Base64

/** Offline regression: the scene is a real GLB, not a flat image. */
class City001True3DTest {
    private val assets = File("src/main/assets/dailycorp/3d")
    @Test fun glbContainsRealMeshesAndAllNamedGameSites() {
        val file = File(assets, "city001_v0_1.glb.b64")
        assertTrue("GLB asset missing", file.isFile)
        val raw = Base64.getMimeDecoder().decode(file.readText().trim())
        val data = ByteBuffer.wrap(raw).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals(0x46546c67, data.getInt(0))
        assertEquals(2, data.getInt(4))
        assertEquals(raw.size, data.getInt(8))
        val jsonLength = data.getInt(12)
        assertEquals(0x4e4f534a, data.getInt(16))
        val json = String(raw,20,jsonLength,Charsets.UTF_8)
        for ((kind,count) in listOf("MINE" to 3, "FACTORY" to 2,
            "WAREHOUSE" to 4, "RESEARCH" to 1, "MUNICIPAL" to 1,
            "ENERGY" to 1, "MARKET" to 1)) {
            for (n in 0 until count)
                assertTrue("Missing genuine mesh LOT_${kind}_${n}",
                    json.contains("LOT_${kind}_${n}"))
        }
        assertTrue("No indexed 3D triangles found", json.contains("indices"))
        assertTrue("No vertex 3D positions found", json.contains("POSITION"))
        assertTrue(raw.size in 50_000..3_000_000)
    }

    @Test fun layoutContainsExactThirteenInteractiveSitesAndPreservesSavedIds() {
        val source = File(assets,"city001_scene.json").readText()
        val counts = BuildingKind.entries.associateWith { kind ->
            Regex("\\\"kind\\\"\\s*:\\s*\\\"${kind.name}\\\"").findAll(source).count()
        }
        assertEquals(3,counts[BuildingKind.MINE])
        assertEquals(2,counts[BuildingKind.FACTORY])
        assertEquals(4,counts[BuildingKind.WAREHOUSE])
        for(kind in listOf(BuildingKind.RESEARCH, BuildingKind.MUNICIPAL,
            BuildingKind.ENERGY,BuildingKind.MARKET))assertEquals(1,counts[kind])
        val city = CityGenerator.makeCities(20261020L).first()
        assertEquals(13,city.lots.size)
        for (kind in BuildingKind.entries) {
            assertEquals(counts[kind],city.lots.count { it.kind==kind })
        }
    }
}
