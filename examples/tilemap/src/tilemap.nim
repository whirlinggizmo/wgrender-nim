## wgrender tilemap example, in Nim: a port of wgrender's examples/tilemap.c.
##
## A scrolling 2D tile map on an orthographic camera. wgrender has no camera2d: a scrolling, zooming
## 2D world is sprite3d objects in the XY plane (SpriteFacing.Free) under an
## orthographic camera3d, so it keeps the same scenes, layers, depth order and ray
## picking as 3D.
##
##   - one sprite sheet (textures/tiles.png), one sprite3d per cell, cut out with
##     setSource
##   - trees and flags are 16x32 in the sheet, drawn 1x2 world units with setExtent,
##     and stand on their cell because their pivot is the bottom edge (setPivot(0.5, 1))
##   - drag or use the arrow keys to scroll, the wheel to zoom (the camera's
##     orthographic height)
##   - the sheet is pixel art (alpha 0 or 1): ground tiles are AlphaMode.Opaque, props
##     AlphaMode.Mask, so nothing needs sorting and each layer draws in one batch
##   - coins react to the pointer through the scene's interaction state: hovering
##     lights them up, clicking collects them. Their picks are alpha-tested, so the
##     transparent corners of a coin let the tile behind it take the click.
## ESC quits.

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

  TilesPath = "textures/tiles.png"

  WorldW = 24
  WorldH = 16
  MaxProps = 64
  LayerGround = 0
  LayerProps = 1

  # cells of the sheet, in texture pixels: x, y, width, height (wgrender's
  # tools/gen_tiles.py; each cell has a gutter around it that repeats its edge, so
  # sampling never reaches a neighbour)
  Grass: Rect = (2.0, 2.0, 16.0, 16.0)
  Sand: Rect = (22.0, 2.0, 16.0, 16.0)
  Water: Rect = (42.0, 2.0, 16.0, 16.0)
  Stone: Rect = (62.0, 2.0, 16.0, 16.0)
  Tree: Rect = (2.0, 22.0, 16.0, 32.0)
  Flag: Rect = (22.0, 22.0, 16.0, 32.0)
  Coin: Rect = (42.0, 22.0, 16.0, 16.0)
  Rock: Rect = (62.0, 22.0, 16.0, 16.0)

type App = object
  scene: Scene
  camera: Camera3d
  texture: Texture
  bg, shade, text, dim, highlight: Color
  ground: array[WorldW * WorldH, Sprite3d]
  props: array[MaxProps, Sprite3d]
  isCoin: array[MaxProps, bool]
  propCount: int
  collected: int
  centerX, centerY: float # what the camera looks at, in world units
  zoom: float             # world units visible vertically
  loaded: bool

var g: App

proc placeCamera() =
  g.camera.setView(position = (g.centerX, g.centerY, 10.0), target = (g.centerX, g.centerY, 0.0))
  g.camera.setOrthoHeight(g.zoom)

# One cell of the sheet in the world. Ground tiles sit at z 0, props just in front of
# them so they draw over the ground (by depth).
proc addSprite(cell: Rect; x, y, z, width, height, pivotY: float; layer: int): Sprite3d =
  let sprite = newSprite3d(g.texture)
  sprite.setFacing(SpriteFacing.Free)
  sprite.setSource(cell.x, cell.y, cell.width, cell.height)
  sprite.setExtent(width, height)
  sprite.setPivot(0.5, pivotY)
  sprite.setTransform((x, y, z), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  # pixel art has no soft edges: ground tiles are opaque, props cut out their
  # transparent texels; neither needs sorting, so they draw in one batch each
  sprite.setAlphaMode(if layer == LayerGround: AlphaMode.Opaque else: AlphaMode.Mask, 0.5)
  g.scene.add(sprite, layer)
  sprite

proc addProp(cell: Rect; x, y, width, height: float; coin: bool) =
  if g.propCount >= MaxProps:
    return
  # the pivot is the bottom edge, so a prop stands on its cell whatever its height
  let prop = addSprite(cell, x, y - 0.5, 0.1, width, height, 1.0, LayerProps)
  g.props[g.propCount] = prop
  g.isCoin[g.propCount] = coin
  if coin:
    prop.setPickAlphaTest(true, 0.5)
  else:
    prop.setPickable(false)
  inc g.propCount

# A small hand-made map: water along the bottom, a sand shore, stone paths.
proc tileAt(x, y: int): Rect =
  if y < 2: return Water
  if y < 3: return Sand
  if x == 8 or y == 9: return Stone
  Grass

proc onTiles(path: string) =
  g.texture = newTexture(path)
  # pixel art: keep the texels crisp when zoomed in
  g.texture.setSampling(TextureWrap.Clamp, TextureWrap.Clamp, TextureFilter.Nearest)

  for y in 0 ..< WorldH:
    for x in 0 ..< WorldW:
      # a hair over one unit: neighbouring quads are blended separately, so edges that
      # land exactly on a pixel boundary would let the background through as a
      # hairline seam
      let tile = addSprite(tileAt(x, y), x.float + 0.5, y.float + 0.5, 0.0, 1.01, 1.01, 0.5,
                           LayerGround)
      tile.setPickable(false)
      g.ground[y * WorldW + x] = tile
  for i in 0 ..< 7: # trees and flags: 16x32 cells drawn 1x2
    addProp(Tree, 2.5 + i.float * 3.0, 12.5 - float(i mod 3), 1.0, 2.0, false)
  addProp(Flag, 8.5, 9.5, 1.0, 2.0, false)
  for i in 0 ..< 6:
    addProp(Rock, 4.5 + i.float * 3.5, 4.5 + float(i mod 2) * 2.0, 1.0, 1.0, false)
  for i in 0 ..< 8:
    addProp(Coin, 3.5 + i.float * 2.5, 7.5 + float(i mod 3), 0.8, 0.8, true)
  g.loaded = true

proc onInit() =
  setAssetHost(AssetBase)
  g.bg = rgba(24, 28, 38, 255)
  g.shade = rgba(18, 20, 28, 190)
  g.text = rgba(235, 238, 245, 255)
  g.dim = rgba(140, 146, 158, 255)
  g.highlight = rgba(255, 230, 140, 255)

  g.centerX = WorldW * 0.5
  g.centerY = WorldH * 0.5
  g.zoom = 12.0
  g.camera = newCamera3d(Projection.Orthographic)
  placeCamera()

  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  g.scene.setInteractive(true)

  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(TilesPath).addTask(onTiles, onFailed):
    onFailed(TilesPath)

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  let mouse = getMouseState()
  let screen = getScreenSize()
  let unitsPerPixel = if screen.y > 0.0: g.zoom / screen.y else: 0.0

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()

  # scroll: drag, or the arrow keys
  if mouse.buttons[0] == ButtonState.Down:
    g.centerX -= mouse.dx.float * unitsPerPixel
    g.centerY += mouse.dy.float * unitsPerPixel # screen y is down, world y is up
  let speed = g.zoom * 0.6 * dt
  if keys.isDown(Key.Left): g.centerX -= speed
  if keys.isDown(Key.Right): g.centerX += speed
  if keys.isDown(Key.Down): g.centerY -= speed
  if keys.isDown(Key.Up): g.centerY += speed
  if mouse.wheel != 0: # zoom: fewer world units visible = closer
    g.zoom = clamp(g.zoom - mouse.wheel * 1.5, 4.0, 32.0)
  g.centerX = clamp(g.centerX, 0.0, WorldW.float)
  g.centerY = clamp(g.centerY, 0.0, WorldH.float)
  placeCamera()

  # coins: hover lights them up, a click collects them
  for i in 0 ..< g.propCount:
    let prop = g.props[i]
    let hover = g.scene.getHover(prop)
    if not g.isCoin[i]: continue
    prop.setTint(if hover in {ButtonState.Pressed, ButtonState.Down}: g.highlight else: ColorWhite)
    if g.scene.isClicked(prop):
      prop.setVisible(false)
      prop.setPickable(false)
      inc g.collected

  beginFrame()
  clearBackground(g.bg)
  g.scene.draw()
  beginMode2d() # back to screen space for the HUD
  drawRectangle(0, 0, screen.x, 88, g.shade)
  drawText("wgrender tilemap (Nim): an orthographic camera over sprite3d tiles", 20, 20, 20, g.text)
  let loading = if g.loaded: "" else: "   (loading)"
  drawText(&"coins: {g.collected} of 8   zoom: {g.zoom:.1f} units   " &
           &"center: {g.centerX:.1f}, {g.centerY:.1f}{loading}", 20, 46, 15, g.dim)
  drawText("drag or arrows to scroll, wheel to zoom, click the coins", 20, 68, 15, g.dim)
  endFrame()

when isMainModule:
  # no MSAA: tiles are blended quads that meet edge to edge, and multisampled edges let
  # the background through as a hairline seam between them
  initValues(960, 600, "tilemap (wgrender, Nim)", {WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
