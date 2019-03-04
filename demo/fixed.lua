-- create memory with zeros
zeros = memory.create(8)
assert(memory.type(zeros) == "fixed")
assert(memory.tostring(zeros) == string.rep("\0", 8))

-- create memory with contents from string
copy = memory.create("Hello, world!")
assert(memory.type(copy) == "fixed")
assert(memory.tostring(copy) == "Hello, world!")
