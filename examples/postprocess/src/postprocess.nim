## wgrender postprocess example, in Nim: a port of wgrender's examples/postprocess.c.
##
## Post-processing: screen effects over the finished frame. The frame is an ordinary
## lit scene (an animated gumshoe on a floor, generated shapes, a circling point
## light). The effects are custom materials whose shaders are screen effects
## (wgrender's examples/shaders/vignette.glsl and scanlines.glsl, compiled by its
## tools/shaderpack.py; tools/gen_shaders.py --examples):
##
##   - the vignette darkens the corners and warms the middle
##   - the scanlines darken alternating rows, shift red and blue apart and flicker
##
## Both apply in the order they were added, so turning one off and on rebuilds the
## chain (clearEffects, then addEffect again). Their parameters are ordinary material
## parameters, so they can change any frame — here the vignette breathes in and out,
## and the arrow keys change how dark it gets.
##
## Keys: 1 vignette, 2 scanlines, UP/DOWN vignette strength, SPACE stop the breathing,
## O stop the camera, ESC quit.

import std/[math, strformat]
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (wgrender's tools/serve.py mounts examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  GumshoePath = "models/gumshoe/gumshoe.glb"
  VignettePath = "shaders/vignette.wgrshader"
  ScanlinesPath = "shaders/scanlines.wgrshader"

  ShapeCount = 3

type App = object
  scene: Scene
  camera: Camera3d
  gumshoe: Model
  lamp: Light
  lampMarker: Shape3d
  shapes: array[ShapeCount, Model]
  vignette, scanlines: Material # the effect materials (none until they load)
  vignetteOn, scanlinesOn, breathing, orbit: bool
  strength: float # the vignette's, before breathing
  angle, time: float

var g = App(vignetteOn: true, scanlinesOn: false, breathing: true, orbit: true, strength: 0.85)

proc rebuildEffects() =
  ## The chain, in order: the vignette darkens the corners, then the scanlines go over
  ## everything. Rebuilt whenever one is switched on or off.
  clearEffects()
  if g.vignetteOn and not g.vignette.isNone: addEffect(g.vignette)
  if g.scanlinesOn and not g.scanlines.isNone: addEffect(g.scanlines)

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc onInit() =
  # the shapes beside the gumshoe, and their colors
  let shapes = [
    (mesh: newMeshSphere(0.5, 24, 48), x: -2.2, y: 0.5, r: 0.2, gr: 0.55, b: 0.9),
    (mesh: newMeshTorus(0.45, 0.16, 48, 24), x: 2.2, y: 0.7, r: 0.95, gr: 0.6, b: 0.25),
    (mesh: newMeshCube(0.8, 0.8, 0.8), x: 3.6, y: 0.4, r: 0.35, gr: 0.85, b: 0.5),
  ]
  setAssetHost(AssetBase)

  g.camera = newCamera3d(Projection.Perspective)
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  g.scene.setAmbient(rgba(90, 110, 160, 255), 0.12)

  let sun = newLight(LightKind.Directional)
  sun.setDirection((-0.4, -1.0, -0.5))
  sun.setColor(rgba(255, 215, 170, 255))
  sun.setIntensity(2.2)
  g.scene.add(sun)

  g.lamp = newLight(LightKind.Point)
  g.lamp.setColor(rgba(80, 220, 255, 255))
  g.lamp.setIntensity(18.0)
  g.lamp.setRange(6.0)
  g.scene.add(g.lamp)
  g.lampMarker = newShape3d()
  g.lampMarker.setSphere(0.1)
  g.lampMarker.setColor(rgba(80, 220, 255, 255))
  g.scene.add(g.lampMarker)

  let plane = newMeshPlane(16.0, 16.0, 0)
  let floor = newModel(plane)
  plane.release()
  let ground = newMaterial(MaterialShading.Pbr)
  ground.setVec4("base_color", (0.07, 0.07, 0.08, 1.0))
  ground.setFloat("roughness", 0.85)
  floor.setMaterial(-1, ground)
  ground.release()
  g.scene.add(floor)

  for i, shape in shapes:
    let material = newMaterial(MaterialShading.Pbr)
    g.shapes[i] = newModel(shape.mesh)
    shape.mesh.release()
    g.shapes[i].setTransform((shape.x, shape.y, -0.6), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
    material.setVec4("base_color", (shape.r, shape.gr, shape.b, 1.0))
    material.setFloat("roughness", 0.4)
    g.shapes[i].setMaterial(0, material)
    material.release()
    g.scene.add(g.shapes[i])

  g.gumshoe = newModel()
  g.gumshoe.setTransform((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.scene.add(g.gumshoe)

  load(GumshoePath) do (path: string):
    let mesh = newMesh(path)
    g.gumshoe.setMesh(mesh)
    mesh.release() # the model holds its own reference
    g.gumshoe.setAnimation(3)
    g.gumshoe.setAnimationLoop(true)
  load(VignettePath) do (path: string):
    let shader = newShader(path)
    g.vignette = newMaterial(shader)
    shader.release() # the material holds its own reference
    g.vignette.setFloat("strength", g.strength)
    g.vignette.setFloat("radius", 0.25)
    g.vignette.setVec4("tint", (1.04, 1.0, 0.94, 1.0))
    rebuildEffects()
  load(ScanlinesPath) do (path: string):
    let shader = newShader(path)
    g.scanlines = newMaterial(shader)
    shader.release()
    g.scanlines.setFloat("lines", 220.0)
    g.scanlines.setFloat("darkness", 0.35)
    g.scanlines.setFloat("offset", 1.5)
    g.scanlines.setFloat("flicker", 1.0)
    rebuildEffects()
  enableFps(12, 10, 16)

proc onOff(on: bool): string = (if on: "on" else: "off")

proc frame(dt, tickFraction: float) =
  when not defined(emscripten): # a web page has nothing to quit to
    if isKeyPressed(Key.Escape): requestQuit()
  if isKeyPressed(Key.Digit1):
    g.vignetteOn = not g.vignetteOn
    rebuildEffects()
  if isKeyPressed(Key.Digit2):
    g.scanlinesOn = not g.scanlinesOn
    rebuildEffects()
  if isKeyPressed(Key.Space): g.breathing = not g.breathing
  if isKeyPressed(Key.O): g.orbit = not g.orbit
  if getKey(Key.Up) != ButtonState.Up: g.strength = min(g.strength + dt, 1.0)
  if getKey(Key.Down) != ButtonState.Up: g.strength = max(g.strength - dt, 0.0)

  g.time += dt
  g.gumshoe.animate(dt)
  if g.orbit: g.angle += dt * 0.25
  g.camera.setView(position = (9.0 * sin(g.angle), 3.2, 9.0 * cos(g.angle)),
                   target = (0.0, 1.0, 0.0))
  let lampX = 3.0 * sin(g.time * 0.9)
  let lampZ = 2.2 + 1.2 * cos(g.time * 0.9)
  g.lamp.setPosition(lampX, 1.4, lampZ)
  g.lampMarker.setTransform((lampX, 1.4, lampZ), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.shapes[1].setTransform((2.2, 0.7, -0.6), (0.0, g.time * 40.0, g.time * 25.0), (1.0, 1.0, 1.0))

  # the effect's parameters are the material's: change them any frame
  let strength = if g.breathing: g.strength * (0.55 + 0.45 * sin(g.time * 0.8)) else: g.strength
  if not g.vignette.isNone: g.vignette.setFloat("strength", strength)

  beginFrame()
  clearBackground(rgba(16, 18, 24, 255))
  g.scene.draw()
  drawText("wgrender post-processing (Nim): screen effects over the finished frame", 12, 36, 20,
           ColorRaywhite)
  drawText(&"[1] vignette {g.vignetteOn.onOff}   [2] scanlines {g.scanlinesOn.onOff}   " &
           &"effects: {getEffectCount()}", 12, 64, 16, ColorLightgray)
  drawText(&"UP/DOWN strength {g.strength:.2f}   SPACE " &
           (if g.breathing: "stop breathing" else: "breathe") & "   O camera   ESC quit",
           12, 86, 16, ColorGray)
  endFrame()

when isMainModule:
  initValues(1000, 600, "postprocess (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
