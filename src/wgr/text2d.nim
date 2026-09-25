## wgr_text2d.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newText2d*(font: Font): Text2d = Text2d(wgr_text2d_create(font.cHandle))
proc newText2d*(): Text2d =
  ## in the default font (setDefaultFont)
  Text2d(wgr_text2d_create(0))
proc destroy*(text: Text2d) = wgr_text2d_destroy(text.cHandle)
proc setFont*(text: Text2d; font: Font): bool {.discardable.} = wgr_text2d_set_font(text.cHandle, font.cHandle)
proc setText*(text: Text2d; value: string): bool {.discardable.} = wgr_text2d_set_text(text.cHandle, value.cstring)
proc setPosition*(text: Text2d; value: Vec2): bool {.discardable.} =
  wgr_text2d_set_position(text.cHandle, value.x, value.y)
proc setPosition*(text: Text2d; x, y: float): bool {.discardable.} = wgr_text2d_set_position(text.cHandle, x, y)
proc getPosition*(text: Text2d): Vec2 = wgr_text2d_get_position(text.cHandle).toNim
proc setSize*(text: Text2d; size: float): bool {.discardable.} =
  ## line height, pixels
  wgr_text2d_set_size(text.cHandle, size.cfloat)
proc setColor*(text: Text2d; color: Color): bool {.discardable.} = wgr_text2d_set_color(text.cHandle, color)
proc setVisible*(text: Text2d; visible: bool): bool {.discardable.} = wgr_text2d_set_visible(text.cHandle, visible)
proc isVisible*(text: Text2d): bool = wgr_text2d_is_visible(text.cHandle)
proc setPickable*(text: Text2d; pickable: bool): bool {.discardable.} =
  wgr_text2d_set_pickable(text.cHandle, pickable)
proc isPickable*(text: Text2d): bool = wgr_text2d_is_pickable(text.cHandle)
proc setEnabled*(text: Text2d; enabled: bool): bool {.discardable.} = wgr_text2d_set_enabled(text.cHandle, enabled)
proc isEnabled*(text: Text2d): bool = wgr_text2d_is_enabled(text.cHandle)
proc setAlign*(text: Text2d; horizontal: AlignX; vertical: AlignY): bool {.discardable.} =
  ## where the block sits relative to its position
  wgr_text2d_set_align(text.cHandle, ord(horizontal).cint, ord(vertical).cint)
proc setMaxWidth*(text: Text2d; width: float): bool {.discardable.} =
  ## wraps at this width, pixels (0: no wrapping)
  wgr_text2d_set_max_width(text.cHandle, width.cfloat)
proc measureWidth*(text: Text2d): float = wgr_text2d_measure_width(text.cHandle).float
proc measureHeight*(text: Text2d): float = wgr_text2d_measure_height(text.cHandle).float
proc draw*(text: Text2d) = wgr_text2d_draw(text.cHandle) ## immediate, for one not in a scene
