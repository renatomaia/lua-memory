-- create a memory
eight = memory.create("\x01\x23\x45\x67\x89\xab\xcd\xef")

-- get last byte
assert(memory.get(eight, -1) == 0xef)

-- get bytes from a portion of the memory
local a, b, c = memory.get(eight, 3, 5)
assert(a == 0x45)
assert(b == 0x67)
assert(c == 0x89)

-- search for bytes in memory
assert(memory.find(eight, "\x45\x67\x89") == 3)
