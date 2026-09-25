## wgr_asset.h, wrapped.

import ./types, ./internal/convert, ./raw

type AssetCallbacks = ref object
  onSuccess, onFailure: AssetCallback

# wgrender fires exactly one of a task's callbacks, then frees the task, so each
# trampoline releases the closures it was handed.
proc finish(user: pointer; path: WgrConstCstring; success: bool) =
  let task = cast[AssetCallbacks](user)
  let cb = if success: task.onSuccess else: task.onFailure
  GC_unref(task)
  if cb != nil: cb($cstring(path))

proc assetSuccessTrampoline(path: WgrConstCstring; user: pointer) {.cdecl.} =
  finish(user, path, true)

proc assetFailureTrampoline(path: WgrConstCstring; user: pointer) {.cdecl.} =
  finish(user, path, false)

proc setAssetHost*(host: string) = wgr_asset_set_host(host.cstring)

proc getAssetHost*(): string = $wgr_asset_get_host()

proc setAssetCacheDir*(dir: string): bool {.discardable.} =
  ## where downloads are kept on desktop (the web keeps them in the browser)
  wgr_asset_set_cache_dir(dir.cstring)

proc evictAsset*(path: string): bool {.discardable.} = wgr_asset_evict(path.cstring) ## drop it from the cache

proc clearAssetCache*() = wgr_asset_clear_cache()

proc addAssetRedirect*(prefix, target: string): bool {.discardable.} =
  ## paths starting `prefix` are looked for under `target` first (the latest added first)
  wgr_asset_add_redirect(prefix.cstring, target.cstring)

proc clearAssetRedirects*() = wgr_asset_clear_redirects()

proc setAssetUploadBudget*(milliseconds: float) =
  ## how long a frame may spend handing loaded assets to the GPU
  wgr_asset_set_upload_budget(milliseconds.cfloat)

proc newAssetGroup*(): AssetTask =
  ## one task for many: add tasks to it, then addTask on the group
  AssetTask(wgr_asset_group_create())

proc add*(group: AssetTask; task: AssetTask): bool {.discardable.} = wgr_asset_group_add(group.cHandle, task.cHandle)

proc getProgress*(task: AssetTask): float = wgr_asset_get_progress(task.cHandle).float ## 0 .. 1

var assetFetcher: proc (request: AssetRequest; url, destPath: string) {.closure.}

proc fetchTrampoline(request: WgrHandle; url, destPath: WgrConstCstring; user: pointer) {.cdecl.} =
  if assetFetcher != nil: assetFetcher(AssetRequest(request), $cstring(url), $cstring(destPath))

proc setFetcher*(fetch: proc (request: AssetRequest; url, destPath: string) {.closure.}): bool {.discardable.} =
  ## desktop downloads: wgrender ships no HTTP client, so it asks this to fetch `url`
  ## into `destPath` and call fetchDone when it has; nil goes back to none
  assetFetcher = fetch
  wgr_asset_set_fetcher(if fetch != nil: fetchTrampoline else: nil, nil)

proc fetchDone*(request: AssetRequest; ok: bool): bool {.discardable.} =
  wgr_asset_fetch_done(request.cHandle, ok)

type PingCallback = ref object
  onDone: proc (host: string; milliseconds: float) {.closure.}

proc pingTrampoline(host: WgrConstCstring; milliseconds: cfloat; user: pointer) {.cdecl.} =
  let ping = cast[PingCallback](user)
  GC_unref(ping)
  if ping.onDone != nil: ping.onDone($cstring(host), milliseconds.float)

proc pingAssetHost*(host: string; timeoutMs: int;
                    onDone: proc (host: string; milliseconds: float) {.closure.}): bool {.discardable.} =
  ## how long `host` takes to answer (a negative time: it didn't); "" pings the asset host
  let ping = PingCallback(onDone: onDone)
  GC_ref(ping)
  result = wgr_asset_ping_host((if host.len > 0: host.cstring else: nil), timeoutMs.cint,
                              pingTrampoline, cast[pointer](ping))
  if not result: GC_unref(ping)

proc ensureAssetAsync*(path: string; fetchUrl = ""; flags: set[AssetFlag] = {}): AssetTask =
  ## A task to attach callbacks to (task.addTask); none on failure.
  var bits = 0'u32
  for f in flags: bits = bits or (1'u32 shl ord(f))
  AssetTask(wgr_asset_ensure_async(path.cstring,
                                  (if fetchUrl.len > 0: fetchUrl.cstring else: nil), bits))

proc addTask*(task: AssetTask; onSuccess: AssetCallback;
              onFailure: AssetCallback = nil): bool {.discardable.} =
  ## Callbacks run on the main thread during a later frame. False (and no callback)
  ## if the task is invalid or the queue is full.
  let t = AssetCallbacks(onSuccess: onSuccess, onFailure: onFailure)
  GC_ref(t)
  result = wgr_asset_add_task(task.cHandle, assetSuccessTrampoline, assetFailureTrampoline,
                             cast[pointer](t)) == WGR_ASSET_ADD_TASK_OK
  if not result:
    GC_unref(t)

proc newMesh*(path: string): Mesh = Mesh(wgr_mesh_create(path.cstring))

proc newTexture*(path: string): Texture = Texture(wgr_texture_create(path.cstring))
