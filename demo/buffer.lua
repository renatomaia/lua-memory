-- create a buffer
local b = buffer.create(10)

-- fill buffer with zeros
buffer.fill(b, 0)

-- iterate over buffer
for i = 1, buffer.size(b) do
	print(i, buffer.get(b, i))
end

-- iteractively fill the buffer
for i = 1, buffer.size(b) do
	print(i, buffer.set(b, i, 2*i))
end

-- sets 4th, 5th and 6th bytes in the buffer
buffer.set(b, 4, 0xff, 0xff, 0xff)

-- move 3 bytes from position 4 to position 1
buffer.fill(b, b, 1, 3, 4)

-- clear the positions after the 3 first bytes
buffer.fill(b, 0, 4)
