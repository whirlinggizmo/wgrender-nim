## wgr_environment.h, wrapped.

import ./types, ./internal/convert, ./raw

proc setTonemap*(scene: Scene; tonemap: Tonemap; exposure = 0.0): bool {.discardable.} =
  ## how HDR light maps to the screen; exposure in stops
  wgr_scene_set_tonemap(scene.cHandle, ord(tonemap).cint, exposure.cfloat)

proc newEnvironment*(path: string): Environment = Environment(wgr_environment_create(path.cstring)) ## an .hdr

proc release*(environment: Environment) = wgr_environment_release(environment.cHandle)
