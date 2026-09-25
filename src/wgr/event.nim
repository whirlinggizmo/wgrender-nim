## wgr_event.h, wrapped: named events, emitted by wgrender (or a program) and heard
## by closures.
##
## A listener takes no arguments. A payload is a C pointer, which a closure isn't given
## (as in wgrender-hx), and emitEvent sends none. onEvent and onceEvent return the
## listener, which off takes: two closures over the same proc aren't comparable.

import std/[sequtils, tables]
import ./raw

type
  EventListener* = ref object
    ## a listener onEvent or onceEvent registered, for off
    name: string
    callback: proc () {.closure.}
    once: bool

var registered = initTable[string, seq[EventListener]]()

proc forget(listener: EventListener) =
  if listener.name in registered:
    registered[listener.name].keepItIf(it != listener)

proc eventTrampoline(payload, user: pointer) {.cdecl.} =
  let listener = cast[EventListener](user)
  if listener.once:
    forget(listener) # wgrender has dropped it
    GC_unref(listener)
  if listener.callback != nil: listener.callback()

proc listen(name: string; callback: proc () {.closure.}; once: bool): EventListener =
  result = EventListener(name: name, callback: callback, once: once)
  GC_ref(result)
  let ok = (if once: wgr_event_once(name.cstring, eventTrampoline, cast[pointer](result))
            else: wgr_event_on(name.cstring, eventTrampoline, cast[pointer](result))) == 0
  if ok:
    registered.mgetOrPut(name, @[]).add result
  else:
    GC_unref(result)
    result = nil

proc onEvent*(name: string; callback: proc () {.closure.}): EventListener =
  ## called each time `name` is emitted; nil if it couldn't be registered
  listen(name, callback, false)
proc onceEvent*(name: string; callback: proc () {.closure.}): EventListener =
  ## called the next time `name` is emitted, then dropped
  listen(name, callback, true)
proc off*(listener: EventListener): bool {.discardable.} =
  if listener == nil or listener notin registered.getOrDefault(listener.name): return false
  result = wgr_event_off(listener.name.cstring, eventTrampoline, cast[pointer](listener)) > 0 # how many it removed
  forget(listener)
  GC_unref(listener)
proc offAllEvents*(name: string): int {.discardable.} =
  ## every listener of `name` dropped, this program's and wgrender's; how many
  result = wgr_event_off_all(name.cstring).int
  for listener in registered.getOrDefault(name): GC_unref(listener)
  registered.del(name)
proc emitEvent*(name: string): int {.discardable.} =
  ## how many listeners heard it
  wgr_event_emit(name.cstring, nil).int
proc getEventListenerCount*(name: string): int = wgr_event_listener_count(name.cstring).int
