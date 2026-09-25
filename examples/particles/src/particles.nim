## wgrender particles example, in Nim: a port of wgrender's examples/particles.c.
##
## 3D emitters in a scene: a fountain (blended drops under gravity), sparks (added,
## from a point circling the fountain: they trail behind it, are thrown along by it,
## slowed by drag and stretched along their motion), and a campfire: flames (added
## puffs from a flipbook texture, colored by a curve) under smoke (blended, with size
## and color curves: a dark puff that spreads, lightens and fades as it rises). The
## steady ones are prewarmed, so they're already going when they appear. Click or tap
## anywhere for a 2D confetti burst there: squares cut from the middle of the particle
## texture (so their spin shows), each tinted by a color picked from the emitter's
## palette. Space pauses the steady emitters; the particles alive finish their lives.
## The camera turns slowly around the scene (O stops and restarts it).

import std/[math, strformat]
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (tools/serve.py mounts wgrender's examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  ParticlePath = "textures/particle.png"
  FlamePath = "textures/flame.png" # a 4x4 flipbook (wgrender's tools/gen_particles.py)

  OrbitRadius = 16.0
  OrbitSpeed = 0.15 # radians per second

type
  App = object
    scene: Scene
    camera: Camera3d
    fountain, sparks, smoke, flame: Emitter3d
    confetti: Emitter2d
    paused: bool
    time: float
    orbit: bool
    orbitAngle: float # radians around the fountain; holds while the orbit is stopped

var g = App(orbit: true)

proc makeFountain(texture: Texture) =
  g.fountain = newEmitter3d(texture)
  g.fountain.setMax(4096)
  g.fountain.setRate(1200)
  g.fountain.setLife(1.4, 1.9)
  g.fountain.setPosition(0, 0.2, 0)
  g.fountain.setSpawnBox((0.15, 0.0, 0.15))
  g.fountain.setVelocity((0.0, 9.0, 0.0), spread = 0.22, speedVariance = 0.15)
  g.fountain.setGravity((0.0, -9.8, 0.0))
  g.fountain.setSize(0.22, 0.12, 0.4)
  g.fountain.setColor(rgba(150, 210, 255, 230), rgba(60, 120, 255, 0))
  g.fountain.setAlphaMode(AlphaMode.Blend)
  g.fountain.prewarm(2.0) # already running when the page opens
  g.scene.add(g.fountain)

proc makeSparks(texture: Texture) =
  g.sparks = newEmitter3d(texture)
  g.sparks.setMax(2048)
  g.sparks.setRate(600)
  g.sparks.setLife(0.5, 1.2)
  g.sparks.setVelocity((0.0, 4.0, 0.0), spread = 1.2, speedVariance = 0.6)
  g.sparks.setGravity((0.0, -6.0, 0.0))
  g.sparks.setDrag(1.5)            # they slow down
  g.sparks.setInheritVelocity(0.4) # thrown along by the moving source
  g.sparks.setStretch(0.04)        # streaks along their motion
  g.sparks.setSize(0.08, 0.02, 0.5)
  g.sparks.setColor(rgba(255, 220, 120, 255), rgba(255, 60, 10, 0))
  # AlphaMode.Add is the default
  g.scene.add(g.sparks)

proc makeSmoke(texture: Texture) =
  g.smoke = newEmitter3d(texture)
  g.smoke.setMax(512)
  g.smoke.setRate(30)
  g.smoke.setLife(3.0, 4.5)
  g.smoke.setPosition(-5, 1.5, -2) # above the fire
  g.smoke.setSpawnSphere(0.3)
  g.smoke.setVelocity((0.0, 1.4, 0.0), spread = 0.35, speedVariance = 0.3)
  g.smoke.setGravity((0.35, 0.0, 0.0)) # a breeze
  g.smoke.setSpin(-0.8, 0.8)
  # curves: a quick puff that keeps spreading; dark, then light, then gone
  g.smoke.clearSizeKeys()
  g.smoke.addSizeKey(0.0, 0.3)
  g.smoke.addSizeKey(0.15, 1.4)
  g.smoke.addSizeKey(1.0, 3.6)
  g.smoke.clearColorKeys()
  g.smoke.addColorKey(0.0, rgba(40, 36, 34, 0))
  g.smoke.addColorKey(0.1, rgba(50, 46, 44, 190))
  g.smoke.addColorKey(0.5, rgba(130, 130, 140, 120))
  g.smoke.addColorKey(1.0, rgba(170, 170, 180, 0))
  g.smoke.setAlphaMode(AlphaMode.Blend)
  g.smoke.prewarm(5.0)
  g.scene.add(g.smoke)

# A campfire's flames: puffs from a flipbook, played once over each one's life, glowing
# white-yellow, then orange, red and out as they rise and break up.
proc makeFlame(texture: Texture) =
  g.flame = newEmitter3d(texture)
  g.flame.setFrames(4, 4)
  g.flame.setRate(40)
  g.flame.setLife(0.7, 1.1)
  g.flame.setPosition(-5, 0.3, -2)
  g.flame.setSpawnSphere(0.3)
  g.flame.setVelocity((0.0, 1.8, 0.0), spread = 0.2, speedVariance = 0.3)
  g.flame.setDrag(0.8)
  g.flame.setSpin(-1.5, 1.5)
  g.flame.clearSizeKeys()
  g.flame.addSizeKey(0.0, 0.6)
  g.flame.addSizeKey(0.3, 1.1)
  g.flame.addSizeKey(1.0, 0.4)
  g.flame.clearColorKeys()
  g.flame.addColorKey(0.0, rgba(255, 235, 190, 0))
  g.flame.addColorKey(0.08, rgba(255, 235, 190, 110))
  g.flame.addColorKey(0.25, rgba(255, 150, 40, 100))
  g.flame.addColorKey(0.65, rgba(200, 50, 15, 60))
  g.flame.addColorKey(1.0, rgba(80, 15, 5, 0))
  g.flame.prewarm(1.0)
  g.scene.add(g.flame) # added: AlphaMode.Add, the default

proc makeConfetti(texture: Texture) =
  g.confetti = newEmitter2d(texture)
  g.confetti.setSource(24, 24, 16, 16) # the dot's solid middle: squares
  g.confetti.setMax(4096)
  g.confetti.setLife(1.2, 2.2)
  g.confetti.setVelocity((0.0, -420.0), spread = 1.3, speedVariance = 0.7)
  g.confetti.setGravity((0.0, 700.0))
  g.confetti.setDrag(0.8) # flutters down instead of dropping
  g.confetti.setSize(12, 6, 0.5)
  g.confetti.setSpin(-8, 8)
  g.confetti.setColor(ColorWhite, rgba(255, 255, 255, 0))
  # each piece picks one of these at birth
  for color in [ColorRed, ColorGold, ColorLime, ColorSkyblue, ColorViolet]:
    g.confetti.addPaletteColor(color)
  g.confetti.setAlphaMode(AlphaMode.Blend)
  g.scene.add(g.confetti, layer = 1)

proc burstConfetti(x, y: float) =
  g.confetti.jump(x, y)
  g.confetti.burst(300)

proc load(path: string; onReady: proc (texture: Texture)) =
  let onFailed = proc (path: string) = logError("asset load failed: " & path)
  let onLoaded = proc (path: string) =
    let texture = newTexture(path)
    if texture.isNone: return
    onReady(texture)
    texture.release() # each emitter holds its own reference
  if not ensureAssetAsync(path).addTask(onLoaded, onFailed):
    onFailed(path)

proc onInit() =
  setAssetHost(AssetBase)

  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (0.0, 6.0, 16.0), target = (0.0, 3.0, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  load(ParticlePath) do (texture: Texture):
    makeFountain(texture)
    makeSparks(texture)
    makeSmoke(texture)
    makeConfetti(texture)
    let screen = getScreenSize()
    burstConfetti(screen.x * 0.5, screen.y * 0.4) # one to start with
  load(FlamePath) do (texture: Texture):
    makeFlame(texture)
  enableFps(12, 10, 16)

proc setPaused(paused: bool) =
  g.paused = paused
  for emitter in [g.fountain, g.sparks, g.smoke, g.flame]:
    emitter.setEmitting(not paused)

proc frame(dt, tickFraction: float) =
  g.time += dt
  if not g.sparks.isNone:
    # the sparks' source circles the fountain; the sparks stay where they were born
    g.sparks.setPosition(3.5 * cos(g.time * 1.3), 1.5 + 0.8 * sin(g.time * 2.1),
                         3.5 * sin(g.time * 1.3))

  let mouse = getMouseState()
  if mouse.left == ButtonState.Pressed and not g.confetti.isNone:
    burstConfetti(mouse.x.float, mouse.y.float)
  if isKeyPressed(Key.Space) and not g.fountain.isNone:
    setPaused(not g.paused)
  if isKeyPressed(Key.O):
    g.orbit = not g.orbit
  if g.orbit:
    g.orbitAngle += dt * OrbitSpeed
  g.camera.setView(position = (OrbitRadius * sin(g.orbitAngle), 6.0, OrbitRadius * cos(g.orbitAngle)),
                   target = (0.0, 3.0, 0.0))

  beginFrame()
  clearBackground(rgba(14, 16, 24, 255))

  beginMode3d()
  drawGrid(24, 1.0, ColorDarkgray)
  endMode3d()

  g.scene.draw()

  drawText("wgrender particles (Nim)", 12, 36, 24, ColorRaywhite)
  drawText(&"""click / tap: confetti   space: {(if g.paused: "resume" else: "pause")}   """ &
           &"""O: {(if g.orbit: "stop" else: "turn")} the camera""", 12, 70, 16, ColorLightgray)
  drawText(&"fountain {g.fountain.getCount}   sparks {g.sparks.getCount}   " &
           &"flame {g.flame.getCount}   smoke {g.smoke.getCount}   confetti {g.confetti.getCount}",
           12, 94, 16, ColorLightgray)

  endFrame()

  # Escape quits on desktop; a web page has nothing to quit to.
  when not defined(emscripten):
    if isKeyPressed(Key.Escape):
      requestQuit()

when isMainModule:
  initValues(1000, 700, "particles (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
