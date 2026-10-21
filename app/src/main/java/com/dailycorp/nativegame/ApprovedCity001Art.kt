package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import kotlin.math.hypot
import kotlin.math.min

/**
 * Interactive, approved mirrored city 001 composition.
 *
 * The illustration is a VISUAL LAYER ONLY. GameEngine.state.cities[0].lots,
 * its IDs, purchase states, mine interiors and freight routes are never
 * generated from the image or serialized here.
 *
 * Asset: app/src/main/assets/dailycorp/world/city001_approved.webp
 * Native Canvas handles all hit targets, zoom and purchase-status overlays.
 */
internal class ApprovedCity001Art(private val context: Context) {
    companion object {
        const val WIDTH = 1536f
        const val HEIGHT = 1024f
        private const val ASSET = "dailycorp/world/city001_approved.webp"

        internal data class Site(
            val kind: BuildingKind,
            val ordinal: Int,
            val px: Float,
            val py: Float
        )

        // One site per economically distinct building in the approved
        // mirrored reference. Coordinates use the ORIGINAL 1536x1024 image.
        private val SITES = listOf(
            Site(BuildingKind.MINE,      0, 1181f, 165f),
            Site(BuildingKind.MINE,      1,  553f, 101f),
            Site(BuildingKind.MINE,      2, 1360f, 592f),
            Site(BuildingKind.FACTORY,   0,  540f, 351f),
            Site(BuildingKind.FACTORY,   1,  350f, 467f),
            Site(BuildingKind.WAREHOUSE, 0,  979f, 629f),
            Site(BuildingKind.WAREHOUSE, 1,  744f, 521f),
            Site(BuildingKind.WAREHOUSE, 2,  231f, 558f),
            Site(BuildingKind.WAREHOUSE, 3,  394f, 681f),
            Site(BuildingKind.RESEARCH,  0,  305f, 198f),
            Site(BuildingKind.MUNICIPAL, 0,  761f, 205f),
            Site(BuildingKind.ENERGY,    0, 1070f, 345f),
            Site(BuildingKind.MARKET,    0,  823f, 375f)
        )

        /** Pure binding: don't assume saved lot numeric IDs equal array indexes. */
        fun mappedSites(city: City): List<Pair<Lot, Site>> {
            return SITES.mapNotNull { target ->
                val lot = city.lots.filter { it.kind == target.kind }.getOrNull(target.ordinal)
                if (lot == null) null else lot to target
            }
        }
        fun siteCount(): Int = SITES.size
    }

    private val bitmap: Bitmap? by lazy(LazyThreadSafetyMode.NONE) {
        try {
            context.assets.open(ASSET).use { stream ->
                BitmapFactory.decodeStream(stream, null, BitmapFactory.Options().apply {
                    inScaled = false
                    inPreferredConfig = Bitmap.Config.RGB_565
                })
            }?.takeIf { it.width.toFloat() / it.height.toFloat() in 1.48f..1.52f }
        } catch (_: Exception) {
            null
        }
    }
    val isAvailable: Boolean get() = bitmap != null
    private val imagePaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val uiPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    /**
     * Fit the ENTIRE image into the view when zoom=1. Users may zoom/pan
     * independently of continent; no forced crop of coastal cliffs/harbor.
     */
    fun rect(viewWidth: Int, viewHeight: Int, zoom: Float, panX: Float, panY: Float): RectF {
        val availableWidth = viewWidth * 0.985f
        val availableHeight = viewHeight * 0.985f
        val factor = min(availableWidth / WIDTH, availableHeight / HEIGHT) * zoom
        val w = WIDTH * factor
        val h = HEIGHT * factor
        val cx = viewWidth / 2f + panX
        val cy = viewHeight / 2f + panY
        return RectF(cx - w / 2f, cy - h / 2f, cx + w / 2f, cy + h / 2f)
    }

    private fun screen(site: Site, bounds: RectF): Pair<Float, Float> =
        Pair(bounds.left + site.px / WIDTH * bounds.width(),
             bounds.top + site.py / HEIGHT * bounds.height())

    fun draw(canvas: Canvas, bounds: RectF, city: City, engine: GameEngine, selectedLotId: Int?) {
        val image = bitmap ?: return
        canvas.drawBitmap(image, null, bounds, imagePaint)
        val company = engine.company(city.id)
        val dp = context.resources.displayMetrics.density
        val scale = min(bounds.width() / WIDTH, bounds.height() / HEIGHT)

        for ((lot, site) in mappedSites(city)) {
            val (x, y) = screen(site, bounds)
            val owned = when (lot.kind) {
                BuildingKind.MINE -> lot.id in company.mines
                BuildingKind.FACTORY -> lot.id in company.factories
                BuildingKind.WAREHOUSE -> lot.id in company.warehouses
                else -> true
            }
            val selected = lot.id == selectedLotId
            // Distinct outlines are runtime overlays, not paint baked into
            // the background. They continue to work after loading saved games.
            if (selected || !owned) {
                val radius = (if (selected) 24f else 17f) * dp
                uiPaint.style = Paint.Style.STROKE
                uiPaint.strokeWidth = if (selected) 3.7f * dp else 2f * dp
                uiPaint.color = if (selected) Color.rgb(250, 221, 92)
                    else Color.argb(225, 255, 185, 65)
                canvas.drawCircle(x, y, radius, uiPaint)
                uiPaint.style = Paint.Style.FILL
                if (!owned && scale > 0.35f) {
                    uiPaint.color = Color.rgb(255, 192, 76)
                    uiPaint.textAlign = Paint.Align.CENTER
                    uiPaint.textSize = 9f * dp
                    uiPaint.isFakeBoldText = true
                    canvas.drawText("+", x, y - radius - 5f * dp, uiPaint)
                    uiPaint.isFakeBoldText = false
                }
            }
        }
    }

    /** Translate a tap in pixel screen coordinates into the SAME saved Lot. */
    fun hitLot(x: Float, y: Float, bounds: RectF, city: City, density: Float): Lot? {
        if (!bounds.contains(x, y)) return null
        val hitRadius = 34f * density
        return mappedSites(city)
            .map { pair ->
                val at = screen(pair.second, bounds)
                pair.first to hypot(at.first - x, at.second - y)
            }
            .filter { it.second <= hitRadius }
            .minByOrNull { it.second }
            ?.first
    }

    fun allBound(city: City): Boolean =
        mappedSites(city).size == siteCount() && city.lots.size == siteCount()
}
