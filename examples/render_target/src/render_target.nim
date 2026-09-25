## wgrender render_target example, in Nim: a port of wgrender's examples/render_target.c.
##
## Drawing into textures.
##   - "pixel view": the scene drawn into a 160x100 texture and shown 4x larger with
##     nearest filtering (a low-resolution pixel-art look)
##   - "minimap": the same scene from a top-down orthographic camera, in a 256x256
##     texture
##   - "label": text in two fonts drawn into a 256x128 texture, used as the base color
##     texture of the spinning sphere's material (and shown on its own)
## Each frame draws the label first, so the scene views that use it show this frame's
## label. Keys: ESC quit.

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

  WomanCasualPath = "models/woman_casual/woman_casual.glb"
  SpherePath = "models/sphere/sphere.glb"
  FontPath = "fonts/Komika/KOMIKAH_.ttf"

  PixelW = 160
  PixelH = 100
  PixelScale = 4
  Minimap = 256
  LabelW = 256
  LabelH = 128

type App = object
  scene: Scene
  camera: Camera3d
  topCamera: Camera3d
  bg, labelBg, minimapBg, frameColor: Color
  pixelView, minimap, label: Texture # render target textures
  font: Font
  womanCasual, globe, ground: Model
  time: float

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc createModel(x, y, z, scaleY, scale: float; material: Material): Model =
  result = newModel()
  result.setTransform((x, y, z), (0.0, 0.0, 0.0), (scale, scaleY, scale))
  if not material.isNone:
    result.setMaterial(0, material)
    material.release() # the model keeps its own reference
  g.scene.add(result)

proc onInit() =
  setAssetHost(AssetBase)
  g.bg = rgba(24, 26, 34, 255)
  g.labelBg = rgba(30, 60, 140, 255)
  g.minimapBg = rgba(12, 14, 18, 255)
  g.frameColor = rgba(90, 96, 110, 255)

  g.pixelView = newTextureTarget(PixelW, PixelH)
  g.pixelView.setSampling(TextureWrap.Clamp, TextureWrap.Clamp, TextureFilter.Nearest)
  g.minimap = newTextureTarget(Minimap, Minimap)
  g.label = newTextureTarget(LabelW, LabelH)

  g.scene = newScene()
  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (0.0, 6.0, 10.0), target = (0.0, 0.8, 0.0))
  g.topCamera = newCamera3d(Projection.Orthographic)
  g.topCamera.setView(position = (0.0, 12.0, 0.0), target = (0.0, 0.0, 0.0),
                      up = (0.0, 0.0, -1.0)) # looking down, -z up the map
  g.topCamera.setOrthoHeight(9.0)

  let sun = newLight(LightKind.Directional)
  sun.setDirection((-0.5, -1.0, -0.4))
  sun.setIntensity(3.0)
  g.scene.add(sun)
  g.scene.setAmbient(ColorWhite, 0.25)

  # ground: a flattened sphere
  var material = newMaterial(MaterialShading.Pbr)
  material.setVec4("base_color", (0.25, 0.3, 0.25, 1.0))
  material.setFloat("metallic", 0.0)
  g.ground = createModel(0, -0.05, 0, 0.1, 8.0, material)

  g.womanCasual = newModel()
  g.womanCasual.setAnimation(3)
  g.scene.add(g.womanCasual)

  # the globe wears the label texture: drawn into each frame, used like any texture
  material = newMaterial(MaterialShading.Unlit)
  material.setTexture("base_color_texture", g.label)
  material.setVec2("base_color_texture_scale", (2.0, 1.0)) # twice around
  g.globe = createModel(2.2, 1.2, 0, 1.6, 1.6, material)

  load(WomanCasualPath) do (path: string):
    let mesh = newMesh(path)
    g.womanCasual.setMesh(mesh)
    mesh.release()
  load(SpherePath) do (path: string):
    let mesh = newMesh(path)
    g.globe.setMesh(mesh)
    g.ground.setMesh(mesh)
    mesh.release()
  load(FontPath) do (path: string):
    g.font = newFont(path)

proc drawPanel(texture: Texture; x, y, w, h: float; caption: string) =
  ## A texture with a 2px frame and a caption above it.
  drawRectangle(float(x.int - 2), float(y.int - 2), float(w.int + 4), float(h.int + 4), g.frameColor)
  texture.draw(x, y, w, h, ColorWhite)
  drawText(caption, x.int, y.int - 20, 16, ColorLightgray)

proc frame(dt, tickFraction: float) =
  let gx = cos(g.time * 0.6) * 2.5
  let gz = sin(g.time * 0.6) * 2.5

  when not defined(emscripten): # a web page has nothing to quit to
    if isKeyPressed(Key.Escape): requestQuit()
  g.time += dt
  g.womanCasual.setTransform((gx, 0.0, gz), (0.0, -g.time * 0.6, 0.0), (0.6, 0.6, 0.6)) # walks in a circle
  g.womanCasual.animate(dt)
  g.globe.setTransform((-2.2, 1.2, 0.0), (0.0, g.time * 0.8, 0.0), (1.6, 1.6, 1.6))

  beginFrame()

  # 1. the label, first, so the views below use this frame's text
  if beginTexture(g.label):
    clearBackground(g.labelBg)
    g.font.drawText("wgrender", 20, 14, 64, ColorRaywhite)
    drawText(&"t = {g.time:.1f}", 24, 92, 16, ColorGold)
    endTexture()

  # 2. low-resolution view of the scene
  if beginTexture(g.pixelView):
    clearBackground(g.bg)
    g.scene.setActiveCamera(g.camera)
    g.scene.draw()
    endTexture()

  # 3. minimap from above
  if beginTexture(g.minimap):
    clearBackground(g.minimapBg)
    g.scene.setActiveCamera(g.topCamera)
    g.scene.draw()
    endTexture()

  # the screen
  clearBackground(g.bg)
  drawPanel(g.pixelView, 24, 64, PixelW * PixelScale, PixelH * PixelScale,
            "pixel view (160x100, nearest)")
  drawPanel(g.minimap, 700, 64, Minimap, Minimap, "minimap (orthographic, from above)")
  drawPanel(g.label, 700, 380, LabelW, LabelH, "label (text drawn into a texture)")
  drawText("wgrender render targets (Nim): newTextureTarget + beginTexture", 12, 12, 16,
           ColorRaywhite)
  endFrame()

when isMainModule:
  initValues(1000, 560, "render_target (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
