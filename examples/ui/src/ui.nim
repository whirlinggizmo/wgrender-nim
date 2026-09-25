## wgrender ui example, in Nim: a port of wgrender's examples/ui.c.
##
## Pointer interaction with 2D and 3D members of one scene. The buttons, the progress
## bar and the scrolling list come from ui_widgets.nim (a port of examples/ui_widgets.h),
## which builds them out of 2D shapes, text2d and scene interaction: wgrender has no
## widget API (docs/ROADMAP.md, "GUI direction"), so this is how a game writes one.
##
##   - a nine-slice sprite is the panel behind the controls; presses on it don't orbit
##   - buttons (rounded 2D shapes + centered text2d) react to hover and press; clicking
##     counts and fills the progress bar
##   - "Enable"/"Disable" toggles the third button: disabled, it still blocks the
##     pointer but doesn't react
##   - the note under the bar is wrapped text (setMaxWidth)
##   - the list at the bottom is clipped to the panel (scene.setClip): the mouse wheel
##     scrolls it, and rows scrolled out of the box can't be hovered or clicked
##   - the gumshoe (a 3D member) lights up on hover; clicking it starts or stops its
##     animation
##   - dragging anywhere else orbits the camera; a drag that starts on a button doesn't
##     (isPointerCaptured)
##   - the header is immediate drawing, next to all that retained UI: the panel's
##     nine-slice texture drawn directly, and a rounded, bordered status pill
## Touch works like the mouse. ESC quits.

import std/[math, strformat]
import wgr
import ./ui_widgets

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (wgrender's tools/serve.py mounts examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  GumshoePath = "models/gumshoe/gumshoe.glb"
  PanelPath = "textures/ui_panel.png"

  Buttons = 3
  Rows = 8

  # Layers, bottom to top. Each widget puts its labels on the layer above the one it's
  # given (ui_widgets.nim), so a control on LayerControl labels on LayerLabel, and the
  # list's rows and labels are clipped to the same box on LayerRow and the one above.
  LayerPanel = 0
  LayerControl = 1
  LayerLabel = 2
  LayerRow = 5

  PanelX = 10.0
  PanelY = 70.0
  PanelWidth = 280.0
  PanelHeight = 470.0
  ListX = 30.0
  ListY = 400.0
  ListWidth = 240.0
  ListHeight = 120.0
  RowHeight = 34.0

  Labels: array[Buttons, string] = ["Count", "Enable / Disable", "Count too"]
  RowNames: array[Rows, string] = ["Sponza", "Flight helmet", "Gumshoe", "Damaged helmet",
                                   "Water bottle", "Lantern", "Sphere grid", "Boom box"]

type App = object
  scene: Scene
  camera: Camera3d
  sun: Light
  theme: Theme
  bg, highlight, pill, pillEdge: Color
  panel: Sprite2d
  divider: Shape2d
  note: Text2d
  buttons: array[Buttons, Button]
  bar: Bar
  list: List
  gumshoe: Model
  panelTexture: Texture
  clicks: int
  animating: bool
  yaw: float

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc placeCamera() =
  g.camera.setView(position = (sin(g.yaw) * 5.0, 1.6, cos(g.yaw) * 5.0), target = (0.0, 0.9, 0.0))

proc onInit() =
  setAssetHost(AssetBase)
  g.theme = defaultTheme()
  g.bg = rgba(30, 34, 44, 255)
  g.highlight = rgba(255, 220, 120, 255)
  g.pill = rgba(40, 46, 62, 230)
  g.pillEdge = rgba(90, 105, 140, 255)

  g.camera = newCamera3d(Projection.Perspective)
  placeCamera()
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  g.scene.setAmbient(ColorWhite, 0.35)
  g.scene.setInteractive(true)

  g.sun = newLight(LightKind.Directional)
  g.sun.setDirection((-0.4, -1.0, -0.6))
  g.scene.add(g.sun)

  g.gumshoe = newModel()
  g.gumshoe.setAnimation(3)
  g.scene.add(g.gumshoe)

  # the panel: one 48x48 texture with 16 px borders, stretched to any size
  g.panel = newSprite2d()
  g.panel.setNineSlice(16, 16, 16, 16)
  g.panel.setPivot(0, 0)
  g.panel.setPosition(PanelX, PanelY)
  g.panel.setSize(PanelWidth, PanelHeight)
  g.scene.add(g.panel, LayerPanel) # pickable, so presses on it don't orbit

  g.divider = newShape2d()
  g.divider.setLine((0.0, 0.0), (220.0, 0.0), 2)
  g.divider.setTransform((30.0, 300.0), 0, (1.0, 1.0))
  g.divider.setColor(g.theme.disabled)
  g.divider.setPickable(false)
  g.scene.add(g.divider, LayerControl)

  g.bar = newBar(g.scene, LayerControl, 30, 320, 220, 18)

  # wrapped note: laid out inside 220 pixels, breaking between words
  g.note = newText2d()
  g.note.setText("Every click fills the bar. The list below is clipped to the panel: " &
                 "scroll it with the wheel.")
  g.note.setSize(14)
  g.note.setMaxWidth(220)
  g.note.setPosition(30, 352)
  g.note.setColor(g.theme.textDisabled)
  g.note.setPickable(false)
  g.scene.add(g.note, LayerLabel)

  for i, button in g.buttons.mpairs:
    button = newButton(g.scene, LayerControl, Labels[i], 30, 100.0 + 60.0 * i.float, 220, 44, 18)
  # the list clips its rows and their labels to its box (LayerRow, LayerRow + 1)
  g.list = newList(g.scene, LayerRow, RowNames, ListX, ListY, ListWidth, ListHeight, RowHeight, 15)

  load(GumshoePath) do (path: string):
    let mesh = newMesh(path)
    g.gumshoe.setMesh(mesh)
    mesh.release()
  load(PanelPath) do (path: string):
    g.panelTexture = newTexture(path) # kept: the header draws it too
    g.panel.setTexture(g.panelTexture)

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  let mouse = getMouseState()
  let hovered = g.scene.getHovered()

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()

  # buttons: each colors itself and says whether it was clicked
  let counted = g.buttons[0].update(g.scene, g.theme)
  let toggled = g.buttons[1].update(g.scene, g.theme)
  let countedToo = g.buttons[2].update(g.scene, g.theme)
  if counted or countedToo:
    inc g.clicks
  if toggled:
    g.buttons[2].setEnabled(not g.buttons[2].isEnabled)
  g.bar.setValue(float(g.clicks mod 11) / 10.0, g.theme)

  # the clipped list: the wheel scrolls it, clicking a row selects it
  let selected = g.list.update(g.scene, g.theme, mouse.wheel)

  # the 3D model
  g.gumshoe.setTint(if g.scene.getHover(g.gumshoe) in {ButtonState.Pressed, ButtonState.Down}:
                      g.highlight else: ColorWhite)
  if g.scene.isClicked(g.gumshoe):
    g.animating = not g.animating
  if g.animating:
    g.gumshoe.animate(dt)

  # orbit, unless the press started on UI
  if mouse.buttons[0] == ButtonState.Down and not isPointerCaptured():
    g.yaw -= mouse.dx.float * 0.01
    placeCamera()

  beginFrame()
  clearBackground(g.bg)
  g.scene.draw()
  # the header is immediate drawing, next to the retained panel below it: the same
  # nine-slice texture as the panel, and a rounded, bordered pill for the status
  g.panelTexture.drawNineSlice((0.0, 0.0, 0.0, 0.0), 16, 16, 16, 16, (10.0, 6.0, 640.0, 62.0),
                               ColorWhite)
  drawRoundedRectangle(18, 40, 624, 22, 11, 11, 11, 11, g.pill)
  drawBorder(18, 40, 624, 22, 1, 1, 1, 1, 11, 11, 11, 11, g.pillEdge)
  drawText("wgrender ui (Nim): hover, press and click 2D and 3D members", 22, 15, 20, g.theme.text)
  let selectedName = if selected < 0: "nothing" else: RowNames[selected]
  let hoveredName =
    if hovered.isNone: "nothing"
    elif hovered == g.gumshoe: "gumshoe"
    elif hovered == g.panel: "the panel"
    else: "UI"
  let captured = if isPointerCaptured(): "yes" else: "no"
  drawText(&"clicks: {g.clicks}   selected: {selectedName}   hovered: {hoveredName}   " &
           &"pointer captured: {captured}", 28, 43, 15, g.theme.textDisabled)
  endFrame()

when isMainModule:
  initValues(960, 600, "ui (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
