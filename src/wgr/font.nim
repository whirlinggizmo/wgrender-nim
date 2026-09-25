## wgr_font.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newFont*(path: string): Font = Font(wgr_font_create(path.cstring))

proc release*(font: Font) = wgr_font_release(font.cHandle)
