-- create a memory
eight = memory.create(8)

-- set memory contents
memory.set(eight, 1, 0x01, 0x23, 0x45, 0x67,
                     0x89, 0xab, 0xcd, 0xef)
assert(memory.tostring(eight) == "\x01\x23\x45\x67\x89\xab\xcd\xef")

-- fill memory with contents from string
memory.fill(eight, "Hello, world!")
assert(memory.tostring(eight) == "Hello, w")

-- fill a portion of the memory
memory.fill(eight, "boy!", 5)
assert(memory.tostring(eight) == "Hellboy!")

-- sets last byte to zero
memory.set(eight, -1, 0)
assert(memory.tostring(eight) == "Hellboy\0")

-- fill positions 3 to 8 with contents from position 2
memory.fill(eight, eight, 3, 8, 2)
assert(memory.tostring(eight) == "Heellboy")

-- fill initial portion of memory
memory.fill(eight, "#h", 1, 2)
assert(memory.tostring(eight) == "#hellboy")
