## wgrender model example, in Nim: a port of wgrender's examples/model.c.
##
## Static glTF (cgltf) rendered with a lit/textured pipeline, loaded async and placed in
## the scene. The model handle is made first, then its mesh loads async and is set on
## the model once ready: the model is in the scene at once, and the mesh appears once
## loaded.

import std/math
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (wgrender's tools/serve.py mounts examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  ModelPath = "models/gumshoe/gumshoe.glb"

type App = object
  scene: Scene
  camera: Camera3d
  background: Color
  model: Model
  orbitCamera: bool
  spinModel: bool

var g = App(orbitCamera: true, spinModel: false)

proc newModelFor(meshPath: string): Model =
  let model = newModel() # empty: mesh attached when it loads
  model.setTransform((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  model.setTint(ColorRaywhite)
  # drive skeletal animation if the glTF has any (no-op until the mesh arrives)
  model.setAnimation(3)
  model.setAnimationSpeed(1.0)
  model.setAnimationLoop(true)

  let onReady = proc (path: string) =
    let mesh = newMesh(path)
    model.setMesh(mesh)
    mesh.release() # the model holds its own reference to the mesh
  let onFailed = proc (path: string) = logError("model load failed: " & path)
  if not ensureAssetAsync(meshPath).addTask(onReady, onFailed):
    onFailed(meshPath)
  model

proc onInit() =
  setAssetHost(AssetBase)
  g.background = rgba(30, 32, 40, 255)
  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (8.0, 8.0, 8.0), target = (0.0, 3.0, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  # scenes start unlit: add a sun and some ambient
  let sun = newLight(LightKind.Directional)
  sun.setDirection((-0.6, -1.0, -0.5))
  sun.setIntensity(3.0) # ~pi: a white surface facing the sun shows its full color
  g.scene.add(sun)
  g.scene.setAmbient(ColorWhite, 0.3)
  enableFps(12, 10, 16)

  g.model = newModelFor(ModelPath)
  g.scene.add(g.model)

proc frame(dt, tickFraction: float) =
  let t = getTime()

  # orbit the camera around the model
  if g.orbitCamera:
    g.camera.setView(position = (cos(t * 0.4) * 9.0, 7.0, sin(t * 0.4) * 9.0),
                     target = (0.0, 3.0, 0.0))

  # spin the model in place
  if g.spinModel:
    g.model.setTransform((0.0, 0.0, 0.0), (0.0, t * 0.5, 0.0), (1.0, 1.0, 1.0)) # slow spin
  g.model.animate(dt) # skeletal anim

  beginFrame()
  clearBackground(g.background)

  beginMode3d()
  drawGrid(20, 1.0, ColorDarkgray)
  endMode3d()

  g.scene.draw()

  drawText("wgrender model (Nim): glTF/cgltf", 12, 36, 22, ColorRaywhite)
  drawText((if not g.model.isNone: "gumshoe.glb — skeletal animation (glTF skin)"
            else: "loading model..."), 12, 68, 16, ColorLightgray)

  endFrame()

  when not defined(emscripten): # a web page has nothing to quit to
    if getKeyboardState().isPressed(Key.Escape): requestQuit()

when isMainModule:
  initValues(900, 700, "model (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
