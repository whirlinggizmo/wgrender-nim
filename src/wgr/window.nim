## wgr_window.h, wrapped.

import ./types, ./internal/convert, ./raw

proc setWindowTitle*(title: string) = wgr_window_set_title(title.cstring)

proc isCloseRequested*(): bool = wgr_window_close_requested() != 0 ## the user asked to close it

proc setWindowSize*(width, height: int): bool {.discardable.} =
  wgr_window_set_size(width.cint, height.cint)

proc setWindowPosition*(x, y: int): bool {.discardable.} = wgr_window_set_position(x.cint, y.cint)

proc getWindowPosition*(): Vec2 = wgr_window_get_position().toNim

proc hasFullscreen*(): bool = wgr_window_has_fullscreen() ## whether this platform can

proc requestFullscreen*(fullscreen: bool): bool {.discardable.} =
  ## a request: isFullscreen answers on a later frame
  wgr_window_request_fullscreen(fullscreen)

proc isFullscreen*(): bool = wgr_window_is_fullscreen()

proc setWindowVisible*(visible: bool): bool {.discardable.} =
  ## a hidden window keeps running
  wgr_window_set_visible(visible)

proc isWindowVisible*(): bool = wgr_window_is_visible()

proc isWindowFocused*(): bool = wgr_window_is_focused()

proc getMonitorCount*(): int = wgr_window_get_monitor_count().int

proc getMonitor*(): int = wgr_window_get_monitor().int ## the one the window is on

proc setMonitor*(monitor: int): bool {.discardable.} = wgr_window_set_monitor(monitor.cint)

proc getMonitorSize*(monitor: int): Vec2 = wgr_window_get_monitor_size(monitor.cint).toNim

proc getMonitorPosition*(monitor: int): Vec2 = wgr_window_get_monitor_position(monitor.cint).toNim

proc getMonitorName*(monitor: int): string = $wgr_window_get_monitor_name(monitor.cint)

proc getScreenSize*(): Vec2 = wgr_window_get_screen_size().toNim
