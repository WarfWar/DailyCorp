package com.dailycorp.nativegame

/** The native screens share one live simulation; both persist its serializable state. */
object GameSession {
    var engine: GameEngine? = null
    var cityId: Int = 1
    var mineLotId: Int = -1
    fun save(activity:android.app.Activity) {
        val current = engine ?: return
        try {
            java.io.ObjectOutputStream(activity.openFileOutput("dailycorp-native-v1.save",android.content.Context.MODE_PRIVATE))
                .use { it.writeObject(current.state) }
        } catch (_:Exception) {}
    }
}