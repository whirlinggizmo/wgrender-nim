## wgr_debug.h, wrapped.

import ./raw

proc enableFps*(x, y, fontSize: int) =
  ## wgrender's own FPS overlay, drawn at the end of every frame
  wgr_debug_enable_fps(x.cint, y.cint, fontSize.cint)

proc disableFps*() = wgr_debug_disable_fps()
