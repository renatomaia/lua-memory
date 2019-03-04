m = memory.create(2)

memory.pack(m, "I2", 1, 0x0001)
if memory.unpack(m, "B") == 0 then
	print("big-endian platform")
else
	print("little-endian platform")
end
