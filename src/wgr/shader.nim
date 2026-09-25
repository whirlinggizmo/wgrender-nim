## wgr_shader.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newShader*(path: string): Shader = Shader(wgr_shader_create(path.cstring)) ## a .wgrshader

proc release*(shader: Shader) = wgr_shader_release(shader.cHandle)
