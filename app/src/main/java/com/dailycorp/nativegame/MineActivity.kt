package com.dailycorp.nativegame

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.graphics.Color
import android.content.res.ColorStateList
import android.view.Gravity
import android.widget.Button
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/** Playable cross-section: mark ore or rock for miners, watch carts return to the shaft. */
class MineActivity : Activity() {
    private lateinit var engine: GameEngine
    private lateinit var mineView: MineCanvasView
    private lateinit var information: TextView
    private var cityId = 1
    private var lotId = -1
    private val handler = Handler(Looper.getMainLooper())
    private val update = object:Runnable {
        override fun run() {
            if (::mineView.isInitialized) { updateInfo(); mineView.invalidate() }
            handler.postDelayed(this,800)
        }
    }
    private fun px(n:Int) = (n*resources.displayMetrics.density).toInt()
    private fun action(label:String,block:()->Unit):Button = Button(this).apply {
        text=label; textSize=11f; isAllCaps=false; setTextColor(Color.WHITE)
        backgroundTintList=ColorStateList.valueOf(Color.rgb(28,107,145))
        minWidth=px(98); minHeight=px(48);setOnClickListener{block()}
    }
    override fun onCreate(savedInstanceState:Bundle?) {
        super.onCreate(savedInstanceState)
        cityId=intent.getIntExtra("cityId",GameSession.cityId)
        lotId=intent.getIntExtra("lotId",GameSession.mineLotId)
        engine=GameSession.engine ?: run {
            try {
                val old=java.io.ObjectInputStream(openFileInput("dailycorp-native-v1.save"))
                    .use {it.readObject() as GameState}
                GameEngine(old)
            } catch (_:Exception){GameEngine.newGame()}
        }
        GameSession.engine=engine
        val mine=engine.company(cityId).mines[lotId]
        if(mine==null){finish();return}
        val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(Color.rgb(10,35,51))}
        val title=TextView(this).apply{
            text="ШАХТА №"+(lotId+1)+"  ·  ПОДЗЕМНЫЕ РАБОТЫ"
            setTextColor(Color.WHITE);textSize=17f;gravity=Gravity.CENTER_VERTICAL
            setPadding(px(12),0,0,0)
        }
        root.addView(title,LinearLayout.LayoutParams(-1,px(50)))
        information=TextView(this).apply{
            setTextColor(Color.rgb(192,221,226));textSize=11f
            setPadding(px(12),px(3),px(6),px(3))
        }
        root.addView(information,LinearLayout.LayoutParams(-1,px(63)))
        mineView=MineCanvasView(this,engine,cityId,lotId)
        mineView.onCellTap={x,y->
            val done=engine.dig(cityId,lotId,x,y)
            if(!done) Toast.makeText(this,"Можно выбирать только породу и рудные жилы",Toast.LENGTH_SHORT).show()
            else GameSession.save(this)
            updateInfo();mineView.invalidate()
        }
        root.addView(mineView,LinearLayout.LayoutParams(-1,0,1f))
        val scroll=HorizontalScrollView(this)
        scroll.isHorizontalScrollBarEnabled=false
        val bar=LinearLayout(this).apply{orientation=LinearLayout.HORIZONTAL}
        fun control(title:String,onClick:()->Boolean) {
            bar.addView(action(title){
                val success=onClick()
                Toast.makeText(this,if(success)"Готово" else "Проверь деньги, лимит или условия",Toast.LENGTH_SHORT).show()
                if(success)GameSession.save(this)
                updateInfo();mineView.invalidate()
            },LinearLayout.LayoutParams(-2,px(52)))
        }
        control("＋ Шахтёр"){engine.hireMiner(cityId,lotId)}
        control("＋ Вагонетка"){engine.buyMineCart(cityId,lotId)}
        control("Буровая ↑"){engine.improveDrill(cityId,lotId)}
        control("Вагонетка ↑"){engine.improveMineCart(cityId,lotId)}
        control("Этаж ↑"){engine.selectMineFloor(cityId,lotId,MineWorld.interior(mine).activeFloor-1)}
        control("Этаж ↓"){engine.selectMineFloor(cityId,lotId,MineWorld.interior(mine).activeFloor+1)}
        control("Углубить шахту"){engine.deepenMine(cityId,lotId)}
        bar.addView(action("На поверхность"){finish()},LinearLayout.LayoutParams(-2,px(52)))
        scroll.addView(bar)
        root.addView(scroll,LinearLayout.LayoutParams(-1,px(62)))
        setContentView(root)
        updateInfo()
        handler.postDelayed(update,800)
    }
    private fun updateInfo() {
        val mine=engine.company(cityId).mines[lotId]?:return
        val underground=MineWorld.interior(mine)
        val floor=engine.mineFloor(cityId,lotId)?:return
        val orders=floor.blocks.sumOf{r->r.count{it.ordered}}
        information.text="Этаж "+underground.activeFloor+"/"+mine.depth+" · Открыто "+underground.unlockedFloor+
            " · Шахтёры "+floor.workers.size+" · Вагонетки "+floor.carts.size+
            "\nНа погрузке "+mine.loading.values.sum()+" · Руда в тоннелях "+floor.piles.sumOf{it.amount}+
            " · Разработано "+floor.excavated+" клеток · Задач "+orders+
            "\nНажми на породу: рабочие проложат проход; вагонетки вывезут руду."
    }
    override fun onPause(){super.onPause();GameSession.save(this)}
    override fun onDestroy(){handler.removeCallbacks(update);super.onDestroy()}
}
