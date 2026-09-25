## wgrender pick example, in Nim: a port of wgrender's examples/pick.c.
##
## Ray-pick a scene containing all three drawable kinds. Click to pick. The scene's
## pick does a world-AABB broadphase then a per-kind narrow phase: shapes use exact
## ray/cube and ray/sphere tests; models use exact ray/triangle against the bind-pose
## mesh; sprites test the billboard quad and (when alpha-test picking is enabled)
## reject transparent texels via a CPU mask built from the texture source on demand.
## The camera is fixed so aiming is predictable; the readout shows what was hit, where,
## and how far.

import std/strformat
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (tools/serve.py mounts wgrender's examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  LogoPath = "sprites/logo/wg-logo-bw-alpha.png"
  ModelPath = "models/gumshoe/gumshoe.glb"

type App = object
  scene: Scene
  camera: Camera3d
  background: Color
  cube, sphere: Shape3d
  sprite: Sprite3d # set once the texture finishes loading
  model: Model     # set once the glTF finishes loading
  selected: Handle
  last: PickResult

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("asset load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc kindName(handle: Handle): string =
  case handle.getKind
  of HandleKind.Shape3d: "shape"
  of HandleKind.Sprite3d: "sprite3d"
  of HandleKind.Model: "model"
  else: "?"

proc onInit() =
  setAssetHost(AssetBase)

  g.background = rgba(24, 26, 34, 255)
  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (11.0, 9.0, 11.0), target = (0.0, 2.0, 0.0))

  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  # scenes start unlit: a sun and some ambient so the model is visible
  let sun = newLight(LightKind.Directional)
  sun.setDirection((-0.6, -1.0, -0.5))
  sun.setIntensity(3.0)
  g.scene.add(sun)
  g.scene.setAmbient(ColorWhite, 0.3)

  g.cube = newShape3d()
  g.cube.setCube((2.0, 2.0, 2.0))
  g.cube.setTransform((-3.5, 1.0, 0.0), (0.0, 0.6, 0.0), (1.0, 1.0, 1.0))
  g.cube.setColor(ColorOrange)
  g.scene.add(g.cube)

  g.sphere = newShape3d()
  g.sphere.setSphere(1.5)
  g.sphere.setTransform((3.5, 1.5, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.sphere.setColor(ColorGold)
  g.scene.add(g.sphere)

  load(LogoPath) do (path: string):
    let texture = newTexture(path)
    g.sprite = newSprite3d(texture)
    texture.release() # the sprite holds its own reference
    if g.sprite.isNone:
      return
    g.sprite.setSize(4.0)
    g.sprite.setFacing(SpriteFacing.Camera)
    g.sprite.setTint(ColorWhite)
    g.sprite.setTransform((0.0, 3.0, 4.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
    g.sprite.setPickAlphaTest(true, 0.5)
    g.scene.add(g.sprite, 1)
  load(ModelPath) do (path: string):
    let mesh = newMesh(path)
    g.model = newModel(mesh)
    mesh.release() # the model holds its own reference to the mesh
    if g.model.isNone:
      return
    g.model.setTransform((0.0, 0.0, -4.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
    g.model.setTint(ColorRaywhite)
    g.scene.add(g.model)

  enableFps(12, 10, 16)

proc shapeFor(handle: Handle): Shape3d =
  ## the shape a handle is, if it is one of ours; none otherwise
  if handle == g.cube: g.cube
  elif handle == g.sphere: g.sphere
  else: Shape3d(0)

proc defaultColorFor(shape: Shape3d): Color =
  ## Shapes can be recolored to show selection; other kinds just get reported.
  if shape == g.cube: ColorOrange
  elif shape == g.sphere: ColorGold
  else: ColorRaywhite

proc updateSelection(hit: Handle) =
  if hit == g.selected:
    return
  let old = shapeFor(g.selected)
  if not old.isNone:
    old.setColor(defaultColorFor(old))
  g.selected = hit
  let now = shapeFor(g.selected)
  if not now.isNone:
    now.setColor(ColorRaywhite)

proc frame(dt, tickFraction: float) =
  let mouse = getMouseState()

  if mouse.left == ButtonState.Pressed:
    let pick = g.scene.pick(mouse.x.float, mouse.y.float)
    g.last = pick
    updateSelection(if pick.hit: pick.handle else: Handle(0))

  beginFrame()
  clearBackground(g.background)

  beginMode3d()
  drawGrid(24, 1.0, ColorDarkgray)
  endMode3d()

  g.scene.draw()

  drawText("wgrender picking (Nim)", 12, 36, 24, ColorRaywhite)
  drawText("click cube / sphere / sprite / model", 12, 70, 16, ColorLightgray)

  if g.last.hit:
    let (world, local) = (g.last.pointWorld, g.last.pointLocal)
    drawText(&"hit {kindName(g.last.handle)} (handle {g.last.handle})", 12, 94, 16, ColorLime)
    drawText(&"world {world.x:.2f}, {world.y:.2f}, {world.z:.2f}   dist {g.last.distance:.2f}",
             12, 114, 16, ColorLightgray)
    drawText(&"local {local.x:.2f}, {local.y:.2f}, {local.z:.2f}", 12, 134, 16, ColorLightgray)
  else:
    drawText("no hit", 12, 94, 16, ColorLightgray)

  endFrame()

  when not defined(emscripten): # a web page has nothing to quit to
    if getKey(Key.Escape) == ButtonState.Pressed: requestQuit()

when isMainModule:
  initValues(900, 700, "pick (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
