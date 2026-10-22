package com.dailycorp.nativegame

import android.content.Context
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.util.Base64
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Native OpenGL ES 2.0 renderer for the City 001 GLB scene.
 * The mesh contains real 3D geometry (POSITION/COLOR_0/indices), not a map PNG.
 * Lot tapping is mapped to the existing City.lots saved ID by kind + ordinal.
 * This is opt-in; original MapCanvasView and every saved game remain untouched.
 */
class City3DPreviewView(
    context: Context,
    private val engine: GameEngine,
    private val onLotTap: (Lot) -> Unit
) : GLSurfaceView(context) {
    private val sceneRenderer = SceneRenderer(context)
    private var dragging = false
    private var lastX = 0f
    private var lastY = 0f
    private val density = resources.displayMetrics.density
    private val pinch = ScaleGestureDetector(context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                sceneRenderer.distance = (sceneRenderer.distance / detector.scaleFactor)
                    .coerceIn(65f, 245f)
                requestRender()
                return true
            }
        })

    init {
        setEGLContextClientVersion(2)
        preserveEGLContextOnPause = true
        setRenderer(sceneRenderer)
        renderMode = RENDERMODE_WHEN_DIRTY
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        pinch.onTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                lastX = event.x; lastY = event.y; dragging = false; return true
            }
            MotionEvent.ACTION_POINTER_DOWN -> { dragging = true; return true }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.x - lastX
                val dy = event.y - lastY
                if (!pinch.isInProgress && event.pointerCount == 1) {
                    if (hypot(dx,dy) > 1.5f * density) dragging = true
                    if (dragging) {
                        sceneRenderer.azimuth -= dx * .006f
                        sceneRenderer.elevation = (sceneRenderer.elevation + dy * .004f)
                            .coerceIn(.30f, 1.33f)
                        requestRender()
                    }
                }
                lastX = event.x; lastY = event.y
                return true
            }
            MotionEvent.ACTION_UP -> {
                if (!dragging && !pinch.isInProgress) {
                    val s = sceneRenderer.closestSite(event.x, event.y, width, height)
                    if (s != null) {
                        val lot = engine.city(1).lots.filter { it.kind.name == s.kind }
                            .getOrNull(s.ordinal)
                        if (lot != null) onLotTap(lot)
                    }
                }
                return true
            }
        }
        return true
    }

    private data class Site3D(val kind: String, val ordinal: Int,
                              val x: Float, val y: Float, val z: Float)
    private data class Mesh3D(val vertices: FloatBuffer, val indices: ShortBuffer,
                              val indexCount: Int)

    private inner class SceneRenderer(private val ctx: Context) : GLSurfaceView.Renderer {
        @Volatile var azimuth = .77f
        @Volatile var elevation = .76f
        @Volatile var distance = 146f
        @Volatile private var lastProjection = FloatArray(16)
        @Volatile private var sites: List<Site3D> = emptyList()
        private var meshes: List<Mesh3D> = emptyList()
        private var program = 0
        private var posLoc = -1
        private var colorLoc = -1
        private var mvpLoc = -1
        private var w = 1
        private var h = 1

        override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
            GLES20.glClearColor(.075f, .17f, .22f, 1f)
            GLES20.glEnable(GLES20.GL_DEPTH_TEST)
            GLES20.glDepthFunc(GLES20.GL_LEQUAL)
            val vertexShader = compileShader(GLES20.GL_VERTEX_SHADER, """
                uniform mat4 uMVP;
                attribute vec3 aPosition;
                attribute vec3 aColor;
                varying vec3 vColor;
                void main() {
                    gl_Position = uMVP * vec4(aPosition, 1.0);
                    vColor = aColor;
                }
            """.trimIndent())
            val fragmentShader = compileShader(GLES20.GL_FRAGMENT_SHADER, """
                precision mediump float;
                varying vec3 vColor;
                void main() { gl_FragColor = vec4(vColor, 1.0); }
            """.trimIndent())
            program = GLES20.glCreateProgram()
            GLES20.glAttachShader(program, vertexShader)
            GLES20.glAttachShader(program, fragmentShader)
            GLES20.glLinkProgram(program)
            val linked = IntArray(1)
            GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linked, 0)
            check(linked[0] == GLES20.GL_TRUE) { "3D shader link failed" }
            posLoc = GLES20.glGetAttribLocation(program,"aPosition")
            colorLoc = GLES20.glGetAttribLocation(program,"aColor")
            mvpLoc = GLES20.glGetUniformLocation(program,"uMVP")
            meshes = loadGlb(ctx)
            val json = JSONObject(ctx.assets.open("dailycorp/3d/city001_scene.json")
                .bufferedReader().use { it.readText() })
            val parsed = mutableListOf<Site3D>()
            val nodes = json.getJSONArray("sites")
            for (i in 0 until nodes.length()) {
                val site = nodes.getJSONObject(i)
                parsed.add(Site3D(site.getString("kind"), site.getInt("ordinal"),
                    site.getDouble("x").toFloat(), site.getDouble("y").toFloat(),
                    site.getDouble("z").toFloat()))
            }
            sites = parsed
        }

        override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
            w = max(1,width); h = max(1,height)
            GLES20.glViewport(0,0,w,h)
        }

        override fun onDrawFrame(gl: GL10?) {
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
            if(program == 0) return
            val projection = FloatArray(16)
            val view = FloatArray(16)
            val mvp = FloatArray(16)
            Matrix.perspectiveM(projection,0,46f,w.toFloat()/h, .8f,550f)
            val horiz = distance * cos(elevation)
            Matrix.setLookAtM(view,0,
                horiz*sin(azimuth), distance*sin(elevation)+4f,
                horiz*cos(azimuth), 0f,5f,0f, 0f,1f,0f)
            Matrix.multiplyMM(mvp,0,projection,0,view,0)
            lastProjection = mvp
            GLES20.glUseProgram(program)
            GLES20.glUniformMatrix4fv(mvpLoc,1,false,mvp,0)
            GLES20.glEnableVertexAttribArray(posLoc)
            GLES20.glEnableVertexAttribArray(colorLoc)
            for(mesh in meshes) {
                mesh.vertices.position(0)
                GLES20.glVertexAttribPointer(posLoc,3,GLES20.GL_FLOAT,false,24,mesh.vertices)
                mesh.vertices.position(3)
                GLES20.glVertexAttribPointer(colorLoc,3,GLES20.GL_FLOAT,false,24,mesh.vertices)
                mesh.indices.position(0)
                GLES20.glDrawElements(GLES20.GL_TRIANGLES, mesh.indexCount,
                    GLES20.GL_UNSIGNED_SHORT,mesh.indices)
            }
            GLES20.glDisableVertexAttribArray(posLoc)
            GLES20.glDisableVertexAttribArray(colorLoc)
        }

        /** Tap a 3D site by its projected world position, never by image pixels. */
        fun closestSite(px: Float, py: Float, width: Int, height: Int): Site3D? {
            val m = lastProjection
            if(m.size != 16 || height < 1) return null
            var best: Site3D? = null
            var bestDistance = 45f * density
            for(site in sites) {
                val inp = floatArrayOf(site.x,site.y+2.8f,site.z,1f)
                val pos = FloatArray(4)
                Matrix.multiplyMV(pos,0,m,0,inp,0)
                if(pos[3] <= .01f) continue
                val sx = (pos[0]/pos[3]*.5f+.5f)*width
                val sy = (1f-(pos[1]/pos[3]*.5f+.5f))*height
                val diff = hypot(px-sx, py-sy)
                if(diff < bestDistance) {bestDistance=diff;best=site}
            }
            return best
        }

        private fun compileShader(type: Int, text: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader,text)
            GLES20.glCompileShader(shader)
            val status = IntArray(1)
            GLES20.glGetShaderiv(shader,GLES20.GL_COMPILE_STATUS,status,0)
            check(status[0] == GLES20.GL_TRUE) { GLES20.glGetShaderInfoLog(shader) }
            return shader
        }
    }

    /** Tiny offline subset of glTF 2.0; supports our indexed colored static GLB. */
    private fun loadGlb(context: Context): List<Mesh3D> {
        val encoded=context.assets.open("dailycorp/3d/city001_v0_1.glb.b64")
            .bufferedReader().use { it.readText().trim() }
        val data=Base64.decode(encoded,Base64.DEFAULT)
        val bytes=ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        check(bytes.getInt(0)==0x46546c67 && bytes.getInt(4)==2) { "Invalid GLB header" }
        val jsonSize=bytes.getInt(12)
        check(bytes.getInt(16)==0x4e4f534a) { "Missing glTF JSON chunk" }
        val jsonText=String(data,20,jsonSize,Charsets.UTF_8).trimEnd('\u0000',' ')
        val json=JSONObject(jsonText)
        val binaryChunkOffset=20+jsonSize+8
        check(bytes.getInt(20+jsonSize+4)==0x004e4942) { "Missing glTF BIN chunk" }
        val accessors=json.getJSONArray("accessors")
        val bufferViews=json.getJSONArray("bufferViews")
        fun accessorRange(id:Int):Pair<Int,JSONObject> {
            val a=accessors.getJSONObject(id)
            val bv=bufferViews.getJSONObject(a.getInt("bufferView"))
            val start=binaryChunkOffset+bv.optInt("byteOffset",0)+a.optInt("byteOffset",0)
            return Pair(start,a)
        }
        val result=mutableListOf<Mesh3D>()
        val meshDefs=json.getJSONArray("meshes")
        for(mi in 0 until meshDefs.length()) {
            val mesh=meshDefs.getJSONObject(mi)
            val prims=mesh.getJSONArray("primitives")
            for(pi in 0 until prims.length()) {
                val p=prims.getJSONObject(pi)
                if (p.optInt("mode",4)!=4)continue
                val attributes=p.getJSONObject("attributes")
                val (pOff,pAcc)=accessorRange(attributes.getInt("POSITION"))
                val color=attributes.optInt("COLOR_0",-1)
                val colRange=if(color>=0) accessorRange(color) else null
                val count=pAcc.getInt("count")
                check(count<=65535) { "GLB mesh exceeds GLES2 index limit" }
                val interleaved=ByteBuffer.allocateDirect(count*6*4)
                    .order(ByteOrder.nativeOrder()).asFloatBuffer()
                for(i in 0 until count) {
                    for(k in 0..2) interleaved.put(bytes.getFloat(pOff+i*12+k*4))
                    if(colRange!=null) {
                        val (offset,colorAccessor)=colRange
                        // glTF normalized unsigned byte RGBA, 4 bytes/vertex.
                        check(colorAccessor.getInt("componentType")==5121)
                        for(k in 0..2)
                            interleaved.put((bytes.get(offset+i*4+k).toInt() and 255)/255f)
                    } else {interleaved.put(0.7f);interleaved.put(0.7f);interleaved.put(0.7f)}
                }
                interleaved.position(0)
                val (iOff,iAcc)=accessorRange(p.getInt("indices"))
                val n=iAcc.getInt("count")
                val typ=iAcc.getInt("componentType")
                check(typ==5125 || typ==5123) { "Unsupported GLB index type" }
                val indices=ByteBuffer.allocateDirect(n*2)
                    .order(ByteOrder.nativeOrder()).asShortBuffer()
                for(i in 0 until n) {
                    val id=if(typ==5125)bytes.getInt(iOff+i*4) else bytes.getShort(iOff+i*2).toInt() and 65535
                    check(id in 0 until count) { "Invalid GLB mesh index" }
                    indices.put(id.toShort())
                }
                indices.position(0)
                result.add(Mesh3D(interleaved,indices,n))
            }
        }
        return result
    }
}