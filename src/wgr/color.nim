## wgr_color.h, wrapped.

import ./types, ./raw

proc rgba*(r, g, b, a: int): Color = wgr_color_rgba(r.cint, g.cint, b.cint, a.cint)

proc rgbaf*(r, g, b, a: float): Color =
  ## from 0 .. 1 components
  wgr_color_rgbaf(r.cfloat, g.cfloat, b.cfloat, a.cfloat)

proc withAlpha*(color: Color; a: int): Color = wgr_color_with_alpha(color, a.cint)

proc red*(color: Color): int = wgr_color_get_red(color).int

proc green*(color: Color): int = wgr_color_get_green(color).int

proc blue*(color: Color): int = wgr_color_get_blue(color).int

proc alpha*(color: Color): int = wgr_color_get_alpha(color).int

proc lerp*(a, b: Color; t: float): Color = wgr_color_lerp(a, b, t.cfloat) ## 0: a, 1: b
