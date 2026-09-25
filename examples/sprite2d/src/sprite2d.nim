## wgrender sprite2d example, in Nim: a port of wgrender's examples/sprite2d.c.
##
## Screen-space sprites over a 3D scene.
##
##   - "sheet": the 256x256 logo treated as a 2x2 sprite sheet; setSource steps
##     through the four quadrants like animation frames
##   - "spin": rotates around its center (default pivot)
##   - "swing": rotates around its top-left corner (pivot 0,0)
##   - "flip": mirrored with a negative x scale
##   - "tint": a white copy of the logo cycling through tint colors (tint multiplies
##     the texture color, so it can't show on the black logo)
##   - a one-off texture draw in the corner (no object)
## Sprites are scene members, so they draw on top of the 3D model and are picked
## first. Hovering enlarges the sprite under the mouse; the alpha test lets the pointer
## through the logo's transparent parts. Uses high-DPI, so all positions are logical
## pixels. ESC quits.

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

  LogoPath = "sprites/logo/wg-logo-bw-alpha.png"
  WhiteLogoPath = "sprites/logo/wg-logo-white-alpha.png"
  CharacterPath = "models/woman_casual/woman_casual.glb"

  SpriteCount = 5
  TintSprite = 4
  PaletteSize = 24

  Names: array[SpriteCount, string] = ["sheet", "spin", "swing", "flip", "tint"]

type App = object
  scene: Scene
  camera: Camera3d
  bg: Color
  logo: Texture
  palette: array[PaletteSize, Color]
  model: Model
  sprites: array[SpriteCount, Sprite2d]
  hovered: Handle
  time: float
  frame: int

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc onInit() =
  setAssetHost(AssetBase)
  g.bg = rgba(28, 30, 38, 255)
  for i, color in g.palette.mpairs: # colors are immutable, so cycle a palette
    let a = i.float / PaletteSize * 6.2831853
    color = rgba(int(127 + 127 * sin(a)), int(127 + 127 * sin(a + 2.1)),
                 int(127 + 127 * sin(a + 4.2)), 255)

  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (0.0, 1.4, 5.5), target = (0.0, 1.0, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  let sun = newLight(LightKind.Directional)
  sun.setDirection((-0.5, -1.0, -0.7))
  sun.setIntensity(3.0)
  g.scene.add(sun)
  g.scene.setAmbient(ColorWhite, 0.35)

  g.model = newModel()
  g.model.setAnimation(3)
  g.model.setAnimationLoop(true)
  g.scene.add(g.model)

  for sprite in g.sprites.mitems:
    sprite = newSprite2d() # texture attached when it loads
    sprite.setSize(128, 128)
    sprite.setPickAlphaTest(true, 0.5)
    g.scene.add(sprite, layer = 1)
  g.sprites[0].setPosition(140, 170)
  g.sprites[1].setPosition(140, 380)
  g.sprites[2].setPivot(0, 0)
  g.sprites[2].setPosition(700, 110)
  g.sprites[2].setSize(96, 96)
  g.sprites[3].setPosition(760, 400)
  g.sprites[3].setScale(-1, 1)
  g.sprites[TintSprite].setPosition(450, 110)
  g.sprites[TintSprite].setSize(96, 96)

  load(LogoPath) do (path: string):
    g.logo = newTexture(path)
    for i, sprite in g.sprites:
      if i != TintSprite:
        sprite.setTexture(g.logo)
  load(WhiteLogoPath) do (path: string):
    let texture = newTexture(path)
    g.sprites[TintSprite].setTexture(texture)
    texture.release() # the sprite holds its own reference
  load(CharacterPath) do (path: string):
    let mesh = newMesh(path)
    g.model.setMesh(mesh)
    mesh.release()

proc frame(dt, tickFraction: float) =
  let mouse = getMouseState()
  var hoverName = "nothing"

  when not defined(emscripten): # a web page has nothing to quit to
    if isKeyPressed(Key.Escape): requestQuit()
  g.time += dt
  g.model.animate(dt)

  # sprite sheet: one quadrant of the 256x256 texture per animation frame
  g.frame = int(g.time * 2.0) mod 4
  g.sprites[0].setSource(float(g.frame mod 2) * 128, float(g.frame div 2) * 128, 128, 128)
  g.sprites[1].setRotation(g.time)
  g.sprites[2].setRotation(sin(g.time * 1.5) * 0.8)
  g.sprites[TintSprite].setTint(g.palette[int(g.time * 6.0) mod PaletteSize])

  # hover: 2D sprites are picked before the model behind them
  let pick = g.scene.pick(mouse.x.float, mouse.y.float)
  g.hovered = if pick.hit: pick.handle else: Handle.default
  for i, sprite in g.sprites:
    let grow = if sprite == g.hovered: 1.15 else: 1.0
    sprite.setScale(if i == 3: -grow else: grow, grow) # "flip" keeps its mirror
    if sprite == g.hovered:
      hoverName = Names[i]
  if pick.hit and pick.handle == g.model:
    hoverName = "model"

  beginFrame()
  clearBackground(g.bg)
  g.scene.draw()
  g.logo.draw(getScreenSize().x - 74, 10, 64, 64, ColorWhite) # one-off, no object

  drawText("wgrender sprite2d (Nim): source rect, pivot, rotation, flip, picking", 12, 12, 16,
           ColorRaywhite)
  drawText(&"mouse ({mouse.x}, {mouse.y})  hover: {hoverName}  sheet frame {g.frame}", 12, 36, 16,
           ColorLightgray)
  endFrame()

when isMainModule:
  initValues(900, 520, "sprite2d (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
