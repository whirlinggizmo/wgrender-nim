## wgrender for Nim: the C API (wgr/raw) wrapped in stock Nim types.
##
## Nothing exported here names a C type: a consumer never writes a cstring, a cint, a
## cast or a WGR_ constant. tools/coverage.py --check (CI) fails on any exported proc,
## type, constant or field that does; C stays in wgr/raw.
##
## - strings, ints and floats instead of cstring / cint / cfloat
## - Nim enums and a `set` of window flags instead of C constants (button states too)
## - handles as distinct types, the untyped `Handle` included: not a number
## - vectors as tuples, mouse and pick state as Nim objects
## - closures for callbacks, called through cdecl trampolines
## - a distinct type per handle kind (Model, Texture, Font, ...), so passing the
##   wrong kind is a compile error; the zero value is "none" (`isNone`)
## - the calls read as Nim, not C: on a handle, the call is its action, on the
##   handle by method call syntax (`wgr_model_set_position(m, ...)` is
##   `m.setPosition(v)`), overloaded on the handle kinds; a constructor is
##   `new<Kind>` (`wgr_model_create` is `newModel(mesh)`); anything else is its
##   action as a plain proc (`wgr_render_begin_frame` is `beginFrame()`), with its
##   section as a noun only where the action alone would be ambiguous
##   (`drawText`, `measureText`, `setAssetHost`, `setLogLevel`). `wgr.` in front
##   qualifies any of them: `wgr.newTexture(path)`
## - `bool` results are discardable
##
## One module per wgrender header, src/wgr/<header>.nim (model.nim wraps wgr_model.h,
## core.nim wgr.h itself), with the types they share in types.nim; this module
## re-exports them all, so `import wgr` is everything. `wgr/raw` has the C API as is.


import wgr/[types, core, version, logger, asset, color, audio, sound, model, material, shader, texture, sprite3d, font, text, text3d, camera3d, light, scene, environment, pick, shape2d, window, sprite2d, shape3d, debug, render, input, emitter, text2d, event]
export types, core, version, logger, asset, color, audio, sound, model, material, shader, texture, sprite3d, font, text, text3d, camera3d, light, scene, environment, pick, shape2d, window, sprite2d, shape3d, debug, render, input, emitter, text2d, event
