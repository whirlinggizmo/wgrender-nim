## wgr_material.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newMaterial*(shading = MaterialShading.Pbr): Material =
  Material(wgr_material_create(ord(shading).cint))

proc newMaterial*(shader: Shader): Material =
  ## drawn by a custom shader: its parameters are the ones the shader declares
  Material(wgr_material_create_custom(shader.cHandle))

proc getShader*(material: Material): Shader = Shader(wgr_material_get_shader(material.cHandle))

proc release*(material: Material) = wgr_material_release(material.cHandle)

proc setShading*(material: Material; shading: MaterialShading): bool {.discardable.} =
  wgr_material_set_shading(material.cHandle, ord(shading).cint)

proc getShading*(material: Material): MaterialShading =
  MaterialShading(wgr_material_get_shading(material.cHandle))

proc setAlphaMode*(material: Material; mode: AlphaMode; cutoff = 0.5): bool {.discardable.} =
  wgr_material_set_alpha_mode(material.cHandle, ord(mode).cint, cutoff.cfloat)

proc getAlphaMode*(material: Material): AlphaMode = AlphaMode(wgr_material_get_alpha_mode(material.cHandle))

proc setDoubleSided*(material: Material; doubleSided: bool): bool {.discardable.} =
  wgr_material_set_double_sided(material.cHandle, doubleSided)

proc isDoubleSided*(material: Material): bool = wgr_material_is_double_sided(material.cHandle)

proc setInt*(material: Material; name: string; value: int): bool {.discardable.} =
  wgr_material_set_int(material.cHandle, name.cstring, value.cint)

proc setFloat*(material: Material; name: string; value: float): bool {.discardable.} =
  wgr_material_set_float(material.cHandle, name.cstring, value.cfloat)

proc setVec2*(material: Material; name: string; value: Vec2): bool {.discardable.} =
  wgr_material_set_vec2(material.cHandle, name.cstring, value.x, value.y)

proc setVec3*(material: Material; name: string; value: Vec3): bool {.discardable.} =
  wgr_material_set_vec3(material.cHandle, name.cstring, value.x, value.y, value.z)

proc setVec4*(material: Material; name: string; value: Vec4): bool {.discardable.} =
  wgr_material_set_vec4(material.cHandle, name.cstring, value.x, value.y, value.z, value.w)

proc setColor*(material: Material; name: string; color: Color): bool {.discardable.} =
  ## a vec3 or vec4 parameter (a vec3 ignores alpha)
  wgr_material_set_color(material.cHandle, name.cstring, color)

proc setTexture*(material: Material; name: string; texture: Texture): bool {.discardable.} =
  wgr_material_set_texture(material.cHandle, name.cstring, texture.cHandle)

proc setTextureSampling*(material: Material; name: string; wrapU, wrapV: TextureWrap;
                         filter: TextureFilter): bool {.discardable.} =
  ## how texture `name` is sampled (default Repeat, Linear)
  wgr_material_set_texture_sampling(material.cHandle, name.cstring, ord(wrapU).cint, ord(wrapV).cint,
                                   ord(filter).cint)
