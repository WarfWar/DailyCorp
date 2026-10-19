package com.dailycorp.nativegame

/** Ten historical technology eras with prerequisites and meaningful mining bonuses. */
data class Technology(val id:String, val title:String, val era:Int,
    val cost:Int, val requires:List<String> = emptyList(), val description:String)

object ScienceTree {
    val eraNames = listOf("Ручной труд","Механизация","Паровая эпоха","Электрификация",
        "Массовое производство","Автоматизация","Цифровизация","Роботизация",
        "Высокие технологии","Квантовая индустрия")
    val nodes: List<Technology> = (1..10).flatMap { era ->
        val prev = if (era == 1) emptyList() else listOf("mining_" + (era-1))
        listOf(
            Technology("mining_" + era, "Горное дело: " + eraNames[era-1],era,
                30 + era * 20,prev,"Ускорение проходки и укрепление шахт"),
            Technology("transport_" + era,"Подземный транспорт: " + eraNames[era-1],era,
                35 + era * 20,listOf("mining_" + era),"Улучшение вагонеток и погрузки")
        )
    }
    fun owned(state:GameState): MutableSet<String> {
        if (state.unlockedResearch == null) state.unlockedResearch = mutableSetOf()
        return state.unlockedResearch!!
    }
    fun canUnlock(state:GameState, node:Technology): Boolean =
        node.id !in owned(state) && node.era <= state.era &&
        node.requires.all { it in owned(state) } && state.science >= node.cost

    fun unlock(state:GameState, id:String):Boolean {
        val node = nodes.firstOrNull { it.id == id } ?: return false
        if (!canUnlock(state,node)) return false
        state.science -= node.cost
        owned(state).add(id)
        return true
    }
    fun drillBoost(state:GameState):Boolean = owned(state).any { it.startsWith("mining_") }
    fun cartBoost(state:GameState):Boolean = owned(state).any { it.startsWith("transport_") }
    fun canAdvanceEra(state:GameState):Boolean =
        state.era < 10 && ("mining_" + state.era) in owned(state) &&
        state.science >= state.era*100 && state.money >= state.era*500L
}
