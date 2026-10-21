package com.dailycorp.nativegame

import kotlin.random.Random
import kotlin.math.abs

/**
 * Pilot city visual layout (city_001) on the native Kotlin renderer.
 *
 * This layer must never recreate economic entities or assign new lot IDs:
 * City.lots from the save file remains the single source of truth.
 * Additional boulevards, landscaping and props are non-economic scenery.
 */
object City001Layout {
    data class Decoration(val at: Point, val sprite: String, val size: Float)

    fun plan(city: City): MapPlan {
        val base = CityGenerator.plan(city)
        val occupiedLots = city.lots.map { it.pos }.toSet()
        val roads = base.roads.toMutableSet()
        val c = base.center

        // A small, connected civic ring complements the old street network.
        // Preserve all original roads and every saved industrial gate.
        val ring = mutableListOf<Point>()
        for (x in c.x - 4..c.x + 4) {
            ring.add(Point(x, c.y - 4))
            ring.add(Point(x, c.y + 4))
        }
        for (y in c.y - 3..c.y + 3) {
            ring.add(Point(c.x - 4, y))
            ring.add(Point(c.x + 4, y))
        }
        for (p in ring) {
            if (p.x !in 2 until base.width - 2 || p.y !in 2 until base.height - 2) continue
            if (p in occupiedLots) continue
            // The additional road must not clip a saved building foundation.
            if (occupiedLots.any { abs(it.x - p.x) <= 1 && abs(it.y - p.y) <= 1 }) continue
            roads.add(p)
        }
        // A ring may be cut into islands by saved foundations. Only keep
        // segments reachable from the original connected freight network.
        // Never replace existing economic gates or add phantom truck roads.
        val connected = mutableSetOf<Point>()
        val frontier = ArrayDeque<Point>()
        val first = base.roads.firstOrNull()
        if (first != null) {
            connected.add(first)
            frontier.add(first)
        }
        while (frontier.isNotEmpty()) {
            val p = frontier.removeFirst()
            for (offset in listOf(Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1))) {
                val next = Point(p.x + offset.x, p.y + offset.y)
                if (next in roads && connected.add(next)) frontier.add(next)
            }
        }
        roads.retainAll(connected)
        // Residential sprites never paint a new boulevard or a saved lot.
        val homes = base.homes.filter {
            it !in roads && it !in occupiedLots &&
                // Reserve a walkable, green civic district instead of filling
                // the test city center with randomly placed residential boxes.
                !(abs(it.x - c.x) <= 5 && abs(it.y - c.y) <= 5)
        }
        return MapPlan(base.width, base.height, roads, city.lots, homes, c)
    }

    /**
     * Sparse, physically separate curated city decorations from the bundled
     * isometric building/infra sprite atlas. No text is baked into the scene.
     */
    fun decorations(plan: MapPlan, seed: Long): List<Decoration> {
        val random = Random(seed xor 0x5A1B2026L)
        val blocked = HashSet<Point>().apply {
            addAll(plan.roads)
            addAll(plan.homes)
            addAll(plan.lots.map { it.pos })
        }
        val result = mutableListOf<Decoration>()
        val candidates = mutableListOf<Point>()
        for (y in 3 until plan.height - 3) for (x in 3 until plan.width - 3)
            candidates.add(Point(x, y))
        candidates.shuffle(random)

        for (p in candidates) {
            if (result.size >= 30) break
            if (p in blocked || result.any { abs(it.at.x - p.x) <= 2 && abs(it.at.y - p.y) <= 2 }) continue
            // Keep house/lot frontages and traffic intersections unobstructed.
            if (plan.lots.any { abs(it.pos.x - p.x) <= 2 && abs(it.pos.y - p.y) <= 2 }) continue
            if (plan.homes.any { abs(it.x - p.x) <= 1 && abs(it.y - p.y) <= 1 }) continue

            val nearIndustry = plan.lots.any {
                it.kind in setOf(BuildingKind.MINE, BuildingKind.FACTORY, BuildingKind.WAREHOUSE) &&
                    abs(it.pos.x - p.x) + abs(it.pos.y - p.y) <= 7
            }
            val downtown = abs(plan.center.x - p.x) + abs(plan.center.y - p.y) <= 11
            val sprite = when {
                downtown -> listOf("buildings.park_10", "buildings.square_10",
                    "infra.fountain", "infra.flowerbed", "infra.alley")[result.size % 5]
                nearIndustry -> listOf("infra.containers", "infra.pallets",
                    "infra.storage_yard", "infra.service_parking")[result.size % 4]
                else -> listOf("buildings.park_10", "infra.flowerbed", "infra.bench")[result.size % 3]
            }
            val size = if (sprite.startsWith("buildings.")) 1.12f else 0.82f
            result.add(Decoration(p, sprite, size))
        }
        return result.sortedWith(compareBy({ it.at.x + it.at.y }, { it.at.x }))
    }
}
