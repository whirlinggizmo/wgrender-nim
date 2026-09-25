## wgrender sprite3d example, in Nim: a port of wgrender's examples/sprite3d.c.
##
## Async asset load + textured billboard in a scene. The handle-only flow:
##   ensureAssetAsync(png) -> onReady(path) -> newTexture(path) -> newSprite3d(texture)
##   -> scene.add. The sprite bobs and faces the camera.

import std/math
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (wgrender's tools/serve.py mounts examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  LogoPath = "sprites/logo/wg-logo-bw-alpha.png"

type App = object
  scene: Scene
  camera: Camera3d
  bg: Color
  sprite: Sprite3d # set once the texture finishes loading
  loaded: bool

var g: App

proc onLogoLoaded(path: string) =
  let texture = newTexture(path)
  g.sprite = newSprite3d(texture)
  texture.release() # the sprite holds its own reference
  if g.sprite.isNone:
    return
  g.sprite.setSize(6.0)
  g.sprite.setFacing(SpriteFacing.Camera)
  g.sprite.setTint(ColorWhite)
  g.scene.add(g.sprite, layer = 1)
  g.loaded = true

proc onInit() =
  setAssetHost(AssetBase)
  g.bg = rgba(20, 22, 30, 255)
  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (12.0, 7.0, 12.0), target = (0.0, 2.5, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  # a couple of ground shapes for depth reference
  let pedestal = newShape3d()
  pedestal.setCube((3.0, 0.5, 3.0))
  pedestal.setTransform((0.0, 0.25, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  pedestal.setColor(ColorDarkgray)
  g.scene.add(pedestal)

  let onFailed = proc (path: string) = logError("could not load " & path)
  if not ensureAssetAsync(LogoPath).addTask(onLogoLoaded, onFailed):
    onFailed(LogoPath)
  enableFps(12, 10, 16)

proc frame(dt, tickFraction: float) =
  let t = getTime()

  g.camera.setView(position = (cos(t * 0.3) * 13.0, 7.0, sin(t * 0.3) * 13.0),
                   target = (0.0, 2.5, 0.0))

  if g.loaded:
    let y = 3.5 + sin(t * 1.5) * 0.8 # bob
    g.sprite.setTransform((0.0, y, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))

  beginFrame()
  clearBackground(g.bg)

  beginMode3d()
  drawGrid(20, 1.0, ColorDarkgray)
  endMode3d()

  g.scene.draw()

  drawText("wgrender sprite3d (Nim)", 12, 36, 24, ColorRaywhite)
  drawText(if g.loaded: "logo: ensure -> texture_create -> sprite" else: "loading logo...",
           12, 70, 16, ColorLightgray)

  endFrame()

  # Escape quits on desktop; a web page has nothing to quit to.
  when not defined(emscripten):
    if isKeyPressed(Key.Escape):
      requestQuit()

when isMainModule:
  initValues(900, 700, "sprite3d (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
