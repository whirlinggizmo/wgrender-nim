## wgrender text3d example, in Nim: a port of wgrender's examples/text3d.c.
##
## Text in the 3D world, 3D shapes and object picking:
##   - camera-facing labels above a cube, a sphere and a rectangle
##   - a sign: text with Free facing, turned with its transform
##   - circle outlines on the ground and a line-strip spiral built point by point
##   - hover: the scene's pick finds the object under the mouse (labels included) and
##     highlights it; pick statistics and the FPS are drawn with a TrueType font
##   - P toggles whether the cube is pickable
## Escape quits.

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

  FontPath = "fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"
  LabelCount = 3

type App = object
  scene: Scene
  camera: Camera3d
  font: Font
  bg, grey, gold, teal, rose, highlight, ring: Color
  cube, sphere, panel, spiral: Shape3d
  sign: Text3d
  rings: array[3, Shape3d]
  labels: array[LabelCount, Text3d]
  hovered: Handle
  time: float

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc addLabel(text: string; x, y, z: float): Text3d =
  let label = newText3d() # font attached when it loads
  label.setText(text)
  label.setSize(0.35)
  label.setTransform((x, y, z), (0.0, 0.0, 0.0))
  label.setColor(ColorRaywhite)
  g.scene.add(label)
  label

proc onInit() =
  setAssetHost(AssetBase)
  setAssetManifest(AssetManifestName)
  g.bg = rgba(22, 24, 30, 255)
  g.grey = rgba(60, 64, 76, 255)
  g.gold = rgba(230, 180, 60, 255)
  g.teal = rgba(60, 190, 180, 255)
  g.rose = rgba(220, 90, 120, 255)
  g.highlight = rgba(255, 255, 255, 255)
  g.ring = rgba(120, 130, 160, 255)

  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (0.0, 4.0, 9.0), target = (0.0, 0.8, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  g.cube = newShape3d()
  g.cube.setCube((1.2, 1.2, 1.2))
  g.cube.setTransform((-3.0, 0.6, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.scene.add(g.cube)

  g.sphere = newShape3d()
  g.sphere.setSphere(0.7)
  g.sphere.setTransform((0.0, 0.7, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.scene.add(g.sphere)

  g.panel = newShape3d()
  g.panel.setRectangle(1.4, 1.0)
  g.panel.setTransform((3.0, 0.8, 0.0), (0.0, -0.5, 0.0), (1.0, 1.0, 1.0))
  g.scene.add(g.panel)

  for i, ring in g.rings.mpairs: # rings lying on the ground under each object
    ring = newShape3d()
    ring.setCircle(1.0)
    ring.setTransform((-3.0 + 3.0 * i.float, 0.01, 0.0), (-1.5707963, 0.0, 0.0), (1.0, 1.0, 1.0))
    ring.setColor(g.ring)
    ring.setPickable(false)
    g.scene.add(ring)

  g.spiral = newShape3d() # a line strip, built point by point
  g.spiral.setLineStrip()
  for i in 0 .. 160:
    let t = i.float / 160.0
    let a = t * 6.2831853 * 4.0
    g.spiral.addPoint((cos(a) * (0.2 + t), t * 2.5, sin(a) * (0.2 + t)))
  g.spiral.setTransform((0.0, 0.0, -3.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.spiral.setColor(g.teal)
  g.scene.add(g.spiral)

  g.labels[0] = addLabel("cube", -3, 1.7, 0)
  g.labels[1] = addLabel("sphere", 0, 1.9, 0)
  g.labels[2] = addLabel("rectangle", 3, 1.8, 0)

  g.sign = newText3d() # Free facing: oriented by its rotation, like a sign
  g.sign.setText("wgrender text3d (Nim)")
  g.sign.setSize(0.6)
  g.sign.setFacing(SpriteFacing.Free)
  g.sign.setColor(g.gold)
  g.scene.add(g.sign)

  load(FontPath) do (path: string):
    g.font = newFont(path)
    for label in g.labels:
      label.setFont(g.font)
    g.sign.setFont(g.font)

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  let mouse = getMouseState()

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()
  if keys.isPressed(Key.P): g.cube.setPickable(not g.cube.isPickable)

  g.time += dt
  g.cube.setTransform((-3.0, 0.6, 0.0), (0.0, g.time * 0.7, 0.0), (1.0, 1.0, 1.0))
  g.sign.setTransform((0.0, 3.2, -3.0), (0.0, sin(g.time * 0.6) * 0.6, 0.0))

  # hover: the nearest pickable object under the mouse
  resetPickStats()
  let pick = g.scene.pick(mouse.x.float, mouse.y.float)
  g.hovered = if pick.hit: pick.handle else: Handle(0)
  g.cube.setColor(if g.hovered == g.cube: g.highlight else: g.gold)
  g.sphere.setColor(if g.hovered == g.sphere: g.highlight else: g.rose)
  g.panel.setColor(if g.hovered == g.panel: g.highlight else: g.teal)
  for label in g.labels:
    label.setColor(if g.hovered == label: g.gold else: ColorRaywhite)
  let stats = getPickStats()

  beginFrame()
  clearBackground(g.bg)
  beginMode3d()
  drawGrid(16, 1.0, g.grey)
  endMode3d()
  g.scene.draw()

  drawText(g.font, "wgrender text3d (Nim): text in 3D, shapes, picking", 12, 10, 20, ColorRaywhite)
  let hover =
    if not pick.hit: "nothing"
    elif pick.handle == g.cube: "cube"
    elif pick.handle == g.sphere: "sphere"
    elif pick.handle == g.panel: "rectangle"
    elif pick.handle == g.sign: "sign"
    else: "label"
  drawText(g.font, &"hover: {hover}   [P] cube pickable: {(if g.cube.isPickable: \"yes\" else: \"no\")}",
           12, 36, 16, ColorLightgray)
  drawText(g.font, &"pick stats: {stats.broadphaseTests} box tests ({stats.broadphaseRejects} rejected), " &
           &"{stats.narrowphaseTests} exact tests, {stats.narrowphaseHits} hits", 12, 56, 16, ColorLightgray)
  drawFps(g.font, 12, 80, 16, ColorLime)
  endFrame()

when isMainModule:
  initValues(1000, 640, "text3d (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
