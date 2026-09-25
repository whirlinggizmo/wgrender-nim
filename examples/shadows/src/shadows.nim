## wgrender shadows example, in Nim: a port of wgrender's examples/shadows.c.
##
## A casting light and what it does to a scene. The sun casts (setCastsShadows): once
## a frame it draws everything that casts into a depth map, and the lit shading darkens
## what's behind something. The scene is a floor, a wall, some generated shapes and an
## animated woman, so the shadows fall across each other and across themselves.
##
##   - 1 turns the sun's casting on and off, the difference this whole feature makes
##   - 2 does the same for a spot light circling the scene, which casts through its own
##     cone: two lights casting at once, a layer of the shadow map each
##   - the ball on the left doesn't cast (setCastsShadow), so it floats like everything
##     did before shadows; the one on the right doesn't receive (setReceivesShadow), so
##     the wall's shadow passes over it
##   - UP/DOWN change the shadow distance: less distance covers less of the scene with
##     the same map, so the shadows get sharper
##   - [ and ] change the depth bias: too little stripes the lit surfaces ("acne"),
##     too much lifts a shadow away from what casts it
##   - M cycles the map size (512, 1024, 2048, 4096)
##   - S changes how much light a shadow blocks, and T tints what it leaves behind
##
## Keys: 1 sun shadows, 2 spot shadows, UP/DOWN distance, [ ] bias, M map size,
## S strength, T tint, O camera, ESC quit.

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

  WomanCasualPath = "models/woman_casual/woman_casual.glb"

  MapSizes = [512, 1024, 2048, 4096]

  # what a shadow keeps of the light: nothing (physical), then two stylised tints
  Tints: array[3, Color] = [0x000000FF'u32, 0x1E3C64FF'u32, 0x64321EFF'u32]
  TintNames = ["none", "cool", "warm"]

type App = object
  scene: Scene
  camera: Camera3d
  sun, spot: Light
  spotMarker: Shape3d
  womanCasual: Model
  noCast, noReceive: Model
  shadows, spotShadows, orbit: bool
  distance, bias, strength: float
  sizeIndex, tintIndex: int
  angle, time: float

var g = App(shadows: true, spotShadows: true, orbit: true, distance: 30.0, bias: 1.0,
            strength: 1.0, sizeIndex: 1)

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc place(mesh: Mesh; x, y, z, r, gr, b, roughness: float): Model =
  ## A model of `mesh` at (x, y, z) in one color, added to the scene.
  result = newModel(mesh)
  let material = newMaterial(MaterialShading.Pbr)
  mesh.release() # the model holds it
  result.setTransform((x, y, z), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  material.setVec4("base_color", (r, gr, b, 1.0))
  material.setFloat("metallic", 0.0)
  material.setFloat("roughness", roughness)
  result.setMaterial(-1, material)
  material.release()
  g.scene.add(result)

proc onInit() =
  setAssetHost(AssetBase)

  g.camera = newCamera3d(Projection.Perspective)
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  g.scene.setAmbient(rgba(140, 170, 225, 255), 0.25)

  g.sun = newLight(LightKind.Directional)
  g.sun.setDirection((-0.75, -0.85, -0.35))
  g.sun.setColor(rgba(255, 244, 224, 255))
  g.sun.setIntensity(3.2)
  g.sun.setCastsShadows(true)
  g.sun.setShadowDistance(g.distance)
  g.sun.setShadowMapSize(MapSizes[g.sizeIndex])
  g.sun.setShadowStrength(g.strength)
  g.sun.setShadowColor(Tints[g.tintIndex])
  g.scene.add(g.sun)

  # a second caster: a spot light that circles the scene and shadows through its own
  # cone. Both share the map, so both use the same size
  g.spot = newLight(LightKind.Spot)
  g.spot.setColor(rgba(150, 210, 255, 255))
  g.spot.setIntensity(260.0)
  g.spot.setRange(24.0)
  g.spot.setSpotCone(0.30, 0.44)
  g.spot.setCastsShadows(true)
  g.spot.setShadowMapSize(MapSizes[g.sizeIndex])
  g.spot.setShadowDistance(24.0)
  g.scene.add(g.spot)
  g.spotMarker = newShape3d()
  g.spotMarker.setSphere(0.16)
  g.spotMarker.setColor(rgba(150, 210, 255, 255))
  g.scene.add(g.spotMarker)

  discard place(newMeshPlane(40.0, 40.0, 0), 0, 0, 0, 0.42, 0.44, 0.46, 0.9)
  # a wall to throw a long shadow across the floor
  discard place(newMeshCube(0.5, 3.0, 7.0), -4.5, 1.5, 0, 0.55, 0.5, 0.45, 0.85)
  discard place(newMeshTorus(0.7, 0.22, 48, 24), 2.6, 1.1, -1.6, 0.9, 0.55, 0.2, 0.4)
  discard place(newMeshCapsule(0.4, 1.6, 16, 32), 1.2, 0.8, 1.8, 0.35, 0.75, 0.45, 0.5)
  discard place(newMeshCube(1.0, 1.0, 1.0), 3.8, 0.5, 1.4, 0.3, 0.5, 0.85, 0.6)

  # one that casts nothing, and one that nothing shadows
  g.noCast = place(newMeshSphere(0.6, 24, 48), -2.0, 0.6, 2.4, 0.95, 0.85, 0.3, 0.35)
  g.noCast.setCastsShadow(false)
  g.noReceive = place(newMeshSphere(0.6, 24, 48), -2.6, 0.6, -1.2, 0.9, 0.3, 0.5, 0.35)
  g.noReceive.setReceivesShadow(false)

  g.womanCasual = newModel()
  g.womanCasual.setTransform((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.scene.add(g.womanCasual)
  load(WomanCasualPath) do (path: string):
    let mesh = newMesh(path)
    g.womanCasual.setMesh(mesh)
    mesh.release()
    g.womanCasual.setAnimation(3)
    g.womanCasual.setAnimationLoop(true)
  enableFps(12, 10, 16)

proc onOff(on: bool): string = (if on: "on" else: "off")

proc frame(dt, tickFraction: float) =
  when not defined(emscripten): # a web page has nothing to quit to
    if isKeyPressed(Key.Escape): requestQuit()
  if isKeyPressed(Key.Digit1):
    g.shadows = not g.shadows
    g.sun.setCastsShadows(g.shadows)
  if isKeyPressed(Key.Digit2):
    g.spotShadows = not g.spotShadows
    g.spot.setCastsShadows(g.spotShadows)
  if isKeyPressed(Key.O): g.orbit = not g.orbit
  if isKeyPressed(Key.S):
    g.strength = if g.strength > 0.9: 0.65 elif g.strength > 0.5: 0.35 else: 1.0
    g.sun.setShadowStrength(g.strength)
  if isKeyPressed(Key.T):
    g.tintIndex = (g.tintIndex + 1) mod Tints.len
    g.sun.setShadowColor(Tints[g.tintIndex])
  if isKeyPressed(Key.M):
    g.sizeIndex = (g.sizeIndex + 1) mod MapSizes.len
    g.sun.setShadowMapSize(MapSizes[g.sizeIndex])
    g.spot.setShadowMapSize(MapSizes[g.sizeIndex])
  if getKey(Key.Up) != ButtonState.Up or getKey(Key.Down) != ButtonState.Up:
    let step = if getKey(Key.Up) != ButtonState.Up: dt * 20.0 else: -dt * 20.0
    g.distance = max(2.0, min(g.distance + step, 200.0))
    g.sun.setShadowDistance(g.distance)
  if getKey(Key.LeftBracket) != ButtonState.Up or getKey(Key.RightBracket) != ButtonState.Up:
    let step = if getKey(Key.RightBracket) != ButtonState.Up: dt * 4.0 else: -dt * 4.0
    g.bias = max(0.0, min(g.bias + step, 16.0))
    g.sun.setShadowBias(g.bias, g.bias * 4.0)

  g.time += dt
  g.womanCasual.animate(dt)
  # the spot circles overhead, always aimed at the middle of the scene
  let sx = 7.0 * sin(g.time * 0.35)
  let sz = 7.0 * cos(g.time * 0.35)
  g.spot.setPosition(sx, 6.5, sz)
  g.spot.setDirection((-sx, -6.5, -sz))
  g.spotMarker.setTransform((sx, 6.5, sz), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  if g.orbit: g.angle += dt * 0.18
  g.camera.setView(position = (11.0 * sin(g.angle), 5.0, 11.0 * cos(g.angle)),
                   target = (0.0, 1.2, 0.0))

  beginFrame()
  clearBackground(rgba(120, 150, 200, 255))
  g.scene.draw()
  drawText("wgrender shadows (Nim): a directional light casting into a depth map", 12, 36, 20,
           ColorRaywhite)
  drawText(&"[1] sun {g.shadows.onOff}   [2] spot {g.spotShadows.onOff}   map {MapSizes[g.sizeIndex]}   " &
           &"distance {int(round(g.distance))}   bias {g.bias:.1f} texels", 12, 64, 16, ColorLightgray)
  drawText(&"[S] strength {g.strength:.2f}   [T] tint {TintNames[g.tintIndex]}", 12, 86, 16,
           ColorLightgray)
  drawText("UP/DOWN distance   [ ] bias   M map size   O camera   ESC quit", 12, 108, 16, ColorGray)
  drawText("left ball casts nothing; right ball receives nothing", 12, 130, 16, ColorGray)
  endFrame()

when isMainModule:
  initValues(1000, 600, "shadows (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
