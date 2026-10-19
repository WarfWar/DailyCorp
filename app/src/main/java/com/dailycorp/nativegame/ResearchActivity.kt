package com.dailycorp.nativegame

import android.app.Activity
import android.app.AlertDialog
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Ten eras, explicit prerequisites, unlockable mining and transport research. */
class ResearchActivity:Activity(){
    private lateinit var game:GameEngine
    private lateinit var root:LinearLayout
    private val background=Color.rgb(10,34,49)
    private fun px(n:Int)=(n*resources.displayMetrics.density).toInt()
    override fun onCreate(savedInstanceState:Bundle?){
        super.onCreate(savedInstanceState)
        game=GameSession.engine ?: run {
            try {
                GameEngine(java.io.ObjectInputStream(openFileInput("dailycorp-native-v1.save"))
                    .use {it.readObject() as GameState})
            } catch (_:Exception){GameEngine.newGame()}
        }
        GameSession.engine=game
        build()
    }
    private fun text(value:String,size:Float,light:Boolean=false):TextView = TextView(this).apply{
        text=value;textSize=size;setTextColor(if(light)Color.rgb(180,211,219) else Color.WHITE)
        setPadding(px(13),px(6),px(11),px(6))
    }
    private fun build(){
        val shell=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(background)}
        shell.addView(text("ИССЛЕДОВАТЕЛЬСКИЙ ЦЕНТР",21f))
        shell.addView(text("Текущая эпоха "+game.state.era+"/10 · "+ScienceTree.eraNames[game.state.era-1]+
            " · Очки науки "+game.state.science,13f,true))
        shell.addView(text("Исследуй технологии последовательно. Горное дело открывает транспорт; новая эпоха требует исследований.",12f,true))
        val scroll=ScrollView(this)
        root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL}
        scroll.addView(root)
        shell.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
        val footer=LinearLayout(this).apply{orientation=LinearLayout.HORIZONTAL;gravity=Gravity.CENTER}
        val next=Button(this).apply{
            text="Следующая эпоха";isAllCaps=false;setTextColor(Color.WHITE)
            backgroundTintList=ColorStateList.valueOf(Color.rgb(25,101,136))
            setOnClickListener {
                val ok=game.buyEra()
                AlertDialog.Builder(this@ResearchActivity)
                    .setMessage(if(ok)"Открыта эпоха "+game.state.era else
                        "Нужно исследование горного дела текущей эпохи, "+
                        (game.state.era*100)+" науки и "+(game.state.era*500)+" ₽")
                    .setPositiveButton("ОК",null).show()
                if(ok)GameSession.save(this@ResearchActivity)
                build()
            }
        }
        footer.addView(next,LinearLayout.LayoutParams(0,px(54),1f))
        val back=Button(this).apply{
            text="← К игре";isAllCaps=false;setTextColor(Color.WHITE)
            backgroundTintList=ColorStateList.valueOf(Color.rgb(41,69,80))
            setOnClickListener{finish()}
        }
        footer.addView(back,LinearLayout.LayoutParams(0,px(54),1f))
        shell.addView(footer)
        setContentView(shell)
        renderTree()
    }
    private fun renderTree(){
        root.removeAllViews()
        val owned=ScienceTree.owned(game.state)
        for(era in 1..10){
            root.addView(text("ЭПОХА "+era+" · "+ScienceTree.eraNames[era-1],16f))
            for(node in ScienceTree.nodes.filter{it.era==era}){
                val unlocked=node.id in owned
                val available=ScienceTree.canUnlock(game.state,node)
                val label=(if(unlocked)"✓  " else if(available)"●  " else "○  ")+
                    node.title+" · "+node.cost+" науки"
                val b=Button(this).apply{
                    text=label;isAllCaps=false;textSize=12f
                    setTextColor(Color.WHITE)
                    backgroundTintList=ColorStateList.valueOf(
                        if(unlocked)Color.rgb(45,116,85) else if(available)Color.rgb(26,105,147)
                        else Color.rgb(47,64,75))
                    setOnClickListener {
                        val prereqs=if(node.requires.isEmpty())"нет" else node.requires.joinToString()
                        val details=node.description+"\nНужна эпоха: "+node.era+
                            "\nСтоимость: "+node.cost+" науки\nЗависимости: "+prereqs
                        AlertDialog.Builder(this@ResearchActivity).setTitle(node.title)
                            .setMessage(details)
                            .setPositiveButton(if(unlocked)"Уже изучено" else "Исследовать"){_,_->
                                if(!unlocked) {
                                    val ok=game.research(node.id)
                                    if(ok)GameSession.save(this@ResearchActivity)
                                    AlertDialog.Builder(this@ResearchActivity)
                                        .setMessage(if(ok)"Исследование завершено" else "Недостаточно науки, эпохи или не выполнены зависимости")
                                        .setPositiveButton("ОК",null).show()
                                    renderTree()
                                }
                            }.setNegativeButton("Назад",null).show()
                    }
                }
                val margin=LinearLayout.LayoutParams(-1,px(54)).apply{
                    leftMargin=px(14);rightMargin=px(14);bottomMargin=px(7)
                }
                root.addView(b,margin)
            }
        }
    }
    override fun onPause(){super.onPause();GameSession.save(this)}
}
