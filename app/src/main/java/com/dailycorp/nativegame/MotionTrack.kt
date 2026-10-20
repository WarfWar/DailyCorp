package com.dailycorp.nativegame

import kotlin.math.max
import kotlin.math.min

/** UI-only interpolation: simulation moves by cells, actors appear between them. */
data class AnimatedPoint(val x: Float, val y: Float)
class MotionTrack(x: Float, y: Float, private val durationMs: Long = 900L) {
    private var start = AnimatedPoint(x,y)
    private var end = start
    private var startedAtMs: Long = 0L
    private var moving = false

    fun target(x: Float, y: Float, nowMs: Long) {
        if (end.x == x && end.y == y) return
        // Continue smoothly from the currently visible position, not the last tile.
        start = position(nowMs)
        end = AnimatedPoint(x,y)
        startedAtMs = nowMs
        moving = start != end
    }
    fun position(nowMs: Long): AnimatedPoint {
        if (!moving) return end
        val fraction = ((nowMs-startedAtMs).toFloat()/max(1L,durationMs).toFloat()).coerceIn(0f,1f)
        // Linear interpolation avoids artificial braking at every cell.
        // Keep the actor at the current interpolated point when targets change.
        if (fraction >= 1f) moving = false
        return AnimatedPoint(start.x+(end.x-start.x)*fraction,
            start.y+(end.y-start.y)*fraction)
    }
    fun animating(nowMs: Long): Boolean = moving && nowMs-startedAtMs < durationMs
}
