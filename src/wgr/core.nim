## wgr.h: the lifecycle, the frame, time, wrapped.

import std/enumutils
import ./types, ./raw

var
  initCallback: InitCallback
  frameCallback: FrameCallback

proc initTrampoline(user: pointer) {.cdecl.} =
  if initCallback != nil: initCallback()

proc frameTrampoline(dt, tickFraction: cfloat; user: pointer) {.cdecl.} =
  if frameCallback != nil: frameCallback(dt.float, tickFraction.float)

proc initValues*(width, height: int; title: string; flags: set[WindowFlag] = {}): int {.discardable.} =
  var bits = 0'u32
  for f in flags: bits = bits or (1'u32 shl ord(f))
  wgr_init_values(width.cint, height.cint, title.cstring, bits).int

proc setInit*(cb: InitCallback) =
  initCallback = cb
  wgr_set_init(initTrampoline, nil)

proc setFrame*(cb: FrameCallback) =
  frameCallback = cb
  wgr_set_frame(frameTrampoline, nil)

var tickCallback: TickCallback

proc tickTrampoline(dt: cfloat; user: pointer) {.cdecl.} =
  if tickCallback != nil: tickCallback(dt.float)

proc setTick*(cb: TickCallback; hz: int) =
  ## a fixed-rate simulation step, `hz` times a second of real time, apart from the
  ## frames; the frame's tickFraction says how far it is between the last two ticks
  tickCallback = cb
  wgr_set_tick(tickTrampoline, nil, hz.cint)

proc getTime*(): float = wgr_get_time().float ## seconds since the program started

proc isInitialized*(): bool = wgr_is_initialized()

proc getRenderer*(): string = $wgr_get_renderer() ## the graphics backend in use

proc hasThreads*(): bool = wgr_has_threads()

var cleanupCallback: InitCallback

proc cleanupTrampoline(user: pointer) {.cdecl.} =
  if cleanupCallback != nil: cleanupCallback()

proc setCleanup*(cb: InitCallback) =
  ## called once as the program ends, before wgrender shuts down
  cleanupCallback = cb
  wgr_set_cleanup(cleanupTrampoline, nil)

proc run*(): int {.discardable.} = wgr_run().int

proc requestQuit*() = wgr_request_quit() ## close the window / end the loop

proc getPlatform*(): string = $wgr_get_platform()

proc setTargetFps*(fps: int) = wgr_set_target_fps(fps.cint)

proc toHandleKind(kind: cint): HandleKind =
  for k in HandleKind: # the enum has gaps, so a plain conversion could land in one
    if ord(k) == kind.int: return k
  HandleKind.None

proc getKind*(h: Handle | AnyHandle): HandleKind =
  ## what a handle is: which kind a pick result's hit is, say
  toHandleKind(wgr_handle_get_kind(uint32(Handle(h))))
