package com.dailycorp.nativegame

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/** Connected climatic regions, instead of independently randomized terrain tiles.
 * Pure JVM: no graphics libraries, safe to regenerate from each city's stable seed.
 */
enum class Biome {
    OCEAN, COAST, PLAINS, FOREST, MOUNTAINS, SNOW, DESERT, SWAMP, LAKE, RIVER
}

object BiomeGenerator {
    private fun hash(x:Int,y:Int,seed:Long):Double {
        var n=seed xor (x.toLong()*0x4F1BBCDCBFA54029L) xor (y.toLong()*0x369DEA0F31A53F85L)
        n=(n xor (n ushr 30))* -4658895280553007687L
        n=(n xor (n ushr 27))* -7723592293110705685L
        n=n xor (n ushr 31)
        return ((n ushr 11).toDouble()/9007199254740992.0)*2.0-1.0
    }
    private fun smooth(v:Double):Double=v*v*(3.0-2.0*v)
    private fun mix(a:Double,b:Double,t:Double)=a+(b-a)*t
    private fun noise(x:Double,y:Double,seed:Long):Double {
        val ix=floor(x).toInt();val iy=floor(y).toInt()
        val tx=smooth(x-ix);val ty=smooth(y-iy)
        return mix(
            mix(hash(ix,iy,seed),hash(ix+1,iy,seed),tx),
            mix(hash(ix,iy+1,seed),hash(ix+1,iy+1,seed),tx),ty)
    }
    private fun fractal(x:Double,y:Double,seed:Long):Double {
        var sum=0.0;var amplitude=0.55;var f=1.0
        repeat(4) {
            sum+=noise(x*f,y*f,seed+it*0x1F12E285A35B4D61L)*amplitude
            amplitude*=0.48;f*=2.0
        }
        return sum
    }
    private fun landBiome(elevation:Double,wet:Double,temperature:Double):Biome =
        when {
            elevation>=0.73 && temperature<0.43 -> Biome.SNOW
            elevation>=0.66 -> Biome.MOUNTAINS
            temperature<0.30 && elevation>0.45 -> Biome.SNOW
            elevation<0.36 && wet>0.74 -> Biome.LAKE
            elevation<0.42 && wet>0.60 -> Biome.SWAMP
            wet<0.33 && temperature>0.53 -> Biome.DESERT
            wet>0.49 -> Biome.FOREST
            else -> Biome.PLAINS
        }

    /** 40x34 city terrain is a crop from large continuous noise fields. */
    fun city(seed:Long,x:Int,y:Int):Biome {
        val shiftX=(seed and 255L).toDouble()*0.19
        val shiftY=((seed ushr 9) and 255L).toDouble()*0.19
        val fx=x.toDouble()+shiftX
        val fy=y.toDouble()+shiftY
        val elevation=(0.49+fractal(fx/25.0,fy/25.0,seed xor 0x298F013149C31DE9L)*0.49)
            .coerceIn(0.0,1.0)
        val humidity=(0.50+fractal(fx/20.0,fy/20.0,seed xor 0x20F23BFCC1DFABD1L)*0.58)
            .coerceIn(0.0,1.0)
        val temp=(0.58+fractal(fx/38.0,fy/38.0,seed xor 0x237610EACF92D47DL)*0.38)
            .coerceIn(0.0,1.0)
        return landBiome(elevation,humidity,temp)
    }

    private fun riverX(seed:Long,y:Int,width:Int,offset:Int):Double {
        val bend=fractal(y/32.0+offset*0.41,offset*1.47,seed xor 0x617931D5790CE1A9L)
        return width*(if(offset==0)0.33 else 0.67)+bend*width*0.16
    }
    /** For display only. Ocean follows a noisy coast, rivers meander continuously;
     * the fixed 48-city economic layout remains backward compatible.
     */
    fun world(seed:Long,x:Int,y:Int,width:Int=96,height:Int=72):Biome {
        val px=(x-width*0.51)/(width*0.48)
        val py=(y-height*0.50)/(height*0.46)
        val coastDist=hypot(px*0.89,py*1.07)
        val deformation=fractal(x/23.0,y/23.0,seed xor 0x658E716D7DEFB9F5L)
        val land=1.02-coastDist+deformation*0.36
        if(land < -0.035) return Biome.OCEAN
        if(land<0.055)return Biome.COAST

        val elevation=(0.48+fractal(x/27.0,y/27.0,seed xor 0x3715A93FBE4DDF27L)*0.53)
            .coerceIn(0.0,1.0)
        val humidity=(0.50+fractal(x/19.0,y/19.0,seed xor 0x147AC1A8FA602A5DL)*0.53)
            .coerceIn(0.0,1.0)
        val temperature=(0.78-abs(y-height*0.53)/height*0.82+
            fractal(x/32.0,y/32.0,seed xor 0x15A8F31274157CBFL)*0.15)
            .coerceIn(0.0,1.0)

        if(land > 0.11 && elevation<0.68 &&
            ((abs(x-riverX(seed,y,width,0))<1.45 && y>height*0.23) ||
             (abs(x-riverX(seed,y,width,1))<1.2 && y<height*0.74)))
            return Biome.RIVER
        return landBiome(elevation,humidity,temperature)
    }

    fun tint(biome:Biome):Int=when(biome) {
        Biome.OCEAN -> 0xFF286E9B.toInt()
        Biome.COAST -> 0xFFD2C58C.toInt()
        Biome.PLAINS -> 0xFF79B86F.toInt()
        Biome.FOREST -> 0xFF327C56.toInt()
        Biome.MOUNTAINS -> 0xFF8D978E.toInt()
        Biome.SNOW -> 0xFFE4EBE5.toInt()
        Biome.DESERT -> 0xFFD8B978.toInt()
        Biome.SWAMP -> 0xFF608D70.toInt()
        Biome.LAKE, Biome.RIVER -> 0xFF3D9ECC.toInt()
    }
    fun decoration(biome:Biome):String?=when(biome){
        Biome.FOREST->"continent.forest"
        Biome.MOUNTAINS->"continent.mountains"
        Biome.SNOW->"continent.snow"
        Biome.DESERT->"continent.desert"
        Biome.SWAMP->"continent.swamp"
        Biome.LAKE->"continent.lake"
        Biome.RIVER->"continent.river"
        Biome.COAST->"continent.beach"
        else->null
    }
}
