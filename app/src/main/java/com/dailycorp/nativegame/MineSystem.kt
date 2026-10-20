package com.dailycorp.nativegame

import java.io.Serializable
import java.util.ArrayDeque
import java.util.Random
import kotlin.math.abs
import kotlin.math.min

/** Original, side-view mining simulation. All underground state is serializable. */
enum class MineTerrain { BEDROCK, ROCK, ORE, TUNNEL, SHAFT }

data class MineBlock(
    var terrain: MineTerrain,
    var material: String = "",
    var amount: Int = 0,
    var hardness: Int = 0,
    var ordered: Boolean = false
) : Serializable

data class MineWorker(
    val id: Int, var x: Int = MineWorld.ENTRANCE_X, var y: Int = MineWorld.ENTRANCE_Y,
    var striking: Boolean = false
) : Serializable

data class MineCart(
    val id: Int, var x: Int = MineWorld.ENTRANCE_X, var y: Int = MineWorld.ENTRANCE_Y,
    var cargo: String = "", var amount: Int = 0, var delay: Int = 0
) : Serializable

data class MinePile(val x: Int, val y: Int, val material: String, var amount: Int) : Serializable

data class UndergroundFloor(
    val number: Int,
    val blocks: MutableList<MutableList<MineBlock>>,
    val workers: MutableList<MineWorker> = mutableListOf(),
    val carts: MutableList<MineCart> = mutableListOf(),
    val piles: MutableList<MinePile> = mutableListOf(),
    var excavated: Int = 0
) : Serializable {
    fun block(x: Int, y: Int): MineBlock? = blocks.getOrNull(y)?.getOrNull(x)
}

data class UndergroundMine(
    var activeFloor: Int = 1,
    var unlockedFloor: Int = 1,
    var cartsOwned: Int = 1,
    var drillLevel: Int = 1,
    var cartLevel: Int = 1,
    val floors: MutableMap<Int, UndergroundFloor> = mutableMapOf()
) : Serializable

object MineWorld {
    const val WIDTH = 30
    const val HEIGHT = 21
    const val ENTRANCE_X = 14
    const val ENTRANCE_Y = 3
    private val directions = listOf(Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1))
    private fun passable(b: MineBlock?) = b?.terrain == MineTerrain.TUNNEL || b?.terrain == MineTerrain.SHAFT

    fun interior(mine: MineState): UndergroundMine {
        if (mine.interior == null) mine.interior = UndergroundMine()
        return mine.interior!!
    }

    fun floor(mine: MineState, mineSeed: Long): UndergroundFloor {
        val underground = interior(mine)
        val active = underground.activeFloor.coerceIn(1, underground.unlockedFloor)
        underground.activeFloor = active
        val f = underground.floors.getOrPut(active) { generate(mine, mineSeed, active) }
        while (f.workers.size < mine.workers) f.workers.add(MineWorker(f.workers.size + 1))
        while (f.carts.size < underground.cartsOwned) f.carts.add(MineCart(f.carts.size + 1))
        return f
    }

    private fun generate(mine: MineState, seed: Long, number: Int): UndergroundFloor {
        val random = Random(seed xor (number.toLong() * 7919L) xor (mine.lotId.toLong() * 65537L))
        val grid = (0 until HEIGHT).map { y ->
            (0 until WIDTH).map { x ->
                if (x == 0 || x == WIDTH - 1 || y == HEIGHT - 1) MineBlock(MineTerrain.BEDROCK)
                else if ((x == ENTRANCE_X && y in 0..5) || (y == ENTRANCE_Y && x in 10..18)) {
                    MineBlock(if (x == ENTRANCE_X) MineTerrain.SHAFT else MineTerrain.TUNNEL)
                } else if (random.nextInt(100) < 31 && y > 2 && mine.ores.isNotEmpty()) {
                    val material = mine.ores[random.nextInt(mine.ores.size)]
                    MineBlock(MineTerrain.ORE, material, 1 + random.nextInt(3),
                        2 + random.nextInt(3) + number / 6)
                } else {
                    MineBlock(MineTerrain.ROCK, hardness = 2 + random.nextInt(4) + number / 8)
                }
            }.toMutableList()
        }.toMutableList()
        return UndergroundFloor(number, grid)
    }

    fun toggleDig(mine: MineState, seed: Long, x: Int, y: Int): Boolean {
        val block = floor(mine, seed).block(x, y) ?: return false
        if (block.terrain != MineTerrain.ROCK && block.terrain != MineTerrain.ORE) return false
        block.ordered = !block.ordered
        return true
    }

    fun changeFloor(mine: MineState, seed: Long, requested: Int): Boolean {
        val u = interior(mine)
        if (requested !in 1..u.unlockedFloor) return false
        u.activeFloor = requested
        floor(mine, seed)
        return true
    }

    // BFS on dug corridors. Neither miners nor carts teleport through stone.
    private fun path(f: UndergroundFloor, from: Point, to: Point): List<Point> {
        if (from == to) return listOf(from)
        val queue: ArrayDeque<Point> = ArrayDeque()
        val previous = hashMapOf(from to from)
        queue.add(from)
        while (queue.isNotEmpty()) {
            val at = queue.removeFirst()
            if (at == to) break
            for (step in directions) {
                val next = Point(at.x + step.x, at.y + step.y)
                if (next in previous || !passable(f.block(next.x, next.y))) continue
                previous[next] = at
                queue.addLast(next)
            }
        }
        if (to !in previous) return emptyList()
        val result = mutableListOf(to)
        while (result.last() != from) result.add(previous.getValue(result.last()))
        result.reverse()
        return result
    }

    fun step(mine: MineState, seed: Long, drillBonus: Int = 0, cartBonus: Int = 0, geologyBonus: Int = 0) {
        val floor = floor(mine, seed)
        val underground = interior(mine)
        for (worker in floor.workers) {
            worker.striking = false
            var bestPath: List<Point> = emptyList()
            var target: Point? = null
            for (y in 1 until HEIGHT - 1) for (x in 1 until WIDTH - 1) {
                val block = floor.block(x, y) ?: continue
                if (!block.ordered || (block.terrain != MineTerrain.ROCK && block.terrain != MineTerrain.ORE)) continue
                for (dir in directions) {
                    val neighbor = Point(x + dir.x, y + dir.y)
                    if (!passable(floor.block(neighbor.x, neighbor.y))) continue
                    val candidate = path(floor, Point(worker.x, worker.y), neighbor)
                    if (candidate.isNotEmpty() && (bestPath.isEmpty() || candidate.size < bestPath.size)) {
                        bestPath = candidate
                        target = Point(x, y)
                    }
                }
            }
            if (target == null) continue
            if (bestPath.size > 1) {
                worker.x = bestPath[1].x; worker.y = bestPath[1].y
                continue
            }
            val rock = floor.block(target.x, target.y) ?: continue
            worker.striking = true
            rock.hardness -= underground.drillLevel + drillBonus
            if (rock.hardness > 0) continue
            if (rock.terrain == MineTerrain.ORE && rock.amount > 0) {
                val left = mine.reserves[rock.material] ?: 0
                val mined = min(left, rock.amount + geologyBonus)
                if (mined > 0) {
                    mine.reserves[rock.material] = left - mined
                    floor.piles.add(MinePile(target.x, target.y, rock.material, mined))
                }
            }
            rock.terrain = MineTerrain.TUNNEL
            rock.ordered = false
            rock.amount = 0
            floor.excavated++
        }
        for (cart in floor.carts) {
            // Old v1 snapshots can contain a delay counter; clear it.
            // A cart advances every tick, without waiting on intermediate cells.
            cart.delay = 0
            val current = Point(cart.x, cart.y)
            val depot = Point(ENTRANCE_X, ENTRANCE_Y)
            if (cart.amount > 0) {
                if (current == depot) {
                    mine.loading[cart.cargo] = (mine.loading[cart.cargo] ?: 0) + cart.amount
                    cart.amount = 0; cart.cargo = ""
                } else {
                    val route = path(floor, current, depot)
                    if (route.size > 1) { cart.x = route[1].x; cart.y = route[1].y }
                }
            } else {
                var best: MinePile? = null
                var bestPath: List<Point> = emptyList()
                for (pile in floor.piles) {
                    val route = path(floor, current, Point(pile.x, pile.y))
                    if (route.isNotEmpty() && (bestPath.isEmpty() || route.size < bestPath.size)) {
                        best = pile; bestPath = route
                    }
                }
                if (best != null) {
                    if (bestPath.size > 1) {
                        cart.x = bestPath[1].x; cart.y = bestPath[1].y
                    } else {
                        val carried = min(best.amount, 3 + underground.cartLevel * 2 + cartBonus)
                        best.amount -= carried
                        cart.amount = carried; cart.cargo = best.material
                        if (best.amount <= 0) floor.piles.remove(best)
                    }
                }
            }

        }
    }
}
