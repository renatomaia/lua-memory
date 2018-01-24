-- create a memory
local b = memory.create(10)

-- fill memory with zeros
memory.fill(b, 0)

-- iterate over memory
for i = 1, memory.len(b) do
	print(i, memory.get(b, i))
end

-- iterate to fill the memory
for i = 1, memory.len(b) do
	memory.set(b, i, 2*i)
end

-- sets 4th, 5th and 6th bytes in the memory
memory.set(b, 4, 0xff, 0xff, 0xff)

-- copy 3 bytes from position 4 to position 1
memory.fill(b, b, 1, 3, 4)

-- clear the positions after the 3 first bytes
memory.fill(b, 0, 4)
