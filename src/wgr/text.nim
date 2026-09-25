## wgr_text.h, wrapped.

import ./types, ./internal/convert, ./raw

proc drawText*(text: string; x, y, size: int; color: Color) =
  wgr_text_draw(text.cstring, x.cint, y.cint, size.cint, color)

proc measureText*(text: string; size: int): int =
  ## width in the built-in font
  wgr_text_measure(text.cstring, size.cint).int

proc drawText*(font: Font; text: string; x, y, size: float; color: Color) =
  ## the whole string, by its length (a Nim string can hold a 0)
  wgr_text_draw_n(font.cHandle, text.cstring, text.len.cint, x.cfloat, y.cfloat, size.cfloat, color)

proc measureText*(font: Font; text: string; size: float): Vec2 =
  wgr_text_measure_n(font.cHandle, text.cstring, text.len.cint, size.cfloat).toNim

proc setDefaultFont*(font: Font): bool {.discardable.} =
  ## what drawing without a font uses (none: the built-in one)
  wgr_text_set_default_font(font.cHandle)

proc getDefaultFont*(): Font = Font(wgr_text_get_default_font())

proc drawFps*(x, y: int) =
  ## in the built-in font
  wgr_text_draw_fps(x.cint, y.cint)

proc drawFps*(font: Font; x, y, size: float; color: Color) =
  ## font none: the built-in font
  wgr_text_draw_fps_ex(font.cHandle, x.cfloat, y.cfloat, size.cfloat, color)
