-- create empty memory
resizable = memory.create()
assert(memory.type(resizable) == "resizable")
assert(memory.len(resizable) == 0)

-- create memory with zeros
memory.resize(resizable, 4)
assert(memory.tostring(resizable) == "\0\0\0\0")

-- increase memory with data
memory.resize(resizable, 8, "\xff")
assert(memory.tostring(resizable) == "\0\0\0\0\xff\xff\xff\xff")

-- shrink memory
memory.resize(resizable, 6)
assert(memory.tostring(resizable) == "\0\0\0\0\xff\xff")

-- reset to the contents of a string
memory.resize(resizable, 0)
memory.resize(resizable, 13, "Hello, world!")
assert(memory.tostring(resizable) == "Hello, world!")
