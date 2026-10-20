package com.dailycorp.nativegame

/** 80 technology nodes: eight interlinked disciplines across ten eras. */
data class Technology(val id:String, val title:String, val era:Int,
    val cost:Int, val requires:List<String> = emptyList(), val description:String)

object ScienceTree {
    val eraNames = listOf("Ручной труд","Механизация","Паровая эпоха","Электрификация",
        "Массовое производство","Автоматизация","Цифровизация","Роботизация",
        "Высокие технологии","Квантовая индустрия")

    val nodes:List<Technology> = (1..10).flatMap { era ->
        val prior=if(era==1)emptyList() else listOf("mining_"+(era-1))
        val cost=30+era*20
        listOf(
            Technology("mining_"+era,"Шахтное дело · "+eraNames[era-1],era,
                cost,prior,"Повышает скорость бурения и проходки."),
            Technology("transport_"+era,"Рельсы и вагонетки · "+eraNames[era-1],era,
                cost+7,listOf("mining_"+era),"Вместимость вагонеток и скорость подземной доставки."),
            Technology("geology_"+era,"Георазведка · "+eraNames[era-1],era,
                cost+12,listOf("mining_"+era),"Больше полезной руды из разработанных залежей."),
            Technology("metallurgy_"+era,"Металлургия · "+eraNames[era-1],era,
                cost+16,listOf("geology_"+era),"Ускоряет выпуск изделий на заводах."),
            Technology("logistics_"+era,"Промышленная логистика · "+eraNames[era-1],era,
                cost+19,listOf("transport_"+era),"Увеличивает грузоподъёмность и скорость грузовиков."),
            Technology("energy_"+era,"Энергоснабжение · "+eraNames[era-1],era,
                cost+23,listOf("metallurgy_"+era),"Снижает время производственных циклов."),
            Technology("automation_"+era,"Автоматика шахт · "+eraNames[era-1],era,
                cost+29,listOf("transport_"+era,"energy_"+era),
                "Дополнительная производительность шахтёров и вагонеток."),
            Technology("science_"+era,"Лаборатории · "+eraNames[era-1],era,
                cost+26,listOf("geology_"+era),
                "Дополнительные очки науки за завершённые контракты.")
        )
    }
    val byId=nodes.associateBy{it.id}
    fun owned(state:GameState): MutableSet<String> {
        if (state.unlockedResearch == null) state.unlockedResearch = mutableSetOf()
        return state.unlockedResearch!!
    }
    fun level(state:GameState, branch:String):Int =
        (1..10).count{branch+"_"+it in owned(state)}
    fun canUnlock(state:GameState, node:Technology): Boolean =
        node.id !in owned(state) && node.era <= state.era &&
        node.requires.all { it in owned(state) } && state.science >= node.cost

    fun unlock(state:GameState, id:String):Boolean {
        val node=byId[id]?:return false
        if(!canUnlock(state,node))return false
        state.science-=node.cost
        owned(state).add(id)
        return true
    }
    fun drillBoost(state:GameState):Int =
        level(state,"mining") + level(state,"automation")
    fun cartBoost(state:GameState):Int =
        level(state,"transport") + level(state,"automation")
    fun geologyBoost(state:GameState):Int = level(state,"geology").coerceAtMost(3)
    fun productionBoost(state:GameState):Int =
        level(state,"metallurgy")+level(state,"energy")
    fun logisticsBoost(state:GameState):Int = level(state,"logistics")
    fun contractScienceBoost(state:GameState):Int = level(state,"science")*3
    fun canAdvanceEra(state:GameState):Boolean =
        state.era<10 && ("mining_"+state.era) in owned(state) &&
        state.science>=state.era*100 && state.money>=state.era*500L
}
