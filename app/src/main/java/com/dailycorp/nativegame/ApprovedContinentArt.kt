package com.dailycorp.nativegame

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.RectF

/**
 * Pixel-identical raster background from the approved SVG, with native city hit targets.
 *
 * Coordinates are generated from continent_interactive.svg (viewBox 0 0 1536 1024).
 * Keep city IDs 1..48 in sync with the existing GameEngine; SVG is source of truth,
 * while Android Canvas draws the original image without a WebView.
 */
internal class ApprovedContinentArt(private val context: Context) {
    companion object {
        const val WIDTH = 1536f
        const val HEIGHT = 1024f
        const val CITY_COUNT = 48
        private const val ASSET = "dailycorp/world/continent_reference.jpg"
        private val CITY_PIXELS = intArrayOf(
        305, 131, // city_01
        453, 131, // city_02
        587, 145, // city_03
        670, 63, // city_04
        926, 54, // city_05
        947, 133, // city_06
        1111, 117, // city_07
        1340, 139, // city_08
        255, 249, // city_09
        400, 269, // city_10
        602, 236, // city_11
        811, 248, // city_12
        918, 251, // city_13
        1066, 232, // city_14
        1268, 234, // city_15
        1441, 247, // city_16
        228, 394, // city_17
        443, 367, // city_18
        596, 349, // city_19
        814, 352, // city_20
        983, 376, // city_21
        1169, 329, // city_22
        1316, 386, // city_23
        1444, 387, // city_24
        151, 589, // city_25
        341, 535, // city_26
        537, 466, // city_27
        710, 495, // city_28
        912, 479, // city_29
        1159, 469, // city_30
        1345, 508, // city_31
        1473, 520, // city_32
        1026, 544, // city_33
        459, 637, // city_34
        668, 628, // city_35
        829, 650, // city_36
        1074, 610, // city_37
        1167, 690, // city_38
        1272, 646, // city_39
        1448, 666, // city_40
        148, 758, // city_41
        315, 795, // city_42
        543, 818, // city_43
        864, 805, // city_44
        1033, 862, // city_45
        1164, 837, // city_46
        1270, 849, // city_47
        1350, 738 // city_48
        )

        fun pixelPoint(id: Int): PointF? {
            if (id !in 1..CITY_COUNT) return null
            val offset = (id - 1) * 2
            return PointF(CITY_PIXELS[offset].toFloat(), CITY_PIXELS[offset + 1].toFloat())
        }
    }

    private val bitmap: Bitmap? by lazy {
        try {
            context.assets.open(ASSET).use { source ->
                BitmapFactory.decodeStream(source, null, BitmapFactory.Options().apply {
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                })
            }?.takeIf { it.width == WIDTH.toInt() && it.height == HEIGHT.toInt() }
        } catch (_: Exception) {
            null
        }
    }

    val isAvailable: Boolean get() = bitmap != null

    /** Returns false when the image is absent, allowing the procedural map fallback. */
    fun draw(canvas: Canvas, rect: RectF, paint: Paint): Boolean {
        val image = bitmap ?: return false
        paint.reset()
        paint.isAntiAlias = true
        paint.isFilterBitmap = true
        paint.alpha = 255
        canvas.drawBitmap(image, null, rect, paint)
        return true
    }
}
