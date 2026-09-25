## wgr_audio.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newAudio*(path: string): Audio = Audio(wgr_audio_create(path.cstring))

proc release*(audio: Audio) = wgr_audio_release(audio.cHandle)
