## wgrender meshes example, in Nim: a port of wgrender's examples/meshes.c.
##
## Generated meshes: shapes made in code (newMeshPlane, newMeshCube, newMeshSphere,
## newMeshCylinder, newMeshCone, newMeshCapsule, newMeshTorus). The seven shapes in a
## row on a generated floor, each with its own color and the same normal-mapped tile
## material, so their texture coordinates and tangents show: the tiles should sit flat
## on every surface and catch the light the same way. The camera turns around them
## (O stops it). Keys: O camera, Escape quit.

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

  NormalMapPath = "textures/tiles_normal.png"
  ShapeCount = 7

type App = object
  scene: Scene
  camera: Camera3d
  shapes: array[ShapeCount, Model]
  materials: array[ShapeCount, Material] # the models hold references; these get the normal map
  orbit: bool
  angle: float

var g = App(orbit: true)

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc onInit() =
  # each shape, how high its center sits (so it rests on the floor), and its color
  let shapes: array[ShapeCount, tuple[mesh: Mesh; y: float; color: Vec3]] = [
    (newMeshPlane(1.0, 1.0, 4), 0.01, (0.85, 0.85, 0.85)),
    (newMeshCube(0.9, 0.9, 0.9), 0.45, (0.9, 0.3, 0.2)),
    (newMeshSphere(0.5, 24, 48), 0.5, (0.2, 0.55, 0.9)),
    (newMeshCylinder(0.45, 1.0, 40), 0.5, (0.3, 0.8, 0.35)),
    (newMeshCone(0.5, 1.1, 40), 0.55, (0.95, 0.75, 0.2)),
    (newMeshCapsule(0.35, 1.2, 16, 40), 0.6, (0.7, 0.35, 0.85)),
    (newMeshTorus(0.4, 0.15, 48, 24), 0.15, (0.9, 0.5, 0.6)),
  ]
  setAssetHost(AssetBase)

  g.camera = newCamera3d(Projection.Perspective)
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  g.scene.setAmbient(ColorWhite, 0.25)
  let sun = newLight(LightKind.Directional)
  sun.setDirection((-0.5, -1.0, -0.4))
  sun.setIntensity(3.0)
  g.scene.add(sun)

  let plane = newMeshPlane(12.0, 12.0, 0)
  let floor = newModel(plane)
  plane.release() # the model holds its own reference
  let ground = newMaterial(MaterialShading.Pbr)
  ground.setVec4("base_color", (0.06, 0.06, 0.07, 1.0))
  ground.setFloat("metallic", 0.0)
  ground.setFloat("roughness", 0.9)
  floor.setMaterial(-1, ground)
  ground.release()
  g.scene.add(floor)

  for i in 0 ..< ShapeCount:
    let x = (i.float - (ShapeCount - 1) * 0.5) * 1.4
    let (mesh, y, color) = shapes[i]
    g.shapes[i] = newModel(mesh)
    mesh.release()
    g.shapes[i].setTransform((x, y, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
    g.materials[i] = newMaterial(MaterialShading.Pbr)
    g.materials[i].setVec4("base_color", (color.x, color.y, color.z, 1.0))
    g.materials[i].setFloat("metallic", 0.0)
    g.materials[i].setFloat("roughness", 0.45)
    g.materials[i].setVec2("normal_texture_scale", (2.0, 2.0)) # tiles repeat
    g.shapes[i].setMaterial(0, g.materials[i])
    g.materials[i].release() # the model keeps it alive
    g.scene.add(g.shapes[i])
  load(NormalMapPath) do (path: string):
    let texture = newTexture(path)
    for material in g.materials:
      material.setTexture("normal_texture", texture)
    texture.release() # the materials hold their own references
  enableFps(12, 10, 16)

proc frame(dt, tickFraction: float) =
  when not defined(emscripten): # a web page has nothing to quit to
    if getKey(Key.Escape) == ButtonState.Pressed: requestQuit()
  if getKey(Key.O) == ButtonState.Pressed: g.orbit = not g.orbit
  if g.orbit: g.angle += dt * 0.2
  g.camera.setView(position = (9.0 * sin(g.angle), 3.5, 9.0 * cos(g.angle)),
                   target = (0.0, 0.4, 0.0))

  beginFrame()
  clearBackground(rgba(20, 22, 28, 255))
  g.scene.draw()
  drawText("wgrender generated meshes (Nim): plane, cube, sphere, cylinder, cone, capsule, torus",
           12, 36, 20, ColorRaywhite)
  drawText((if g.orbit: "O: stop the camera   ESC: quit" else: "O: turn the camera   ESC: quit"),
           12, 64, 16, ColorLightgray)
  endFrame()

when isMainModule:
  initValues(1000, 600, "meshes (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
