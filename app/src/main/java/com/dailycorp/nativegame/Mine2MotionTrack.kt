package com.dailycorp.nativegame

/** Constant-speed interpolation for a half-second mining tick.
 * Unlike smoothstep, linear interpolation never brakes/restarts at each tile.
 */
class Mine2MotionTrack(x:Float,y:Float,private val durationMs:Long=515L){
    private var fromX=x
    private var fromY=y
    private var toX=x
    private var toY=y
    private var startedAt=0L
    fun position(now:Long):AnimatedPoint{
        val t=((now-startedAt).toFloat()/durationMs.toFloat()).coerceIn(0f,1f)
        return AnimatedPoint(fromX+(toX-fromX)*t,fromY+(toY-fromY)*t)
    }
    fun target(x:Float,y:Float,now:Long){
        if(x==toX && y==toY)return
        val current=position(now)
        fromX=current.x;fromY=current.y
        toX=x;toY=y
        startedAt=now
    }
    fun moving(now:Long):Boolean=
        (fromX!=toX || fromY!=toY) && now-startedAt<durationMs
}
