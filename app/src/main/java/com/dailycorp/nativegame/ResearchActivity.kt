package com.dailycorp.nativegame

import android.app.Activity
import android.app.AlertDialog
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Readable technology tree: 80 large cards, branch prerequisites, expandable eras. */
class ResearchActivity : Activity() {
    private lateinit var game:GameEngine
    private lateinit var list:LinearLayout
    private lateinit var scroll:ScrollView
    private lateinit var status:TextView
    private val expanded=mutableSetOf<Int>()
    private val backgroundColor=Color.rgb(10,34,49)
    private val pale=Color.rgb(189,221,226)
    private fun px(n:Int)=(n*resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState:Bundle?) {
        super.onCreate(savedInstanceState)
        game=GameSession.engine ?: run {
            try {
                GameEngine(java.io.ObjectInputStream(openFileInput("dailycorp-native-v1.save"))
                    .use {it.readObject() as GameState})
            } catch (_:Exception){GameEngine.newGame()}
        }
        GameSession.engine=game
        expanded.add(game.state.era)
        build()
    }
    private fun label(value:String,size:Float,color:Int=Color.WHITE,bold:Boolean=false):TextView =
        TextView(this).apply{
            text=value;textSize=size;setTextColor(color)
            if(bold)typeface=Typeface.DEFAULT_BOLD
            includeFontPadding=true
        }
    private fun surface(fill:Int,border:Int,radius:Int=15):GradientDrawable =
        GradientDrawable().apply{
            cornerRadius=px(radius).toFloat()
            setColor(fill);setStroke(px(2),border)
        }
    private fun button(value:String,action:()->Unit):Button = Button(this).apply {
        text=value;isAllCaps=false;textSize=15f
        setTextColor(Color.WHITE)
        backgroundTintList=ColorStateList.valueOf(Color.rgb(29,100,132))
        setOnClickListener{action()}
    }
    private fun build(){
        val shell=LinearLayout(this).apply{
            orientation=LinearLayout.VERTICAL
            setBackgroundColor(backgroundColor)
        }
        val header=LinearLayout(this).apply{
            orientation=LinearLayout.VERTICAL
            setPadding(px(17),px(16),px(16),px(13))
            setBackgroundColor(Color.rgb(14,49,67))
        }
        header.addView(label("ИССЛЕДОВАТЕЛЬСКИЙ ЦЕНТР",24f,Color.WHITE,true))
        status=label("",16f,pale,true)
        status.setPadding(0,px(9),0,px(8))
        header.addView(status)
        header.addView(label(
            "80 исследований · 8 отраслей в каждой эпохе · нажми на узел, чтобы открыть технологию.",
            14f,pale))
        val commands=LinearLayout(this).apply{
            orientation=LinearLayout.HORIZONTAL
            setPadding(0,px(13),0,0)
        }
        commands.addView(button("Текущая эпоха"){
            expanded.clear();expanded.add(game.state.era)
            renderTree()
            scroll.smoothScrollTo(0,0)
        },LinearLayout.LayoutParams(0,px(52),1f))
        commands.addView(button("Развернуть все"){
            if(expanded.size==10)expanded.clear()
            else expanded.addAll(1..10)
            renderTree()
        },LinearLayout.LayoutParams(0,px(52),1f))
        header.addView(commands)
        shell.addView(header)
        scroll=ScrollView(this).apply{isFillViewport=false}
        list=LinearLayout(this).apply{
            orientation=LinearLayout.VERTICAL
            setPadding(px(12),px(12),px(12),px(22))
        }
        scroll.addView(list)
        shell.addView(scroll,LinearLayout.LayoutParams(-1,0,1f))
        val footer=LinearLayout(this).apply{
            orientation=LinearLayout.HORIZONTAL
            setPadding(px(8),px(6),px(8),px(7))
        }
        footer.addView(button("Следующая эпоха"){
            val ok=game.buyEra()
            if(ok) {
                GameSession.save(this)
                expanded.add(game.state.era)
            }
            AlertDialog.Builder(this)
                .setTitle(if(ok)"Эпоха открыта" else "Условия перехода")
                .setMessage(if(ok)"Переход в "+ScienceTree.eraNames[game.state.era-1]
                    else "Изучи горное дело текущей эпохи, накопи "+
                    (game.state.era*100)+" науки и "+(game.state.era*500)+" ₽.")
                .setPositiveButton("ОК",null).show()
            renderTree()
        },LinearLayout.LayoutParams(0,px(57),1f))
        footer.addView(button("← К городу"){finish()},
            LinearLayout.LayoutParams(0,px(57),1f))
        shell.addView(footer)
        setContentView(shell)
        renderTree()
    }
    private fun renderTree(){
        val oldY=scroll.scrollY
        list.removeAllViews()
        val owned=ScienceTree.owned(game.state)
        status.text="Эпоха "+game.state.era+"/10  ·  "+ScienceTree.eraNames[game.state.era-1]+
            "\nОчки науки: "+game.state.science+"  ·  Открыто: "+owned.size+"/"+ScienceTree.nodes.size
        for(era in 1..10){
            val eraNodes=ScienceTree.nodes.filter{it.era==era}
            val finished=eraNodes.count{it.id in owned}
            val open=era in expanded
            val unlocked=era<=game.state.era
            val title=label(
                (if(open)"▼ " else "▶ ")+"ЭПОХА "+era+" — "+ScienceTree.eraNames[era-1]+
                    "  ("+finished+"/"+eraNodes.size+")",
                18f,if(unlocked)Color.WHITE else pale,true)
            title.gravity=Gravity.CENTER_VERTICAL
            title.setPadding(px(14),px(7),px(11),px(7))
            title.background=surface(if(unlocked)Color.rgb(27,80,106) else Color.rgb(32,55,68),
                if(unlocked)Color.rgb(73,149,179) else Color.rgb(52,80,94))
            title.setOnClickListener{
                if(open)expanded.remove(era) else expanded.add(era)
                renderTree()
            }
            val eraLp=LinearLayout.LayoutParams(-1,px(67)).apply{
                topMargin=px(8);bottomMargin=px(10)
            }
            list.addView(title,eraLp)
            if(!open)continue
            for((index,node) in eraNodes.withIndex()){
                val complete=node.id in owned
                val accessible=ScienceTree.canUnlock(game.state,node)
                val locked=era>game.state.era
                val fill=when {
                    complete -> Color.rgb(27,81,67)
                    accessible -> Color.rgb(19,82,120)
                    locked -> Color.rgb(32,43,52)
                    else -> Color.rgb(38,60,74)
                }
                val edge=when {
                    complete -> Color.rgb(68,181,126)
                    accessible -> Color.rgb(87,180,216)
                    else -> Color.rgb(81,106,119)
                }
                val nodeCard=LinearLayout(this).apply{
                    orientation=LinearLayout.VERTICAL
                    gravity=Gravity.CENTER_VERTICAL
                    setPadding(px(18),px(13),px(14),px(12))
                    background=surface(fill,edge,17)
                    isClickable=true;isFocusable=true
                }
                val nodeTitle=label((if(complete)"✓  " else if(accessible)"●  " else "○  ")+
                    node.title,18f,Color.WHITE,true)
                nodeCard.addView(nodeTitle)
                val subtitle=label(node.description,14f,pale)
                subtitle.setPadding(0,px(5),0,0)
                nodeCard.addView(subtitle)
                val prerequisites=node.requires.map{ScienceTree.byId[it]?.title ?: it}
                val requirement=when {
                    complete -> "ИССЛЕДОВАНО"
                    locked -> "Нужна эпоха "+node.era
                    prerequisites.isEmpty() -> "Без предварительных исследований"
                    else -> "Требуется: "+prerequisites.joinToString(" • ")
                }
                val detail=label(node.cost.toString()+" науки  ·  "+requirement,
                    13f,if(complete)Color.rgb(142,224,179) else Color.rgb(230,206,143))
                detail.setPadding(0,px(8),0,0)
                nodeCard.addView(detail)
                nodeCard.setOnClickListener{openResearch(node)}
                val lp=LinearLayout.LayoutParams(-1,-2).apply{
                    leftMargin=px(9);rightMargin=px(9);bottomMargin=px(3)
                }
                nodeCard.minimumHeight=px(118)
                list.addView(nodeCard,lp)
                if(index<eraNodes.lastIndex){
                    val connector=View(this).apply{setBackgroundColor(Color.rgb(67,133,155))}
                    list.addView(connector,LinearLayout.LayoutParams(px(3),px(18)).apply{
                        gravity=Gravity.CENTER_HORIZONTAL
                    })
                }
            }
        }
        scroll.post{scroll.scrollTo(0,oldY)}
    }
    private fun openResearch(node:Technology){
        val completed=node.id in ScienceTree.owned(game.state)
        val prereq=node.requires.map{ScienceTree.byId[it]?.title ?: it}
        val details=node.description+"\n\nЭпоха: "+node.era+
            "\nЦена: "+node.cost+" науки\nПредпосылки: "+
            (if(prereq.isEmpty())"Нет" else prereq.joinToString("\n• ","• "))+
            "\nДоступно науки: "+game.state.science
        AlertDialog.Builder(this)
            .setTitle(node.title)
            .setMessage(details)
            .setPositiveButton(if(completed)"Изучено" else "Исследовать"){_,_->
                if(!completed){
                    val success=game.research(node.id)
                    if(success)GameSession.save(this)
                    AlertDialog.Builder(this)
                        .setMessage(if(success)"Исследование завершено."
                            else "Недостаточно науки, эпохи или не открыты необходимые технологии.")
                        .setPositiveButton("ОК",null).show()
                    renderTree()
                }
            }.setNegativeButton("Назад",null).show()
    }
    override fun onPause(){super.onPause();GameSession.save(this)}
}
