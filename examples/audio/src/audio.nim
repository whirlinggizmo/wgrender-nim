## wgrender audio example, in Nim: a port of wgrender's examples/audio.c.
##
## Looping mp3 music + a one-shot ogg sound. Each file is ensured local (async), then
## newAudio(path) makes a shared Audio resource: the 6 MB music is streamed (decoded
## while playing), the small click is decoded up front. Sound objects play them. On
## desktop mixing runs on the audio device's thread, so music keeps playing through a
## slow frame: press S to stall one frame for 300 ms and hear it not care. On the web it
## stutters instead: sokol_audio's WebAudio callback (a ScriptProcessorNode) runs on the
## main thread, the one the stall blocks, and its ~46 ms buffer runs dry. Press SPACE to
## play the click, M to toggle music.

import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (wgrender's tools/serve.py mounts examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  MusicPath = "music/ethernight_club.mp3"
  ClickPath = "sounds/click_004.ogg"

var
  background: Color
  music: Sound
  click: Sound
  musicOn: bool

proc onMusicLoaded(path: string) =
  let audio = newAudio(path)
  music = newSound(audio)
  audio.release() # the sound holds its own reference
  music.setVolume(0.5)
  music.setLoop(true) # "music" is just a looping sound
  music.play()
  musicOn = true

proc onClickLoaded(path: string) =
  let audio = newAudio(path)
  click = newSound(audio)
  audio.release() # the sound object holds its own reference
  click.setVolume(1.0)

proc onFailed(path: string) = logError("load failed: " & path)

proc load(path: string; onReady: proc (path: string)) =
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc onInit() =
  setAssetHost(AssetBase)
  background = rgba(18, 20, 28, 255)
  load(MusicPath, onMusicLoaded)
  load(ClickPath, onClickLoaded)

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()

  if keys.isPressed(Key.Space) and not click.isNone:
    click.play()
  if keys.isPressed(Key.S):
    let until = getTime() + 0.3 # a deliberately slow frame
    while getTime() < until:
      discard
  if keys.isPressed(Key.M) and not music.isNone:
    if musicOn: music.pause() else: music.resume()
    musicOn = not musicOn

  beginFrame()
  clearBackground(background)

  drawText("wgrender + sokol_audio (Nim)", 24, 30, 28, ColorRaywhite)
  drawText(if music.isNone: "music: loading..."
           elif musicOn: "music: playing (mp3, streamed, looping)"
           else: "music: paused",
           24, 80, 18, ColorSkyblue)
  drawText(if click.isNone: "click: loading..." else: "click: ready (ogg)",
           24, 110, 18, ColorLime)
  drawText("[SPACE] play click   [M] toggle music   [S] stall 300 ms   [ESC] quit",
           24, 150, 16, ColorLightgray)

  drawFps(24, 12)
  endFrame()

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()

when isMainModule:
  initValues(720, 240, "audio (wgrender, Nim)", {WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
