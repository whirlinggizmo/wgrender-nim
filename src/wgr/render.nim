## wgr_render.h, wrapped.

import ./types, ./internal/convert, ./raw

proc beginFrame*() = wgr_render_begin_frame()

proc endFrame*() = wgr_render_end_frame()

proc beginMode3d*() = wgr_render_begin_mode_3d() ## immediate 3D drawing, through the scene's camera

proc endMode3d*() = wgr_render_end_mode_3d()

proc clearBackground*(color: Color) = wgr_render_clear_background(color)

proc beginMode2d*() = wgr_render_begin_mode_2d() ## back to 2D after beginMode3d, in the same frame
proc endMode2d*() = wgr_render_end_mode_2d()
proc pushClip*(rect: Rect) =
  ## 2D drawing only inside `rect` (within the current clip) until popClip
  wgr_render_push_clip(rect.x, rect.y, rect.width, rect.height)
proc popClip*() = wgr_render_pop_clip()
proc beginTexture*(target: Texture): bool {.discardable.} =
  ## draw into a texture made by newTextureTarget, until endTexture
  wgr_render_begin_texture(target.cHandle)
proc endTexture*() = wgr_render_end_texture()
proc addEffect*(material: Material): bool {.discardable.} =
  ## a screen effect: a material whose shader is one, over the whole frame, in order added
  wgr_render_add_effect(material.cHandle)
proc clearEffects*() = wgr_render_clear_effects()
proc getEffectCount*(): int = wgr_render_effect_count().int
