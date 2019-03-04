-- create a memory
m = memory.create("Hello, World!")

-- no difference found
assert(memory.diff(m, "Hello, World!") == nil)

-- finding the difference
local idx, less = memory.diff(m, "Hello, world!")
assert(idx == 8)
assert(less == true)
