## wgr_sound.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newSound*(audio: Audio): Sound = Sound(wgr_sound_create(audio.cHandle))

proc setLoop*(sound: Sound; loop: bool): bool {.discardable.} = wgr_sound_set_loop(sound.cHandle, loop)

proc play*(sound: Sound): bool {.discardable.} = wgr_sound_play(sound.cHandle)

proc setAudio*(sound: Sound; audio: Audio): bool {.discardable.} = wgr_sound_set_audio(sound.cHandle, audio.cHandle)

proc destroy*(sound: Sound) = wgr_sound_destroy(sound.cHandle)

proc pause*(sound: Sound): bool {.discardable.} = wgr_sound_pause(sound.cHandle)

proc resume*(sound: Sound): bool {.discardable.} = wgr_sound_resume(sound.cHandle)

proc stop*(sound: Sound): bool {.discardable.} = wgr_sound_stop(sound.cHandle)

proc setVolume*(sound: Sound; volume: float): bool {.discardable.} = wgr_sound_set_volume(sound.cHandle, volume.cfloat)

proc setPitch*(sound: Sound; pitch: float): bool {.discardable.} = wgr_sound_set_pitch(sound.cHandle, pitch.cfloat)

proc setPan*(sound: Sound; pan: float): bool {.discardable.} =
  ## -1 left .. 1 right
  wgr_sound_set_pan(sound.cHandle, pan.cfloat)

proc isPlaying*(sound: Sound): bool = wgr_sound_is_playing(sound.cHandle)
