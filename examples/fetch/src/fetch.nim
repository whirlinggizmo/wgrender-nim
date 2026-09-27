## wgrender fetch example, in Nim: a port of wgrender's examples/fetch.c.
##
## The desktop build pulls its assets from the same site the browser version does. On
## the web the browser downloads a missing asset and caches it. On desktop wgrender
## ships no HTTP client (and no TLS), so it asks the program for one: set a URL as the
## asset host, hand it a fetcher, and a cache miss becomes a download.
##
##     setAssetCacheDir("build/asset-cache")
##     setAssetHost("http://localhost:8000/assets")
##
## So there is nothing here to write: this example builds with -d:wgrIncludeFetcher (its
## config.nims), and the binding installs its httpFetcher the first time an http(s) URL
## appears. That is puppy (the binding requires it), which asks the system's own HTTP --
## WinHTTP, Apple's URL loading, libcurl -- so nothing ships beside the program, and
## HTTPS uses the system's certificates. A program that wants its own fetcher still
## sets one (setFetcher), and the binding leaves it be. httpFetcher is synchronous,
## which is fine for a handful of small files but would hitch a frame on a big one; the
## hook is built for the other way round: a real fetcher starts a download and calls
## fetchDone from a later tick, and nothing blocks meanwhile.
##
## Bytes never cross the boundary: wgrender names a URL and a destination file, the
## fetcher writes that file. Downloads land in the cache directory and the next run
## finds them there, which is the job the browser's cache does on web.
##
## It downloads from the project's own assets on GitHub, over HTTPS, so there is nothing
## to start first, and nothing in wgrender did the TLS. Point it somewhere else with
## WGRENDER_ASSET_HOST, e.g. the dev server the web build uses:
##
##     nim serve
##     WGRENDER_ASSET_HOST=http://localhost:8000/assets out/linux/release/fetch
##
## Offline, or built headless for the smoke test (a gate shouldn't need a network), it
## reads the local asset directory instead and says so.
##
## Two buttons (ui_widgets, from examples/shared/ui) show the cache at work: Fetch asset
## loads the logo again, and Clear cache forgets what was downloaded, so the next fetch
## downloads it again. The line under them says what happened -- on desktop, whether the
## file came from the cache or was downloaded, told by looking in the cache directory
## first (getAssetCacheDir). The web keeps its cache in the browser, where the example
## can't look, so there it just says loaded.

import wgr
import ../../shared/ui/ui_widgets
when not defined(emscripten):
  import std/os
  import puppy

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (tools/serve.py mounts wgrender's examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  TexturePath = "sprites/logo/wg-logo-white-alpha.png"
  # the downloads, in this build's work directory (config.nims: build/linux/release/...);
  # on the web the browser caches
  WorkDir {.strdefine: "wgrWorkDir".} = "build"
  CacheDir = WorkDir & "/asset-cache"
  DefaultHost = "https://raw.githubusercontent.com/whirlinggizmo/wgrender-c/main/examples/assets"

const LayerControl = 1 # a button's label goes on the layer above (ui_widgets)

var
  sprite: Sprite2d
  host: string
  scene: Scene
  theme: Theme
  fetchButton, clearButton: Button
  state: string

when not defined(emscripten): # the browser downloads by itself
  var
    remote: bool
    wasCached: bool # the file was in the cache before this fetch

  proc hostIsUp(host: string): bool =
    ## Is anything serving there? Keeps the smoke test (and a forgetful human) honest.
    try:
      puppy.head(host & "/" & TexturePath, timeout = 2).code in 200 .. 299
    except CatchableError:
      false

proc onLoaded(path: string) =
  let texture = newTexture(path)
  sprite.setTexture(texture)
  texture.release() # the sprite holds its own reference
  when defined(emscripten):
    state = "loaded " & TexturePath
  else:
    state = if not remote: "read " & TexturePath & " from " & AssetBase
            elif wasCached: "loaded " & TexturePath & " from the cache"
            else: "downloaded " & TexturePath & " into the cache"
  fetchButton.setEnabled(true)

proc onFailed(path: string) =
  logError("could not get " & path)
  state = "failed to get " & TexturePath
  fetchButton.setEnabled(true)

proc fetch() =
  ## Load the logo again, having noted whether the cache has it already.
  when not defined(emscripten):
    wasCached = remote and fileExists(getAssetCacheDir() / TexturePath)
  sprite.setTexture(Texture(0)) # so a fetch is seen to happen
  fetchButton.setEnabled(false)
  state = "fetching " & TexturePath & "..."
  if not ensureAssetAsync(TexturePath).addTask(onLoaded, onFailed):
    onFailed(TexturePath)

proc onInit() =
  let camera = newCamera3d(Projection.Perspective)
  sprite = newSprite2d()
  sprite.setPosition(512, 380)
  enableFps(12, 10, 16)

  theme = defaultTheme()
  scene = newScene()
  scene.setActiveCamera(camera)
  scene.setInteractive(true)
  fetchButton = newButton(scene, LayerControl, "Fetch asset", 12, 150, 180, 40, 17)
  clearButton = newButton(scene, LayerControl, "Clear cache", 204, 150, 180, 40, 17)

  when defined(emscripten):
    host = AssetBase # the browser fetches
  else:
    host = if existsEnv("WGRENDER_ASSET_HOST"): getEnv("WGRENDER_ASSET_HOST") else: DefaultHost
    when defined(wgrHeadless):
      remote = existsEnv("WGRENDER_ASSET_HOST") and hostIsUp(host) # the smoke test stays offline
    else:
      remote = hostIsUp(host)
    if remote:
      setAssetCacheDir(CacheDir) # the host is set below, and brings the fetcher
    else:
      host = AssetBase # local directory
  setAssetHost(host)
  fetch()

proc frame(dt, tickFraction: float) =
  if fetchButton.update(scene, theme):
    fetch()
  if clearButton.update(scene, theme):
    clearAssetCache()
    state = "cache cleared: the next fetch downloads"

  beginFrame()
  clearBackground(rgba(28, 30, 38, 255))
  sprite.draw()
  scene.draw()
  drawText("wgrender fetch (Nim): the desktop build downloads what the browser downloads", 12, 36, 20,
           ColorRaywhite)
  drawText("host: " & host, 12, 64, 16, ColorLightgray)
  when not defined(emscripten):
    drawText(if remote: "cache: " & getAssetCacheDir()
             else: "no host reachable — reading " & AssetBase & " locally instead",
             12, 86, 16, ColorLightgray)
  drawText(state, 12, 120, 18, ColorSkyblue)
  endFrame()

  when not defined(emscripten): # a web page has nothing to quit to
    if isKeyPressed(Key.Escape): requestQuit()

when isMainModule:
  initValues(1024, 640, "fetch (wgrender, Nim)", {WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
