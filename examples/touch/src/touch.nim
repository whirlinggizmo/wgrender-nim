## wgrender touch example, in Nim: a port of wgrender's examples/touch.c.
##
## Fingers and the two-finger gesture.
##
##   - every finger gets a numbered ring (its id) while it's down, and a fading one
##     where it lifted;
##   - two fingers pan, pinch and twist the logo (getTouchGesture), about the point
##     between them, so it stays under your fingers;
##   - one finger is also the pointer: drag the coin. A second finger cancels that drag
##     (the pointer is released off-screen), so a pinch never drops the coin somewhere
##     or clicks anything.
## Without a touch screen: drag with the mouse, and the wheel zooms the logo.
## ESC quits.

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

  LogoPath = "sprites/logo/wg-logo-white-alpha.png"
  TilesPath = "textures/tiles.png"
  Ring = 38.0

type App = object
  logo, tile: Sprite2d
  logoX, logoY, logoScale, logoRotation: float
  tileX, tileY: float
  dragging: bool
  lifted: array[MaxTouches, tuple[x, y, fade: float]] # a lifted finger; fade 1 -> 0
  colors: array[MaxTouches, Color]

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc onInit() =
  let screen = getScreenSize()
  setAssetHost(AssetBase)
  setAssetManifest(AssetManifestName)
  load(LogoPath) do (path: string):
    g.logo = newSprite2d(newTexture(path))
    g.logo.setSize(240, 240)
  load(TilesPath) do (path: string):
    let texture = newTexture(path)
    texture.setSampling(TextureWrap.Clamp, TextureWrap.Clamp, TextureFilter.Nearest)
    g.tile = newSprite2d(texture)
    g.tile.setSource(32, 16, 16, 16) # the coin
    g.tile.setSize(96, 96)
  g.logoX = screen.x * 0.5
  g.logoY = screen.y * 0.45
  g.logoScale = 1.0
  g.tileX = screen.x * 0.5
  g.tileY = screen.y * 0.8
  for i, color in g.colors.mpairs:
    color = rgba(90 + 20 * i, 200 - 15 * i, 120 + 17 * i, 255)

# Scale and turn the logo about (x, y), so the point under the fingers stays put.
proc transformLogo(x, y, scale, rotation: float) =
  let c = cos(rotation)
  let s = sin(rotation)
  let ox = (g.logoX - x) * scale
  let oy = (g.logoY - y) * scale
  g.logoX = x + ox * c - oy * s
  g.logoY = y + ox * s + oy * c
  g.logoScale = min(max(g.logoScale * scale, 0.2), 8.0)
  g.logoRotation += rotation

proc frame(dt, tickFraction: float) =
  let mouse = getMouseState()
  let gesture = getTouchGesture()
  let count = getTouchCount()
  let defaultFont = Font.default # none: the built-in font

  when not defined(emscripten): # a web page has nothing to quit to
    if isKeyPressed(Key.Escape): requestQuit()

  # two fingers move the logo; the wheel zooms it about the mouse
  if gesture.active:
    g.logoX += gesture.dx
    g.logoY += gesture.dy
    transformLogo(gesture.x, gesture.y, gesture.scale, gesture.rotation)
  if mouse.wheel != 0.0:
    transformLogo(mouse.x.float, mouse.y.float, pow(1.1, mouse.wheel), 0.0)

  # the pointer (mouse, or one finger) drags the coin
  if mouse.left == ButtonState.Pressed and abs(mouse.x.float - g.tileX) < 48 and
      abs(mouse.y.float - g.tileY) < 48:
    g.dragging = true
  elif mouse.left in {ButtonState.Released, ButtonState.Up}:
    g.dragging = false
  if g.dragging:
    g.tileX = mouse.x.float
    g.tileY = mouse.y.float

  # where fingers lifted: a ring that fades
  for lifted in g.lifted.mitems:
    lifted.fade = max(lifted.fade - dt * 2.0, 0.0)
  for i in 0 ..< count:
    let touch = getTouch(i)
    if touch.state == ButtonState.Released:
      g.lifted[touch.id] = (touch.x, touch.y, 1.0)

  beginFrame()
  clearBackground(rgba(22, 25, 33, 255))
  if not g.logo.isNone:
    g.logo.setPosition(g.logoX, g.logoY)
    g.logo.setScale(g.logoScale, g.logoScale)
    g.logo.setRotation(g.logoRotation)
    g.logo.draw()
  if not g.tile.isNone:
    g.tile.setPosition(g.tileX, g.tileY)
    g.tile.setTint(if g.dragging: rgba(255, 230, 150, 255) else: ColorWhite)
    g.tile.draw()
  for i, lifted in g.lifted:
    if lifted.fade > 0.0:
      drawCircleLines((lifted.x, lifted.y), Ring * (2.0 - lifted.fade),
                      g.colors[i].withAlpha(int(200 * lifted.fade)))
  for i in 0 ..< count:
    let touch = getTouch(i)
    if touch.state == ButtonState.Released: continue
    drawCircle((touch.x, touch.y), Ring, g.colors[touch.id].withAlpha(90))
    drawCircleLines((touch.x, touch.y), Ring, g.colors[touch.id])
    defaultFont.drawText($touch.id, touch.x - 6, touch.y - Ring - 26, 22, g.colors[touch.id])
  if gesture.active:
    drawCircle((gesture.x, gesture.y), 6, ColorWhite)

  let pointer = if mouse.left in {ButtonState.Down, ButtonState.Pressed}: "down" else: "up"
  defaultFont.drawText(&"fingers: {count}   pointer: {pointer}", 16, 16, 18, ColorWhite)
  defaultFont.drawText(&"logo: scale {g.logoScale:.2f}, turn {int(round(g.logoRotation * 57.29578))} deg",
                       16, 40, 18, ColorWhite)
  defaultFont.drawText("two fingers: pan, pinch, twist the logo; one finger drags the coin", 16, 64, 16,
                       rgba(150, 158, 175, 255))
  endFrame()

when isMainModule:
  initValues(900, 700, "touch (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
