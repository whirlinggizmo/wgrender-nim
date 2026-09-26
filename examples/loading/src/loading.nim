## wgrender loading example, in Nim: a port of wgrender's examples/loading.c.
##
## Loading during gameplay without stalling frames. Loads two environments (~330 ms of
## CPU work each), two models and textures, as one asset group, while a cube spins and
## a graph shows every frame's duration.
##
##   A    load in the background: files are decoded on worker threads and uploaded a
##        few milliseconds per frame, so creating them in the callback is cheap
##   S    load synchronously for comparison: the files are only fetched
##        (AssetFlag.FileOnly) and created in the group's callback, in one frame
##   U    unload
##   ESC  quit
##
## Starts with a background load.

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

  Environments = 2
  Meshes = 2
  Textures = 2
  Files = Environments + Meshes + Textures
  Graph = 300

  Paths: array[Files, string] = [
    "environments/venice_sunset_1k.hdr",
    "environments/studio_small_09_1k.hdr",
    "models/woman_casual/woman_casual.glb",
    "models/sphere/sphere.glb",
    "textures/tiles_normal.png",
    "sprites/logo/wg-logo-white-alpha.png",
  ]

type App = object
  scene: Scene
  camera: Camera3d
  background, bar, graphOk, graphSlow, line, cube: Color
  character, sphere: Model
  material: Material
  group: AssetTask
  sync: bool                     # the load in progress creates everything in its group callback
  paths: array[Files, string]    # local paths, from the members' callbacks
  environments: array[Environments, Environment]
  meshes: array[Meshes, Mesh]
  textures: array[Textures, Texture]
  loaded: bool
  loadStarted, loadSeconds, createMs: float
  lastTime: float
  frameMs: array[Graph, float]
  frameNext: int
  time: float

var g: App

proc releaseAll() =
  g.scene.setEnvironment(default(Environment), 1.0, 0.0)
  g.scene.setBackground(default(Environment), 0.0)
  g.character.setMesh(default(Mesh))
  g.sphere.setMesh(default(Mesh))
  g.material.setTexture("normal_texture", default(Texture))
  for environment in g.environments.mitems:
    if not environment.isNone: environment.release()
    environment = default(Environment)
  for mesh in g.meshes.mitems:
    if not mesh.isNone: mesh.release()
    mesh = default(Mesh)
  for texture in g.textures.mitems:
    if not texture.isNone: texture.release()
    texture = default(Texture)
  g.loaded = false

proc createAll() =
  ## Create every resource from its local path and use them. In a background load each
  ## create finds the resource the pipeline already prepared.
  let start = getTime()
  for i in 0 ..< Environments: g.environments[i] = newEnvironment(g.paths[i])
  for i in 0 ..< Meshes: g.meshes[i] = newMesh(g.paths[Environments + i])
  for i in 0 ..< Textures: g.textures[i] = newTexture(g.paths[Environments + Meshes + i])
  g.createMs = (getTime() - start) * 1000.0

  g.scene.setEnvironment(g.environments[0], 1.0, 0.0)
  g.scene.setBackground(g.environments[0], 0.3)
  g.character.setMesh(g.meshes[0])
  g.sphere.setMesh(g.meshes[1])
  g.material.setTexture("normal_texture", g.textures[0])
  g.loaded = true

proc onFile(index: int): AssetCallback =
  ## a member's callback: keep its local path
  result = proc (path: string) = g.paths[index] = path

proc onGroupDone(path: string) =
  g.group = default(AssetTask)
  createAll()
  g.loadSeconds = getTime() - g.loadStarted

proc onGroupFailed(path: string) =
  g.group = default(AssetTask)
  logError("loading: some files failed")

proc startLoad(sync: bool) =
  if not g.group.isNone: return # one load at a time
  releaseAll()
  g.sync = sync
  g.loadStarted = getTime()
  for ms in g.frameMs.mitems: ms = 0.0 # "worst" covers this load
  g.createMs = 0.0
  g.group = newAssetGroup()
  for i in 0 ..< Files:
    let task = ensureAssetAsync(Paths[i], flags = (if sync: {AssetFlag.FileOnly} else: {}))
    task.addTask(onFile(i))
    g.group.add(task)
  g.group.addTask(onGroupDone, onGroupFailed)

proc onInit() =
  setAssetHost(AssetBase)
  setAssetManifest(AssetManifestName)
  g.background = rgba(20, 22, 28, 255)
  g.bar = rgba(0, 0, 0, 170)
  g.graphOk = rgba(90, 200, 120, 255)
  g.graphSlow = rgba(235, 80, 70, 255)
  g.line = rgba(255, 255, 255, 90)
  g.cube = rgba(230, 180, 60, 255)

  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (0.0, 1.0, 5.5), target = (0.0, 0.6, 0.0))
  g.camera.setActive()
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  g.character = newModel()
  g.character.setTransform((-1.2, 0.0, 0.0), (0.0, 0.4, 0.0), (0.5, 0.5, 0.5))
  g.character.setAnimation(3)
  g.scene.add(g.character)

  g.sphere = newModel()
  g.sphere.setTransform((1.2, 0.8, 0.0), (0.0, 0.0, 0.0), (0.8, 0.8, 0.8))
  g.material = newMaterial(MaterialShading.Pbr)
  g.material.setVec4("base_color", (0.9, 0.9, 0.9, 1.0))
  g.material.setFloat("roughness", 0.25)
  g.sphere.setMaterial(0, g.material)
  g.scene.add(g.sphere)

  g.lastTime = getTime()
  startLoad(false)

proc drawGraph(x, y, width, height: int) =
  const maxMs = 100.0
  let bar = width / Graph
  var worst = 0.0

  drawRectangle(x.float, y.float, width.float, height.float, g.bar)
  for i in 0 ..< Graph:
    let ms = g.frameMs[(g.frameNext + i) mod Graph]
    let h = int(height.float * min(ms, maxMs) / maxMs)
    if h > 0:
      drawRectangle(float(x + int(i.float * bar)), float(y + height - h),
                    (if bar > 1.0: float(int(bar)) else: 1.0), h.float,
                    if ms > 34.0: g.graphSlow else: g.graphOk)
    worst = max(ms, worst)
  let lineY = float(y + height - int(height.float * 16.7 / maxMs)) # a 60 Hz frame
  drawLine((x.float, lineY), (float(x + width), lineY), g.line)

  drawText(&"frame times, 0-100 ms (line: 16.7 ms)   worst: {int(round(worst))} ms",
           x + 6, y + 6, 10, ColorLightgray)

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  let screen = getScreenSize()
  let now = getTime()

  g.frameMs[g.frameNext] = (now - g.lastTime) * 1000.0 # real time, uncapped
  g.frameNext = (g.frameNext + 1) mod Graph
  g.lastTime = now

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()
  if keys.isPressed(Key.A): startLoad(false)
  if keys.isPressed(Key.S): startLoad(true)
  if keys.isPressed(Key.U) and g.group.isNone: releaseAll()

  g.time += dt
  g.character.animate(dt)

  beginFrame()
  clearBackground(g.background)
  g.scene.draw()
  beginMode3d()
  drawCubeWires((0.0, 1.9 + 0.1 * sin(g.time * 3.0), 0.0), (0.5, 0.5, 0.5), g.cube)
  endMode3d()

  drawRectangle(0, 0, float(int(screen.x)), 64, g.bar)
  drawText("wgrender loading (Nim)   A: in the background   S: synchronously   U: unload", 12, 12, 12,
           ColorRaywhite)
  # "in the background" means worker threads, and a web build only has them on a
  # cross-origin-isolated page. Without them the decode lands on this thread and the
  # graph below says so, so the example had better not claim otherwise.
  drawText(getRenderer() & "  ·  decoding on " &
           (if hasThreads(): "worker threads" else: "the main thread (no threads in this build/host)"),
           12, 26, 12, if hasThreads(): ColorLightgray else: ColorGold)
  if not g.group.isNone:
    let progress = g.group.getProgress()
    let how = if g.sync: "synchronously"
              elif hasThreads(): "in the background"
              else: "in the background, but on this thread"
    drawRectangle(12, 54, float(int(240 * progress)), 12, g.graphOk)
    drawRectangleLines(12, 54, 240, 12, g.line)
    drawText(&"loading ({how})... {int(round(progress * 100))}%", 264, 54, 12, ColorLightgray)
  elif g.loaded:
    let how = if g.sync: "synchronously"
              elif hasThreads(): "in the background"
              else: "without threads"
    drawText(&"loaded {Files} files {how} in {g.loadSeconds:.2f} s; creating them took {int(round(g.createMs))} ms",
             12, 54, 12, ColorLightgray)
  drawGraph(12, int(screen.y) - 132, int(screen.x) - 24, 120)
  endFrame()

when isMainModule:
  initValues(1100, 720, "loading (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
