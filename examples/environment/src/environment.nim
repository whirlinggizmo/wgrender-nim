## wgrender environment example, in Nim: a port of wgrender's examples/environment.c.
##
## Image-based lighting, background and tone mapping. The material spheres (red
## plastic and gold, roughness 0 to 1 left to right), a normal-mapped sphere and the
## character, lit only by an environment map: no lights, no ambient. Metals reflect the
## environment; rough surfaces blur it.
##
## Keys:
##   E            environment: sunset, studio, none
##   B            background blur: sharp, soft, blurred, off
##   T            tone mapping: Neutral, ACES, none
##   UP / DOWN    exposure (+/- half a stop)
##   LEFT / RIGHT rotate the environment
##   ESC          quit

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

  SpherePath = "models/sphere/sphere.glb"
  CharacterPath = "models/woman_casual/woman_casual.glb"
  NormalMapPath = "textures/tiles_normal.png"

  Columns = 5
  EnvironmentCount = 2
  EnvironmentPaths: array[EnvironmentCount, string] = [
    "environments/venice_sunset_1k.hdr",
    "environments/studio_small_09_1k.hdr",
  ]
  EnvironmentNames: array[EnvironmentCount + 1, string] = ["sunset", "studio", "none"]
  TonemapNames: array[Tonemap, string] = ["none", "Neutral", "ACES"]
  Blurs = [0.0, 0.35, 0.8]

type App = object
  scene: Scene
  camera: Camera3d
  bg, bar: Color
  environments: array[EnvironmentCount, Environment]
  spheres: array[2 * Columns + 1, Model]
  character: Model
  tiles: Material
  environment: int # index, EnvironmentCount = none
  blur: int        # index into Blurs, 3 = no background
  tonemap: Tonemap
  exposure: float
  rotation: float
  time: float

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc applyEnvironment() =
  let env = if g.environment < EnvironmentCount: g.environments[g.environment]
            else: default(Environment)
  g.scene.setEnvironment(env, 1.0, g.rotation)
  g.scene.setBackground((if g.blur < 3: env else: default(Environment)),
                        (if g.blur < 3: Blurs[g.blur] else: 0.0))
  g.scene.setTonemap(g.tonemap, g.exposure)

proc loadEnvironment(index: int) =
  ## a proc of its own, so each callback keeps its own index (a closure made in a loop
  ## would share the loop's)
  load(EnvironmentPaths[index]) do (path: string):
    g.environments[index] = newEnvironment(path) # prepares the lighting: a fraction of a second
    applyEnvironment()

proc createSphere(x, y, r, gr, b, metallic, roughness: float): Model =
  result = newModel()
  let material = newMaterial(MaterialShading.Pbr)
  material.setVec4("base_color", (r, gr, b, 1.0))
  material.setFloat("metallic", metallic)
  material.setFloat("roughness", roughness)
  result.setTransform((x, y, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  result.setMaterial(0, material)
  material.release()
  g.scene.add(result)

proc onInit() =
  const spacing = 1.3
  var n = 0

  setAssetHost(AssetBase)
  g.bg = rgba(20, 22, 28, 255)
  g.bar = rgba(0, 0, 0, 150)
  g.tonemap = Tonemap.Neutral

  g.camera = newCamera3d(Projection.Perspective)
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  for c in 0 ..< Columns:
    let x = (c.float - (Columns - 1) * 0.5) * spacing
    let roughness = c / (Columns - 1)
    g.spheres[n] = createSphere(x, 1.9, 0.8, 0.05, 0.04, 0.0, roughness)
    inc n
    g.spheres[n] = createSphere(x, 0.6, 1.0, 0.77, 0.34, 1.0, roughness)
    inc n
  g.spheres[n] = createSphere(-1.3, -0.7, 0.9, 0.9, 0.9, 0.0, 0.3)
  g.tiles = g.spheres[n].getMaterial(0) # borrowed: the model's own material

  g.character = newModel()
  g.character.setTransform((1.3, -1.3, 0.0), (0.0, 0.4, 0.0), (0.3, 0.3, 0.3))
  g.character.setAnimation(3)
  g.scene.add(g.character)

  applyEnvironment()
  for i in 0 ..< EnvironmentCount: loadEnvironment(i)
  load(SpherePath) do (path: string):
    let mesh = newMesh(path)
    for sphere in g.spheres: sphere.setMesh(mesh)
    mesh.release()
  load(CharacterPath) do (path: string):
    let mesh = newMesh(path)
    g.character.setMesh(mesh)
    mesh.release()
  load(NormalMapPath) do (path: string):
    let texture = newTexture(path)
    g.tiles.setTexture("normal_texture", texture)
    texture.release()

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  var changed = false

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()
  if keys.isPressed(Key.E):
    g.environment = (g.environment + 1) mod (EnvironmentCount + 1)
    changed = true
  if keys.isPressed(Key.B):
    g.blur = (g.blur + 1) mod 4
    changed = true
  if keys.isPressed(Key.T):
    g.tonemap = case g.tonemap
                of Tonemap.Neutral: Tonemap.Aces
                of Tonemap.Aces: Tonemap.None
                of Tonemap.None: Tonemap.Neutral
    changed = true
  if keys.isPressed(Key.Up):
    g.exposure += 0.5
    changed = true
  if keys.isPressed(Key.Down):
    g.exposure -= 0.5
    changed = true
  if keys[Key.Left] >= ButtonState.Pressed:
    g.rotation -= dt
    changed = true
  if keys[Key.Right] >= ButtonState.Pressed:
    g.rotation += dt
    changed = true
  if changed: applyEnvironment()

  g.time += dt
  g.camera.setView(position = (sin(g.time * 0.15) * 7.5, 1.2, cos(g.time * 0.15) * 7.5),
                   target = (0.0, 0.3, 0.0))
  g.character.animate(dt)

  let background = if g.blur < 3: (if g.blur == 0: "sharp" elif g.blur == 1: "soft" else: "blurred")
                   else: "off"
  beginFrame()
  clearBackground(g.bg)
  g.scene.draw()
  drawRectangle(0, 0, getScreenSize().x.int.float, 60, g.bar)
  drawText("wgrender environment lighting (Nim): reflections, background and tone mapping",
           12, 12, 16, ColorRaywhite)
  drawText(&"[E] {EnvironmentNames[g.environment]}   [B] background {background}   " &
           &"[T] tone mapping {TonemapNames[g.tonemap]}   [UP/DOWN] exposure {g.exposure:+.1f} EV",
           12, 36, 16, ColorLightgray)
  endFrame()

when isMainModule:
  initValues(1100, 720, "environment (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
