## wgr_logger.h, wrapped.

import ./types, ./raw

proc setLogLevel*(level: LogLevel) = wgr_logger_set_level(ord(level).cint)

proc logMessage*(level: LogLevel; msg: string) =
  wgr_logger_message(ord(level).cint, "%s", msg.cstring)

proc logMessageAt*(level: LogLevel; file: string; line: int; msg: string) =
  ## with the source location it came from
  wgr_logger_message_source(ord(level).cint, file.cstring, line.cint, "%s", msg.cstring)

proc logTrace*(msg: string) = logMessage(LogLevel.Trace, msg)

proc logDebug*(msg: string) = logMessage(LogLevel.Debug, msg)

proc logInfo*(msg: string) = logMessage(LogLevel.Info, msg)

proc logWarn*(msg: string) = logMessage(LogLevel.Warn, msg)

proc logError*(msg: string) = logMessage(LogLevel.Error, msg)

proc logFatal*(msg: string) = logMessage(LogLevel.Fatal, msg)
