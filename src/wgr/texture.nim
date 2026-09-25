## wgr_texture.h, wrapped.

import ./types, ./internal/convert, ./raw

proc release*(texture: Texture) = wgr_texture_release(texture.cHandle)

proc newTextureTarget*(width, height: int): Texture =
  ## a texture to render into (a scene's target)
  Texture(wgr_texture_create_target(width.cint, height.cint))

proc getDefaultTexture*(): Texture = Texture(wgr_texture_get_default()) ## plain white

proc getPlaceholderTexture*(): Texture =
  ## what stands in for a texture that couldn't be loaded
  Texture(wgr_texture_get_placeholder())

proc setPlaceholderTexture*(texture: Texture): bool {.discardable.} =
  wgr_texture_set_placeholder(texture.cHandle)

proc setSampling*(texture: Texture; wrapU, wrapV: TextureWrap; filter: TextureFilter): bool {.discardable.} =
  ## how it's sampled where it's drawn directly (sprites, draw); default Clamp, Linear
  wgr_texture_set_sampling(texture.cHandle, ord(wrapU).cint, ord(wrapV).cint, ord(filter).cint)

proc getSize*(texture: Texture): Vec2 = wgr_texture_get_size(texture.cHandle).toNim

proc draw*(texture: Texture; x, y, width, height: float; tint = ColorWhite) =
  ## the whole texture into that rectangle of the screen
  wgr_texture_draw(texture.cHandle, x.cfloat, y.cfloat, width.cfloat, height.cfloat, tint)

proc draw*(texture: Texture; source, target: Rect; tint = ColorWhite) =
  ## a region of the texture (its pixels) into a rectangle of the screen
  wgr_texture_draw_ex(texture.cHandle, source.x, source.y, source.width, source.height,
                     target.x, target.y, target.width, target.height, tint)

proc drawNineSlice*(texture: Texture; source: Rect; left, top, right, bottom: float;
                    target: Rect; tint = ColorWhite) =
  ## the source's corners kept, its edges and middle stretched to fill the target
  wgr_texture_draw_nine_slice(texture.cHandle, source.x, source.y, source.width, source.height,
                             left, top, right, bottom, target.x, target.y, target.width,
                             target.height, tint)
