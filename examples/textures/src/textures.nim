## wgrender textures example, in Nim: a port of wgrender's examples/textures.c.
##
## Compressed textures. Each texture twice: loaded from its PNG (left), and as
## "name.ktx" (right), for which wgrender picks the file this GPU can use
## (name.bc7.ktx on desktops, name.astc.ktx on phones, name.etc2.ktx on older phones,
## else name.png), made beforehand by wgrender's tools/compress_textures.py. Under
## each: the file that was loaded, what it takes in GPU memory (with mipmaps) and how
## long it took from asking to having it.

import std/[math, strformat, strutils]
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (tools/serve.py mounts wgrender's examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  Names = ["sprites/logo/wg-logo-bw-alpha", "textures/flame"]
  Kinds = ["png", "ktx"]

type Slot = object
  sprite: Sprite2d
  loaded: string
  asked, took: float
  width, height: int

var slots: array[Names.len, array[Kinds.len, Slot]]

proc load(t, k: int) =
  let path = Names[t] & "." & Kinds[k]
  slots[t][k].asked = getTime()
  let onLoaded = proc (path: string) =
    var slot = addr slots[t][k]
    slot.took = getTime() - slot.asked
    slot.loaded = path
    let texture = newTexture(path)
    if texture.isNone: return
    let size = texture.getSize()
    slot.width = size.x.int
    slot.height = size.y.int
    slot.sprite = newSprite2d(texture)
    texture.release() # the sprite holds its own reference
    slot.sprite.setSize(220, 220)
  let onFailed = proc (path: string) = slots[t][k].loaded = "failed: " & path
  if not ensureAssetAsync(path).addTask(onLoaded, onFailed):
    onFailed(path)

proc onInit() =
  setAssetHost(AssetBase)
  for t in 0 ..< Names.len:
    for k in 0 ..< Kinds.len:
      load(t, k)

proc gpuKb(slot: Slot): float =
  ## GPU memory with the full mipmap chain (a third more): 4 bytes a pixel as RGBA, 1 as
  ## BC7 / ASTC 4x4 / ETC2 RGBA
  let bytesPerPixel = if ".ktx" in slot.loaded: 1.0 else: 4.0
  float(slot.width * slot.height) * bytesPerPixel * 4 / 3 / 1024

proc frame(dt, tickFraction: float) =
  beginFrame()
  clearBackground(rgba(38, 42, 54, 255))
  drawText("wgrender textures (Nim): PNG (left) and compressed (right)", 12, 36, 22, ColorRaywhite)
  for t in 0 ..< Names.len:
    for k in 0 ..< Kinds.len:
      let slot = slots[t][k]
      let x = 20.0 + float(t * Kinds.len + k) * 245
      let y = 80.0
      if not slot.sprite.isNone:
        slot.sprite.setPosition(x + 110, y + 110) # the pivot: the middle
        slot.sprite.draw()
      drawText(if slot.loaded.len > 0: slot.loaded.rsplit('/', 1)[^1] else: "loading...",
               x.int, y.int + 236, 16, ColorLightgray)
      if not slot.sprite.isNone:
        drawText(&"{slot.width}x{slot.height}  GPU {int(round(slot.gpuKb))} KB  {int(round(slot.took * 1000))} ms",
                 x.int, y.int + 258, 14, ColorLightgray)
  endFrame()

  # Escape quits on desktop; a web page has nothing to quit to.
  when not defined(emscripten):
    if isKeyPressed(Key.Escape):
      requestQuit()

when isMainModule:
  initValues(1000, 380, "textures (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
