## wgrender instancing example, in Nim: a port of wgrender's examples/instancing.c.
##
## Many models that share a mesh and a material. Nothing here asks for instancing: it
## is what wgrender does when models agree on everything but where they stand
## (docs/PLAN-instancing.md). A field of cubes shares one mesh and one material and
## differs only in transform and tint, so it is one draw; six women share the same
## asset and animate out of step, so their joints are per instance; a few cubes are
## see-through, and those keep their back-to-front order. The sun casts, so the same
## batching happens again into its shadow map: 400 cubes and six walkers go into it as
## two draws, and every shadow lands under its own model. Press Space to give every
## cube its own material instead, which is the same picture drawn one cube at a time.

import std/math
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (tools/serve.py mounts wgrender's examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  ModelPath = "models/woman_casual/woman_casual.glb"
  FieldSide = 20
  FieldCount = FieldSide * FieldSide
  Walkers = 6
  Glass = 5

type App = object
  scene: Scene
  camera: Camera3d
  cubes: array[FieldCount, Model]
  walkers: array[Walkers, Model]
  glass: array[Glass, Model]
  sharedMaterial: Material
  ownMaterials: bool

var g: App

proc loadMeshInto(model: Model) =
  let onReady = proc (path: string) =
    let mesh = newMesh(path) # the same resource for every walker
    model.setMesh(mesh)
    mesh.release()
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(ModelPath).addTask(onReady, onFailed):
    onFailed(ModelPath)

proc fieldTint(i: int; alpha: int): Color =
  let hue = i.float / FieldCount.float
  rgba(int(120 + 135 * sin(hue * 6.28)), int(120 + 135 * sin(hue * 6.28 + 2.1)),
       int(120 + 135 * sin(hue * 6.28 + 4.2)), alpha)

proc setMaterials(own: bool) =
  ## One material for every cube, or one each: the same picture, batched or not.
  for cube in g.cubes:
    if own:
      let material = newMaterial(MaterialShading.Pbr)
      material.setFloat("roughness", 0.5)
      cube.setMaterial(-1, material)
      material.release() # the model keeps its reference
    else:
      cube.setMaterial(-1, g.sharedMaterial)
  g.ownMaterials = own

proc onInit() =
  setAssetHost(AssetBase)
  g.camera = newCamera3d(Projection.Perspective)
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  let sun = newLight(LightKind.Directional)
  sun.setDirection((-0.5, -1.0, -0.4))
  sun.setIntensity(3.0)
  sun.setShadowDistance(60.0)
  sun.setCastsShadows(true) # the depth pass batches the same way
  g.scene.add(sun)
  g.scene.setAmbient(rgba(160, 180, 220, 255), 0.35)
  enableFps(12, 10, 16)

  # something for the shadows to land on
  let floorMesh = newMeshPlane(60.0, 60.0, 0)
  let floorMaterial = newMaterial(MaterialShading.Pbr)
  floorMaterial.setVec4("base_color", (0.45, 0.47, 0.5, 1.0))
  floorMaterial.setFloat("roughness", 0.9)
  let floor = newModel(floorMesh)
  floor.setMaterial(-1, floorMaterial)
  floor.setTransform((0.0, -0.6, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.scene.add(floor)
  floorMesh.release()
  floorMaterial.release()

  # the field: one mesh, one material, a tint each
  let cube = newMeshCube(0.6, 0.6, 0.6)
  g.sharedMaterial = newMaterial(MaterialShading.Pbr)
  g.sharedMaterial.setFloat("roughness", 0.5)
  for i in 0 ..< FieldCount:
    g.cubes[i] = newModel(cube)
    g.cubes[i].setTint(fieldTint(i, 255))
    g.scene.add(g.cubes[i])
  setMaterials(false)

  # see-through copies of the same cube: same mesh, same material, alpha in the tint
  for i in 0 ..< Glass:
    g.glass[i] = newModel(cube)
    g.glass[i].setMaterial(-1, g.sharedMaterial)
    g.glass[i].setTint(rgba(255, 255, 255, 110))
    g.glass[i].setTransform((i.float * 2.0 - 4.0, 5.2, 5.0), (0.0, 0.0, 0.0), (2.0, 2.0, 2.0))
    g.scene.add(g.glass[i])
  cube.release()

  # six walkers sharing one skinned mesh, each at its own point in the walk
  for i in 0 ..< Walkers:
    g.walkers[i] = newModel()
    g.walkers[i].setTransform((i.float * 2.4 - 6.0, 0.0, -2.0), (0.0, 3.14159, 0.0), (1.0, 1.0, 1.0))
    g.walkers[i].setAnimation(3)
    g.walkers[i].setAnimationLoop(true)
    g.scene.add(g.walkers[i])
  for walker in g.walkers:
    loadMeshInto(walker)

proc frame(dt, tickFraction: float) =
  let t = getTime()

  g.camera.setView(position = (sin(t * 0.15) * 22.0, 12.0, cos(t * 0.15) * 22.0),
                   target = (0.0, 1.0, 0.0))
  for i in 0 ..< FieldCount:
    let x = ((i mod FieldSide).float - FieldSide * 0.5 + 0.5) * 1.5
    let z = ((i div FieldSide).float - FieldSide * 0.5 + 0.5) * 1.5
    let wave = sin(t * 1.5 + x * 0.6 + z * 0.4)
    # well clear of the floor, so every cube throws its own shadow onto it
    g.cubes[i].setTransform((x, 2.4 + wave * 0.5, z), (0.0, t * 0.3 + i.float, 0.0), (1.0, 1.0, 1.0))
  for i in 0 ..< Walkers:
    # the same walk, out of step: a shared mesh, but each its own pose
    g.walkers[i].setAnimationTime(t + i.float * 0.35)

  beginFrame()
  clearBackground(rgba(28, 30, 38, 255))
  g.scene.draw()
  drawText("wgrender instancing (Nim): models that share a mesh and a material go up as one draw",
           12, 36, 20, ColorRaywhite)
  drawText($FieldCount & " cubes, " &
           (if g.ownMaterials: "a material each (one draw each)" else: "one material (one draw)") &
           "   SPACE toggles   ESC quit", 12, 64, 16, ColorLightgray)
  endFrame()

  let keys = getKeyboardState()
  if keys.isPressed(Key.Space):
    setMaterials(not g.ownMaterials)
  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()

when isMainModule:
  initValues(1024, 720, "instancing (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
