## Events run: closures handed to C, kept alive by the binding, dropped by off. The
## event bus exists once wgrender has started, so this starts it, headless (no window,
## GPU or audio), and checks from init; WGR_HEADLESS_FRAMES ends it.
##
##   cd tests && WGR_HEADLESS_FRAMES=2 nim c -d:wgrHeadless -r tevents.nim

import wgr

var failures = 0
template check(cond: bool; what: string) =
  if not cond:
    echo "FAIL: ", what
    inc failures

proc onInit() =
  var heard = 0
  let listener = onEvent("tevents", proc () = inc heard)
  check listener != nil, "onEvent registers"
  check emitEvent("tevents") == 1 and heard == 1, "one listener hears an emit"
  discard onceEvent("tevents", proc () = heard += 10)
  check emitEvent("tevents") == 2 and heard == 12, "a once listener hears the next"
  check emitEvent("tevents") == 1 and heard == 13, "and only that one"
  check getEventListenerCount("tevents") == 1, "one left"
  check listener.off(), "off drops it"
  check emitEvent("tevents") == 0 and heard == 13, "nobody hears it now"
  check not listener.off(), "off twice is refused"
  discard onEvent("tevents", proc () = inc heard)
  discard onEvent("tevents", proc () = inc heard)
  check offAllEvents("tevents") == 2, "offAllEvents drops them all"
  check emitEvent("tevents") == 0, "and nobody hears it"

when isMainModule:
  initValues(64, 64, "tevents")
  setInit(onInit)
  setFrame(proc (dt, tickFraction: float) = discard)
  let status = run()
  echo (if failures == 0: "tevents: ok" else: "tevents: " & $failures & " failed")
  quit (if failures == 0: status else: 1)
