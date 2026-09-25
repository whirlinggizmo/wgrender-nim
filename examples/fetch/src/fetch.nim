## wgrender fetch example, in Nim: a port of wgrender's examples/fetch.c.
##
## The desktop build pulls its assets from the same site the browser version does. On
## the web the browser downloads a missing asset and caches it. On desktop wgrender
## ships no HTTP client (and no TLS), so it asks the program for one: set a URL as the
## asset host, hand it a fetcher, and a cache miss becomes a download.
##
##     setAssetCacheDir("build/asset-cache")
##     setAssetHost("http://localhost:8000/assets")
##     setFetcher(fetchWithCurl)
##
## The fetcher here shells out to curl, so the example needs nothing built or linked. It
## is synchronous, which is fine for a handful of small files but would hitch a frame on
## a big one; the hook is built for the other way round: a real fetcher starts a
## download and calls fetchDone from a later tick, and nothing blocks meanwhile.
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

import wgr
when not defined(emscripten):
  import std/[os, osproc]

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (wgrender's tools/serve.py mounts examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  TexturePath = "sprites/logo/wg-logo-white-alpha.png"
  # the downloads, in this build's work directory (config.nims: build/linux/release/...);
  # on the web the browser caches
  WorkDir {.strdefine: "wgrWorkDir".} = "build"
  CacheDir = WorkDir & "/asset-cache"
  DefaultHost = "https://raw.githubusercontent.com/whirlinggizmo/wgrender-c/main/examples/assets"

var
  sprite: Sprite2d
  host: string

when not defined(emscripten): # the browser downloads by itself
  var
    remote: bool
    downloads: int

  proc fetchWithCurl(request: AssetRequest; url, destPath: string) =
    ## Download `url` to `destPath`, then say how it went. A real one wouldn't block.
    let ok = execCmd("curl -fsS --max-time 30 -o " & quoteShell(destPath) & " " & quoteShell(url)) == 0
    if ok:
      inc downloads
    request.fetchDone(ok)

  proc hostIsUp(host: string): bool =
    ## Is anything serving there? Keeps the smoke test (and a forgetful human) honest.
    ## (execCmdEx keeps curl's output, the headers, out of the terminal.)
    execCmdEx("curl -fsS -I --max-time 2 " & quoteShell(host & "/" & TexturePath)).exitCode == 0

proc onLoaded(path: string) =
  let texture = newTexture(path)
  sprite.setTexture(texture)
  texture.release() # the sprite holds its own reference

proc onFailed(path: string) = logError("could not get " & path)

proc onInit() =
  discard newCamera3d(Projection.Perspective)
  sprite = newSprite2d()
  sprite.setPosition(512, 380)
  enableFps(12, 10, 16)

  when defined(emscripten):
    host = AssetBase # the browser fetches
  else:
    host = if existsEnv("WGRENDER_ASSET_HOST"): getEnv("WGRENDER_ASSET_HOST") else: DefaultHost
    when defined(wgrHeadless):
      remote = existsEnv("WGRENDER_ASSET_HOST") and hostIsUp(host) # the smoke test stays offline
    else:
      remote = hostIsUp(host)
    if remote:
      setAssetCacheDir(CacheDir)
      setFetcher(fetchWithCurl)
    else:
      host = AssetBase # local directory
  setAssetHost(host)
  if not ensureAssetAsync(TexturePath).addTask(onLoaded, onFailed):
    onFailed(TexturePath)

proc frame(dt, tickFraction: float) =
  beginFrame()
  clearBackground(rgba(28, 30, 38, 255))
  sprite.draw()
  drawText("wgrender fetch (Nim): the desktop build downloads what the browser downloads", 12, 36, 20,
           ColorRaywhite)
  drawText("host: " & host, 12, 64, 16, ColorLightgray)
  when not defined(emscripten):
    drawText(if remote: "downloaded " & $downloads & " file(s) into " & CacheDir &
                        "   (delete it and re-run: they come back)"
             else: "no host reachable — reading " & AssetBase & " locally instead",
             12, 86, 16, ColorLightgray)
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
