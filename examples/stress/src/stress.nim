## wgrender's stress scene (wgrender-c tools/bench/stress.c), in Nim: N entities updated
## every frame, a steady churn of them dying and being replaced, and a screenful of
## formatted text. It follows the C's spec line for line, so every language does the
## same work, and it is written the way Nim naturally would be: an entity is a ref
## object, and a replaced one is a new object, the old one freed by ARC on the spot.

import std/strformat
import wgr
when not defined(emscripten):
  import std/[os, strutils]

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (wgrender's tools/serve.py mounts examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"
  SpritePath = "sprites/logo/wg-logo-bw-alpha.png"
  DefaultN = 2000
  Step = 1.0 / 60.0
  Box = 10.0
  TextLines = 48

type
  Entity = ref object
    x, y, z, vx, vy, vz, angle, spin, life: float
    sprite: Sprite3d

  App = object
    n: int
    rng: uint32
    entities: seq[Entity]
    texture: Texture
    scene: Scene
    background: Color

var g: App

when defined(emscripten):
  proc emscripten_run_script_int(script: cstring): cint {.importc, header: "<emscripten.h>".}

proc entityCount(): int =
  ## ?n= in the page's URL on the web, the first argument (or STRESS_N) on desktop
  let given =
    when defined(emscripten):
      emscripten_run_script_int("+(new URLSearchParams(location.search).get('n')) || 0").int
    else:
      try: parseInt(if paramCount() > 0: paramStr(1) else: getEnv("STRESS_N"))
      except ValueError: 0
  if given > 0: given else: DefaultN

proc rnd(): float =
  ## xorshift32, as the spec gives it
  var x = g.rng
  x = x xor (x shl 13)
  x = x xor (x shr 17)
  x = x xor (x shl 5)
  g.rng = x
  float(x shr 8) / 16777216.0

proc spawn(): Entity =
  result = Entity()
  result.x = (rnd() * 2 - 1) * Box / 2
  result.y = 1 + rnd() * 4
  result.z = (rnd() * 2 - 1) * Box / 2
  result.vx = (rnd() * 2 - 1) * 4
  result.vy = 4 + rnd() * 6
  result.vz = (rnd() * 2 - 1) * 4
  result.spin = (rnd() * 2 - 1) * 3
  result.life = 2 + rnd() * 4
  result.sprite = newSprite3d(g.texture)
  result.sprite.setFacing(SpriteFacing.Free)
  g.scene.add(result.sprite)

proc update(i: int) =
  let e = g.entities[i]
  e.vy -= 9.8 * Step
  e.x += e.vx * Step
  e.y += e.vy * Step
  e.z += e.vz * Step
  if e.y < 0:
    e.y = 0
    e.vy = -e.vy * 0.8
  if abs(e.x) > Box:
    e.x = (if e.x > 0: Box else: -Box)
    e.vx = -e.vx
  if abs(e.z) > Box:
    e.z = (if e.z > 0: Box else: -Box)
    e.vz = -e.vz
  e.angle += e.spin * Step
  e.life -= Step
  e.sprite.setTransform((e.x, e.y, e.z), (0.0, e.angle, 0.0), (0.5, 0.5, 0.5))
  if e.life <= 0:
    e.sprite.destroy()
    g.entities[i] = spawn() # a new object; ARC frees the old one here

proc onInit() =
  setAssetHost(AssetBase)
  setLogLevel(LogLevel.Warn)
  setTargetFps(60)
  g.rng = 2463534242'u32

  let camera = newCamera3d(Projection.Perspective)
  camera.setView((0.0, 14.0, 30.0), (0.0, 3.0, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(camera)
  g.background = rgba(245, 245, 245, 255)

  let onFailed = proc (path: string) = logError("failed to import asset: " & path)
  let onReady = proc (path: string) =
    g.texture = newTexture(path)
    for _ in 0 ..< g.n:
      g.entities.add spawn()
  if not ensureAssetAsync(SpritePath).addTask(onReady, onFailed):
    onFailed(SpritePath)

proc drawText() =
  drawText(&"stress: {g.n} entities", 10, 10, 16, ColorBlack)
  for i in 0 ..< min(TextLines, g.entities.len):
    let e = g.entities[i]
    drawText(&"e{i}: {e.x:.2f} {e.y:.2f} {e.z:.2f} life {e.life:.2f}", 10, 34 + 18 * i, 16, ColorBlack)

proc frame(dt, tickFraction: float) =
  for i in 0 ..< g.entities.len:
    update(i)
  beginFrame()
  clearBackground(g.background)
  g.scene.draw()
  drawText()
  endFrame()

when isMainModule:
  g.n = entityCount()
  initValues(1024, 1280, "stress (wgrender, Nim)", {WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
