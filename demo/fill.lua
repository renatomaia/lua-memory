-- create a memory
local m = memory.create(10)

-- fill memory with zeros
memory.fill(m, 0)

-- iterate over memory
for i = 1, memory.len(m) do
	print(i, memory.get(m, i))
end

-- iterate to fill the memory
for i = 1, memory.len(m) do
	memory.set(m, i, 2*i)
end

-- sets 4th, 5th and 6th bytes in the memory
memory.set(m, 4, 0xff, 0xff, 0xff)

-- copy 3 bytes from position 4 to position 1
memory.fill(m, m, 1, 3, 4)

-- clear the positions after the 3 first bytes
memory.fill(m, 0, 4)
