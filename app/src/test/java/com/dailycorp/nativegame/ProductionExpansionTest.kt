package com.dailycorp.nativegame

import org.junit.Assert.*
import org.junit.Test

/** Checks the complete ten-era production catalogue and ore-grade substitutions. */
class ProductionExpansionTest {
    @Test fun all143RecipesResolveAndFormValidProductionChains(){
        assertEquals(143,Catalog.recipes.size)
        assertEquals(130,ProductionExpansion.extraMaterials.size)
        assertEquals(394,Catalog.materials.size)
        assertEquals(Catalog.materials.size,Catalog.byId.size)
        assertEquals(143,Catalog.recipes.keys.toSet().size)
        assertEquals((1..10).toList(),
            (1..10).filter{era->Catalog.recipes.values.count{
                it.output.startsWith("epoch_"+era+"_")}==11})
        assertEquals(20,Catalog.recipes.keys.count{it.startsWith("refined_")})
        for((output,recipe) in Catalog.recipes){
            assertEquals(output,recipe.output)
            assertTrue(output in Catalog.byId)
            assertTrue(recipe.seconds>0)
            assertTrue(recipe.ingredients.isNotEmpty())
            for((item,count) in recipe.ingredients){
                assertTrue("Missing ingredient "+item+" for "+output,item in Catalog.byId)
                assertTrue(count>0)
                assertTrue("Recipe tier "+output+" needs later item "+item,
                    Catalog.byId.getValue(item).era<=Catalog.byId.getValue(output).era)
            }
        }
        val allRaw=Catalog.materials.filter{
            it.id.startsWith("ore_") || it.id in Catalog.basicMinerals.map{b->b.id} ||
            it.id in listOf("coal","iron","copper","gold")
        }
        for(material in allRaw){
            assertTrue("Unused mined material: "+material.id,
                Catalog.recipes.values.any{recipe->
                    Catalog.accepts(recipe,material.id)
                })
        }
    }
    @Test fun allTwelveOreGradesAreRealInputsRatherThanLockedToGradeOne(){
        val recipe=Catalog.recipes.getValue("refined_12")
        val quantity=recipe.ingredients.getValue("ore_12_1")
        val inputs=mutableMapOf(
            "ore_12_2" to 2,
            "ore_12_7" to 3,
            "ore_12_12" to (quantity-5),
            "coal" to recipe.ingredients.getValue("coal")
        )
        assertTrue(Catalog.canProduce(recipe,inputs))
        assertEquals(quantity,Catalog.available(inputs,"ore_12_1"))
        assertTrue(Catalog.consumeIngredients(recipe,inputs))
        assertEquals(0,Catalog.available(inputs,"ore_12_1"))
        assertEquals(0,inputs["coal"])
        assertFalse(Catalog.canProduce(recipe,inputs))
        assertFalse(Catalog.acceptsIngredient("ore_12_1","ore_1_12"))
    }
    @Test fun eraRulesActuallyBlockFutureEquipment(){
        val game=GameEngine.newGame(72723L)
        val lot=game.city(1).lots.first{it.kind==BuildingKind.FACTORY}
        assertTrue(game.purchaseFactory(1,lot.id))
        assertEquals("brick",game.company(1).factories.getValue(lot.id).recipeId)
        assertTrue(game.setRecipe(1,lot.id,"epoch_1_2"))
        assertFalse(game.setRecipe(1,lot.id,"epoch_2_2"))
        assertFalse(game.setRecipe(1,lot.id,"refined_11"))
        game.state.era=10
        assertTrue(game.setRecipe(1,lot.id,"epoch_10_2"))
    }
    @Test fun realFactoryProducesRefinedOreUsingMixedGrades(){
        val game=GameEngine.newGame(1234L)
        val lot=game.city(1).lots.first{it.kind==BuildingKind.FACTORY}
        assertTrue(game.purchaseFactory(1,lot.id))
        game.state.era=6
        assertTrue(game.setRecipe(1,lot.id,"refined_12"))
        val recipe=Catalog.recipes.getValue("refined_12")
        val inputs=game.company(1).factories.getValue(lot.id).inputs
        val required=recipe.ingredients.getValue("ore_12_1")
        inputs["ore_12_12"]=required
        inputs["coal"]=recipe.ingredients.getValue("coal")
        game.tick(recipe.seconds+3)
        assertEquals(1,game.company(1).storage["refined_12"])
        assertEquals(0,inputs["ore_12_12"])
        game.tick(recipe.seconds+3)
        assertEquals(1,game.company(1).storage["refined_12"])
    }
    @Test fun factoryRoutesAllowAllGradesOfSelectedOreFamily(){
        val game=GameEngine.newGame(1234L)
        val city=game.city(1)
        val factoryLot=city.lots.first{it.kind==BuildingKind.FACTORY}
        val warehouseLot=city.lots.first{it.kind==BuildingKind.WAREHOUSE}
        assertTrue(game.purchaseFactory(1,factoryLot.id))
        game.state.era=6
        assertTrue(game.setRecipe(1,factoryLot.id,"refined_12"))
        val route=TruckRoute(RouteType.WAREHOUSE_FACTORY,1,warehouseLot.id,factoryLot.id,"ore_12_9")
        assertTrue(game.canAssign(route))
        assertFalse(game.canAssign(route.copy(material="ore_1_9")))
    }
}
