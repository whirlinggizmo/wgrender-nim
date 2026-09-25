## wgr_light.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newLight*(kind: LightKind): Light = Light(wgr_light_create(ord(kind).cint))

proc setDirection*(light: Light; direction: Vec3): bool {.discardable.} =
  wgr_light_set_direction(light.cHandle, direction.x, direction.y, direction.z)

proc setIntensity*(light: Light; intensity: float): bool {.discardable.} =
  wgr_light_set_intensity(light.cHandle, intensity.cfloat)

proc destroy*(light: Light) = wgr_light_destroy(light.cHandle)

proc getKind*(light: Light): LightKind = LightKind(wgr_light_get_type(light.cHandle))

proc getIntensity*(light: Light): float = wgr_light_get_intensity(light.cHandle).float

proc setColor*(light: Light; color: Color): bool {.discardable.} = wgr_light_set_color(light.cHandle, color)

proc getColor*(light: Light): Color = wgr_light_get_color(light.cHandle)

proc setPosition*(light: Light; value: Vec3): bool {.discardable.} =
  ## a point or spot light's; a directional one has none
  wgr_light_set_position(light.cHandle, value.x, value.y, value.z)

proc setPosition*(light: Light; x, y, z: float): bool {.discardable.} = wgr_light_set_position(light.cHandle, x, y, z)

proc getPosition*(light: Light): Vec3 = wgr_light_get_position(light.cHandle).toNim

proc getDirection*(light: Light): Vec3 = wgr_light_get_direction(light.cHandle).toNim

proc setRange*(light: Light; range: float): bool {.discardable.} =
  ## how far a point or spot light reaches
  wgr_light_set_range(light.cHandle, range.cfloat)

proc getRange*(light: Light): float = wgr_light_get_range(light.cHandle).float

proc setSpotCone*(light: Light; innerAngle, outerAngle: float): bool {.discardable.} =
  ## full brightness inside `innerAngle`, fading to none at `outerAngle` (radians)
  wgr_light_set_spot_cone(light.cHandle, innerAngle.cfloat, outerAngle.cfloat)

proc getSpotInnerAngle*(light: Light): float = wgr_light_get_spot_inner_angle(light.cHandle).float

proc getSpotOuterAngle*(light: Light): float = wgr_light_get_spot_outer_angle(light.cHandle).float

proc setEnabled*(light: Light; enabled: bool): bool {.discardable.} = wgr_light_set_enabled(light.cHandle, enabled)

proc isEnabled*(light: Light): bool = wgr_light_is_enabled(light.cHandle)

proc setCastsShadows*(light: Light; casts: bool): bool {.discardable.} =
  wgr_light_set_casts_shadows(light.cHandle, casts)

proc castsShadows*(light: Light): bool = wgr_light_get_casts_shadows(light.cHandle)

proc setShadowDistance*(light: Light; distance: float): bool {.discardable.} =
  wgr_light_set_shadow_distance(light.cHandle, distance.cfloat)

proc getShadowDistance*(light: Light): float = wgr_light_get_shadow_distance(light.cHandle).float

proc setShadowMapSize*(light: Light; size: int): bool {.discardable.} =
  wgr_light_set_shadow_map_size(light.cHandle, size.cint)

proc getShadowMapSize*(light: Light): int = wgr_light_get_shadow_map_size(light.cHandle).int

proc setShadowStrength*(light: Light; strength: float): bool {.discardable.} =
  wgr_light_set_shadow_strength(light.cHandle, strength.cfloat)

proc getShadowStrength*(light: Light): float = wgr_light_get_shadow_strength(light.cHandle).float

proc setShadowColor*(light: Light; color: Color): bool {.discardable.} = wgr_light_set_shadow_color(light.cHandle, color)

proc getShadowColor*(light: Light): Color = wgr_light_get_shadow_color(light.cHandle)

proc setShadowBias*(light: Light; constant, slope: float): bool {.discardable.} =
  wgr_light_set_shadow_bias(light.cHandle, constant.cfloat, slope.cfloat)

proc getShadowBiasConstant*(light: Light): float = wgr_light_get_shadow_bias_constant(light.cHandle).float

proc getShadowBiasSlope*(light: Light): float = wgr_light_get_shadow_bias_slope(light.cHandle).float

proc add*(scene: Scene; member: SceneMember; layer = 0): bool {.discardable.} =
  wgr_scene_add(scene.cHandle, member.cHandle, layer.cint)
