## wgrender lights example, in Nim: a port of wgrender's examples/lights.c.
##
## Directional, point and spot lights in a scene. Five animated models on a grid: a dim
## warm sun (directional); a cyan point light orbiting through them, falling off with
## its range (the small sphere marks it; shapes are unlit, so it shows the light's
## color); a white spotlight sweeping across them from above. Behind them stand
## billboard sprites with a built-in material: they take the same lights as the
## models, facing the camera. Each shows one cell of the tilemap example's sprite
## sheet, and the sheet's normal map gives it relief: the normal map is sampled through
## the same region. Scenes start unlit (no lights, no ambient); everything here is
## explicit. Keys: 1 sun, 2 point light, 3 spotlight.

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

  CharacterPath = "models/woman_casual/woman_casual.glb"
  SpritePath = "textures/tiles.png"
  NormalPath = "textures/tiles_sheet_normal.png" # wgrender's tools/gen_tiles.py

  # the sprites' cells in the sheet (pixels, from wgrender's tools/gen_tiles.py) and
  # their world height; all 1.6 wide
  SpriteCells = [
    (x: 62.0, y: 2.0, width: 16.0, height: 16.0, worldHeight: 1.6), # stone
    (x: 2.0, y: 22.0, width: 16.0, height: 32.0, worldHeight: 3.2), # tree
    (x: 42.0, y: 22.0, width: 16.0, height: 16.0, worldHeight: 1.6), # coin
    (x: 62.0, y: 22.0, width: 16.0, height: 16.0, worldHeight: 1.6), # rock
  ]

type App = object
  scene: Scene
  camera: Camera3d
  background, grid: Color
  models: array[5, Model]
  sprites: array[4, Sprite3d] # lit billboards: one material, the same lights
  spriteMaterial: Material
  sun, lamp, spot: Light
  lampMarker: Shape3d
  time: float

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc toggle(light: Light) = light.setEnabled(not light.isEnabled)

proc onInit() =
  setAssetHost(AssetBase)
  g.background = rgba(12, 13, 18, 255)
  g.grid = rgba(40, 42, 50, 255)
  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (0.0, 4.5, 10.0), target = (0.0, 1.0, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  g.scene.setAmbient(rgba(90, 110, 160, 255), 0.05)

  for i, model in g.models.mpairs:
    model = newModel()
    model.setTransform((-4.0 + 2.0 * i.float, 0.0, (if i mod 2 == 1: -0.8 else: 0.8)),
                       (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
    model.setAnimation(3)
    model.setAnimationLoop(true)
    g.scene.add(model)

  g.sun = newLight(LightKind.Directional)
  g.sun.setDirection((-0.4, -1.0, -0.6))
  g.sun.setColor(rgba(255, 210, 160, 255))
  g.sun.setIntensity(1.1)
  g.scene.add(g.sun)

  g.lamp = newLight(LightKind.Point)
  g.lamp.setColor(rgba(60, 220, 255, 255))
  g.lamp.setIntensity(20)
  g.lamp.setRange(5)
  g.scene.add(g.lamp)
  g.lampMarker = newShape3d()
  g.lampMarker.setSphere(0.12)
  g.lampMarker.setColor(rgba(60, 220, 255, 255))
  g.scene.add(g.lampMarker)

  g.spot = newLight(LightKind.Spot)
  g.spot.setPosition(0, 6, 2)
  g.spot.setSpotCone(0.14, 0.28) # radians: about 8 and 16 degrees
  g.spot.setIntensity(125)
  g.scene.add(g.spot)

  # lit billboards: a built-in material, so the scene's lights reach them
  g.spriteMaterial = newMaterial(MaterialShading.Pbr)
  g.spriteMaterial.setFloat("metallic", 0.0)
  g.spriteMaterial.setFloat("roughness", 0.55)
  # cells sit side by side in the sheet: clamp, so none reaches into the next
  g.spriteMaterial.setTextureSampling("normal_texture", TextureWrap.Clamp, TextureWrap.Clamp,
                                      TextureFilter.Linear)
  for i, sprite in g.sprites.mpairs:
    let cell = SpriteCells[i]
    sprite = newSprite3d()
    sprite.setTransform((-3.0 + 2.0 * i.float, 0.2, -2.5), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
    sprite.setSource(cell.x, cell.y, cell.width, cell.height)
    sprite.setExtent(1.6, cell.worldHeight)
    sprite.setPivot(0.5, 1.0) # standing on their bottom edge
    sprite.setAlphaMode(AlphaMode.Mask, 0.5)
    sprite.setMaterial(g.spriteMaterial)
    g.scene.add(sprite)
  g.spriteMaterial.release() # the sprites hold it

  load(CharacterPath) do (path: string):
    let mesh = newMesh(path)
    for model in g.models: model.setMesh(mesh)
    mesh.release() # the models hold their own references
  load(SpritePath) do (path: string):
    let texture = newTexture(path)
    texture.setSampling(TextureWrap.Clamp, TextureWrap.Clamp, TextureFilter.Nearest)
    for sprite in g.sprites: sprite.setTexture(texture)
    texture.release() # the sprites hold their own references
  load(NormalPath) do (path: string):
    let texture = newTexture(path)
    g.spriteMaterial.setTexture("normal_texture", texture)
    texture.release()

proc onOff(light: Light): string = (if light.isEnabled: "on " else: "off")

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  if keys.isPressed(Key.Digit1): toggle(g.sun)
  if keys.isPressed(Key.Digit2): toggle(g.lamp)
  if keys.isPressed(Key.Digit3): toggle(g.spot)
  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()

  g.time += dt
  for model in g.models: model.animate(dt)
  # the point light orbits through the row; the spot sweeps left and right
  let lamp = (sin(g.time * 0.6) * 5, 1.2, cos(g.time * 0.6) * 2)
  g.lamp.setPosition(lamp)
  g.lampMarker.setTransform(lamp, (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.lampMarker.setVisible(g.lamp.isEnabled)
  g.spot.setDirection((sin(g.time * 0.8) * 0.7, -1.0, -0.3))

  beginFrame()
  clearBackground(g.background)
  beginMode3d()
  drawGrid(20, 1.0, g.grid)
  endMode3d()
  g.scene.draw()
  drawText("wgrender lights (Nim): directional, point, spot", 12, 12, 20, ColorRaywhite)
  drawText("[1] sun " & g.sun.onOff & "   [2] point light " & g.lamp.onOff &
           "   [3] spotlight " & g.spot.onOff, 12, 40, 16, ColorLightgray)
  drawFps(12, 64)
  endFrame()

when isMainModule:
  initValues(1000, 600, "lights (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
