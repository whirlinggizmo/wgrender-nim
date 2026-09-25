## wgrender force_fetch example, in Nim: a port of wgrender's examples/force_fetch.c.
##
## Exercises both ensure overrides at once: `fetchUrl` (per-call source override) and
## AssetFlag.ForceFetch. The asset KEY is a bogus path (nothing exists at host + key, so
## a plain ensure would just fail), while `fetchUrl` points at an explicit source URL
## and ForceFetch bypasses the cache. On web the bytes are pulled from that URL and
## cached under the key; on desktop (no network fetcher yet) it falls back to loading
## the real file locally so the example still plays. Press M to toggle the looping
## music.

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
  InvalidMusicPath = "music/ethernight_club_invalid.mp3" # intentionally invalid to demonstrate force_fetch
  # explicit source URL, used verbatim. Relative to the page, so it works on whatever
  # host serves the site and at whatever depth -- "/assets/..." would be the server
  # root, which is wrong wherever the site isn't at one (GitHub Pages serves a project
  # under /<repo>/). An absolute https://cdn.example/... URL is passed through the same way.
  MusicForceFetchPath = "assets/music/ethernight_club.mp3"

var
  background: Color
  music: Sound
  musicOn: bool

proc onMusicLoaded(path: string) =
  let audio = newAudio(path)
  music = newSound(audio)
  audio.release() # the sound holds its own reference
  music.setVolume(0.5)
  music.setLoop(true) # "music" is just a looping sound
  music.play()
  musicOn = true

proc onFailed(path: string) = logError("load failed: " & path)

proc onInit() =
  setAssetHost(AssetBase)
  background = rgba(18, 20, 28, 255)

  if getPlatform() == "web":
    # Web: demonstrate fetchUrl + ForceFetch. The key (InvalidMusicPath) is a bogus
    # path, so the bytes can only come from the explicit source URL, proving the
    # override is honored and cached under the key.
    ensureAssetAsync(InvalidMusicPath, MusicForceFetchPath, {AssetFlag.ForceFetch})
      .addTask(onMusicLoaded, onFailed)
    logInfo("force_fetch: " & InvalidMusicPath & " from " & MusicForceFetchPath)
  else:
    # Desktop has no network fetcher yet, so fetchUrl/ForceFetch are no-ops; load the
    # real file from the local asset dir so the example still plays.
    ensureAssetAsync(MusicPath).addTask(onMusicLoaded, onFailed)
    logInfo("force_fetch is web-only; loading " & MusicPath & " locally on desktop")

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()

  if keys.isPressed(Key.M) and not music.isNone:
    if musicOn: music.pause() else: music.resume()
    musicOn = not musicOn

  beginFrame()
  clearBackground(background)

  drawText("wgrender + sokol_audio + force_fetch (Nim)", 24, 30, 28, ColorRaywhite)
  drawText(if music.isNone: "music: loading..."
           elif musicOn: "music: playing (mp3, looping)"
           else: "music: paused",
           24, 80, 18, ColorSkyblue)
  drawText("[M] toggle music   [ESC] quit", 24, 150, 16, ColorLightgray)

  drawFps(24, 12)
  endFrame()

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()

when isMainModule:
  setLogLevel(LogLevel.Info)
  initValues(720, 240, "force_fetch (wgrender, Nim)", {WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
