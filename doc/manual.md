Legend:
[ok] - implementation and tests
[??] - implementation only
[  ] - no implementation yet



-- buffer support
[ok]   b = stream.buffer (b|s|sz [, i [, j]])
[ok]   buffer:set (pos, ...)
[ok]   buffer:fill (b|s [, i [, j [, o]]])
[ok]   sz = #buffer                          -- ~ stream.len
[ok]   str = tostring (buffer)               -- ~ stream.tostring
[ok]   ... = buffer:get ([i [, j]])          -- ~ stream.byte
[  ]   fmt_i, arg_i = buffer:pack (fmt, ...) -- padding shall not change buffer
[  ]   ... = buffer:unpack (fmt [, pos])
-- inspect streams
[ok]   bool = stream.isbuffer (b|s)
[ok]   index, lesser = stream.diff (b|s, b|s)
[ok]   sz = stream.len (b|s)
[ok]   str = stream.tostring (b|s [, i [, j]]) -- ~ string.sub
[ok]   ... = stream.byte (b|s [, i [, j]])
-- pattern matching
[??]   i, j = stream.find (b|s, pattern [, init [, plain]])
[??]   for ... in stream.gmatch (b|s, pattern) do
[??]   ... = stream.match (b|s, pattern [, init])
-- structure packing
[??]   ... = stream.unpack (fmt, b|s [, pos])
[??]   size = stream.packsize (fmt, ...)
-- stream factories (out="string"|"buffer")
[ok]   b|s = stream.char (out, ...)
[??]   b|s = stream.dump (out, f [, strip])
[??]   b|s = stream.format (out, fmt, ...)
[??]   b|s = stream.gsub (out, b|s, pattern, repl [, n])
[??]   b|s = stream.pack (out, fmt, ...)
[??]   b|s = stream.rep (out, b|s, n [, sep])
[??]   b|s = stream.lower (out, b|s) -- out="string"|"buffer"|"inplace"
[??]   b|s = stream.upper (out, b|s) -- out="string"|"buffer"|"inplace"
[??]   b|s = stream.reverse (out, b|s) -- out="string"|"buffer"|"inplace"
[  ]   b|s = stream.concat (out, list [, sep [, i [, j]]])
