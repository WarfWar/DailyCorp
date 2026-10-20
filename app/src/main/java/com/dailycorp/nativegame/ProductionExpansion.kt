package com.dailycorp.nativegame

/** 20 ore refinery chains + 11 equipment categories × 10 technology eras.
 * All materials have unique stable ids. The original 13 recipes stay intact.
 */
object ProductionExpansion {
    data class Refined(val name:String,val era:Int)
    val refined=listOf(
        Refined("Алюминиевый слиток",2),Refined("Никелевый сплав",3),
        Refined("Цинковый слиток",2),Refined("Свинцовый слиток",2),
        Refined("Карбид вольфрама",4),Refined("Кобальтовый слиток",4),
        Refined("Титановый слиток",5),Refined("Литиевый концентрат",5),
        Refined("Графитовый порошок",3),Refined("Кварцевое стекло",2),
        Refined("Серный реагент",3),Refined("Оксид урана",7),
        Refined("Платиновый слиток",6),Refined("Серебряный слиток",3),
        Refined("Марганцевая добавка",3),Refined("Хромовый слиток",4),
        Refined("Молибденовый слиток",5),Refined("Оловянный слиток",2),
        Refined("Кремниевая пластина",5),Refined("Редкоземельный магнит",7)
    )
    val equipmentNames=listOf(
        "Инструменты","Рельсовое хозяйство","Шахтная вагонетка","Буровая установка",
        "Энергомодуль","Вентиляционный модуль","Грузовой подъёмник",
        "Конвейер","Датчики","Блок управления","Шахтная инфраструктура"
    )
    private val earlyIngredients=listOf(
        mapOf("iron" to 2,"clay" to 1),
        mapOf("iron" to 3,"gravel" to 2),
        mapOf("iron" to 3,"copper" to 1),
        mapOf("iron" to 4,"coal" to 2),
        mapOf("copper" to 3,"coal" to 2),
        mapOf("clay" to 2,"sand" to 2),
        mapOf("iron" to 3,"gravel" to 3),
        mapOf("copper" to 2,"iron" to 3),
        mapOf("copper" to 2,"sand" to 1),
        mapOf("copper" to 3,"iron" to 1),
        mapOf("brick" to 2,"granite" to 2,"iron" to 3)
    )
    private val upperIngredients=mapOf(
        2 to listOf("steel","wire","glass","cement"),
        3 to listOf("parts","ceramics","chemicals","construction_kit"),
        4 to listOf("alloy","electronics","machine_parts"),
        5 to listOf("alloy","electronics","machine_parts"),
        6 to listOf("alloy","electronics","machine_parts"),
        7 to listOf("alloy","electronics","machine_parts"),
        8 to listOf("alloy","electronics","machine_parts"),
        9 to listOf("alloy","electronics","machine_parts"),
        10 to listOf("alloy","electronics","machine_parts")
    )
    val extraMaterials:List<Material> = refined.mapIndexed {i,r ->
        Material("refined_"+i,r.name,r.era,120+i*37+r.era*42)
    }+(1..10).flatMap {era ->
        equipmentNames.mapIndexed {i,name ->
            Material("epoch_"+era+"_"+i,name+" · эпоха "+era,era,
                150+era*220+i*60+era*era*25)
        }
    }
    private fun plan():Map<String,Recipe> {
        val result=linkedMapOf<String,Recipe>()
        // Canonical input ore_i_1 accepts all 12 grades of that ore family.
        for((i,r) in refined.withIndex()){
            val inputs=linkedMapOf<String,Int>()
            inputs["ore_"+i+"_1"]=4+r.era
            inputs[if(i%3==0)"coal" else if(i%3==1)"salt" else "sulfur"]=1+(r.era/3)
            result["refined_"+i]=Recipe("refined_"+i,inputs,14+r.era*5)
        }
        for(era in 1..10)for(i in equipmentNames.indices){
            val inputs=linkedMapOf<String,Int>()
            if(era==1)inputs.putAll(earlyIngredients[i])
            else{
                inputs["epoch_"+(era-1)+"_"+i]=1+era/4
                val essentials=upperIngredients.getValue(era)
                inputs[essentials[i%essentials.size]]=2+era/2
                if(i in listOf(3,6,7,9,10))
                    inputs["epoch_"+(era-1)+"_"+((i+3)%equipmentNames.size)]=1
                val specialty=refined.indices.filter{refined[it].era==era}
                if(i<specialty.size){
                    inputs["refined_"+specialty[i]]=1+era/3
                }else if(era>=5 && i%2==0){
                    val available=refined.indices.filter{refined[it].era<=era}
                    inputs["refined_"+available[(era*7+i*3)%available.size]]=1+era/4
                }
            }
            result["epoch_"+era+"_"+i]=Recipe("epoch_"+era+"_"+i,inputs,20+era*8+i*3)
        }
        return result
    }
    val recipes:Map<String,Recipe> = plan()
    init{
        require(extraMaterials.size==130)
        require(recipes.size==130)
        require(refined.indices.all{i -> recipes.values.any{r->
            r.output!="refined_"+i && r.ingredients.containsKey("refined_"+i)
        }})
    }
}
