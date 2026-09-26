## wgrender quit example, in Nim: a port of wgrender's examples/quit.c.
##
## requestQuit while audio plays and files are loading. Plays music, and after a second
## starts loading two environments, keeps the main thread busy for half a second (like a
## long synchronous load) and quits. That is the path that used to crash on web: audio
## events queued during the busy frame ran after shutdown. Cleanup then runs with loads
## still in progress.
##
## On web, quitting stops the frame loop and runs cleanup; the canvas keeps showing the
## last frame.
##
##   Q    quit now
##   ESC  quit now (desktop)

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

type App = object
  music: Sound
  background: Color
  quitAt: float
  quitting: bool

var g: App

proc onMusic(path: string) =
  let audio = newAudio(path)
  g.music = newSound(audio)
  audio.release() # the sound keeps its own reference
  g.music.setLoop(true)
  g.music.play()

proc onEnvironment(path: string) =
  discard # only started to be in flight at quit; never created

proc onInit() =
  setAssetHost(AssetBase)
  setAssetManifest(AssetManifestName)
  g.background = rgba(30, 36, 48, 255)
  g.quitAt = getTime() + 1.0 # soon enough for tools/webcheck.py to see the quit
  ensureAssetAsync("music/a_hero_is_born.mp3").addTask(onMusic)

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  if keys.isPressed(Key.Q):
    requestQuit()
  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()

  beginFrame()
  clearBackground(g.background)
  drawText("wgrender quit (Nim)   Q: quit now", 12, 12, 16, ColorRaywhite)
  if g.quitting:
    drawText("quit requested: cleanup runs after this frame", 12, 40, 16, ColorLightgray)
  else:
    drawText(&"loading, stalling and quitting in {g.quitAt - getTime():.1f} s", 12, 40, 16,
             ColorLightgray)
  endFrame()

  if not g.quitting and getTime() >= g.quitAt:
    g.quitting = true
    ensureAssetAsync("environments/venice_sunset_1k.hdr").addTask(onEnvironment)
    ensureAssetAsync("environments/studio_small_09_1k.hdr").addTask(onEnvironment)
    let busyUntil = getTime() + 0.5 # a long synchronous frame
    while getTime() < busyUntil:
      discard
    requestQuit()

proc cleanup() =
  logInfo("quit: cleanup")

when isMainModule:
  initValues(640, 200, "quit (wgrender, Nim)", {WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  setCleanup(cleanup)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
