## wgrender materials example, in Nim: a port of wgrender's examples/materials.c.
##
## glTF metallic-roughness materials created in code:
##   - top row: dielectric (metallic 0) spheres, roughness 0 to 1 left to right
##   - middle row: metal (metallic 1) spheres, same roughness steps
##   - bottom row: unlit, emissive, normal mapped (tangents generated at load), alpha
##     blended, and the animated gumshoe with its body material replaced by gold on
##     this model only
## One sphere mesh backs every sphere; each model overrides the mesh's material. The
## materials are assigned before the mesh finishes loading. A sun, an orbiting point
## light and a little ambient light the scene. Keys: 1 sun, 2 point light.

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

  SpherePath = "models/sphere/sphere.glb"
  GumshoePath = "models/gumshoe/gumshoe.glb"
  NormalMapPath = "textures/tiles_normal.png"

  Columns = 5
  Spacing = 1.35
  GumshoeBodySlot = 1 # slot 0, the blob shadow, is kept

type App = object
  scene: Scene
  camera: Camera3d
  background: Color
  spheres: seq[Model]
  gumshoe: Model
  tiles: Material # normal mapped; gets its texture when it loads
  sun, lamp: Light
  lampMarker: Shape3d
  time: float

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc addSphere(x, y: float; material: Material) =
  ## a sphere with its own material; the model keeps its own reference to it
  let model = newModel() # its mesh attached when it loads
  model.setTransform((x, y, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  model.setMaterial(0, material)
  material.release()
  g.scene.add(model)
  g.spheres.add model

proc newPbr(color: Vec3; metallic, roughness: float): Material =
  result = newMaterial(MaterialShading.Pbr)
  result.setVec4("base_color", (color.x, color.y, color.z, 1.0)) # linear
  result.setFloat("metallic", metallic)
  result.setFloat("roughness", roughness)

proc onInit() =
  setAssetHost(AssetBase)
  g.background = rgba(20, 22, 28, 255)
  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (0.0, 1.6, 7.5), target = (0.0, 1.2, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  g.scene.setAmbient(ColorWhite, 0.12)

  g.sun = newLight(LightKind.Directional)
  g.sun.setDirection((-0.4, -0.7, -0.6))
  g.sun.setColor(rgba(255, 244, 228, 255))
  g.sun.setIntensity(3)
  g.scene.add(g.sun)

  g.lamp = newLight(LightKind.Point)
  g.lamp.setColor(rgba(120, 190, 255, 255))
  g.lamp.setIntensity(8)
  g.lamp.setRange(10)
  g.scene.add(g.lamp)
  g.lampMarker = newShape3d() # shapes are unlit, so it shows the light's color
  g.lampMarker.setSphere(0.06)
  g.lampMarker.setColor(ColorSkyblue)
  g.scene.add(g.lampMarker)

  # rows of roughness steps: red plastic, then gold
  for c in 0 ..< Columns:
    let x = (c.float - (Columns - 1) * 0.5) * Spacing
    let roughness = c / (Columns - 1)
    addSphere(x, 2.7, newPbr((0.8, 0.05, 0.04), 0.0, roughness))
    addSphere(x, 1.35, newPbr((1.0, 0.77, 0.34), 1.0, roughness))

  # unlit: ignores the lights
  var material = newMaterial(MaterialShading.Unlit)
  material.setColor("base_color", ColorSkyblue)
  addSphere(-2 * Spacing, 0.0, material)
  # emissive: glows regardless of lighting
  material = newPbr((0.05, 0.05, 0.05), 0.0, 0.6)
  material.setVec3("emissive", (1.0, 0.35, 0.05))
  addSphere(-Spacing, 0.0, material)
  # normal mapped: bevelled tiles
  g.tiles = newPbr((0.6, 0.6, 0.62), 0.0, 0.45)
  g.tiles.setFloat("normal_scale", 1.0)
  addSphere(0.0, 0.0, g.tiles) # releases our reference; the model keeps one
  # alpha blended glass
  material = newPbr((0.3, 0.9, 0.5), 0.0, 0.1)
  material.setVec4("base_color", (0.3, 0.9, 0.5, 0.35))
  material.setAlphaMode(AlphaMode.Blend)
  addSphere(Spacing, 0.0, material)

  g.gumshoe = newModel()
  g.gumshoe.setTransform((2 * Spacing, -0.55, 0.0), (0.0, -0.6, 0.0), (0.3, 0.3, 0.3))
  g.gumshoe.setAnimation(3)
  material = newPbr((1.0, 0.77, 0.34), 1.0, 0.3)
  g.gumshoe.setMaterial(GumshoeBodySlot, material)
  material.release()
  g.scene.add(g.gumshoe)

  load(SpherePath) do (path: string):
    let mesh = newMesh(path)
    for sphere in g.spheres: sphere.setMesh(mesh)
    mesh.release() # the models hold their own references
  load(GumshoePath) do (path: string):
    let mesh = newMesh(path)
    g.gumshoe.setMesh(mesh)
    mesh.release()
  load(NormalMapPath) do (path: string):
    let texture = newTexture(path)
    g.tiles.setTexture("normal_texture", texture)
    texture.release() # the material holds its own reference

proc onOff(light: Light): string = (if light.isEnabled: "on" else: "off")

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()
  if keys.isPressed(Key.Digit1): g.sun.setEnabled(not g.sun.isEnabled)
  if keys.isPressed(Key.Digit2): g.lamp.setEnabled(not g.lamp.isEnabled)

  g.time += dt
  let lamp = (cos(g.time * 0.7) * 4, 1.4 + sin(g.time * 0.9) * 1.2, sin(g.time * 0.7) * 1.5 + 2)
  g.lamp.setPosition(lamp)
  g.lampMarker.setTransform(lamp, (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.lampMarker.setVisible(g.lamp.isEnabled)
  for i in 2 * Columns ..< g.spheres.len: # turn the bottom row so the normal map moves
    let x = ((i - 2 * Columns).float - 2) * Spacing
    g.spheres[i].setTransform((x, 0.0, 0.0), (0.0, g.time * 0.5, 0.0), (1.0, 1.0, 1.0))
  g.gumshoe.animate(dt)

  beginFrame()
  clearBackground(g.background)
  g.scene.draw()
  drawText("wgrender materials (Nim): metallic-roughness, unlit, emissive, normal map, blend",
           12, 12, 16, ColorRaywhite)
  drawText("roughness 0 -> 1 (left to right)   rows: plastic, gold   [1] sun " & g.sun.onOff &
           "  [2] lamp " & g.lamp.onOff, 12, 36, 16, ColorLightgray)
  endFrame()

when isMainModule:
  initValues(1000, 700, "materials (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
