import mmap
import struct

class Fifo:
  def __init__(self, ddr_addr, ddr_size):
    hack = 0x20000000
    ddr_offset = ddr_addr-hack
    ddr_filelen = ddr_size+hack
    with open("/dev/mem", "r+b") as f:
      self.ddr_mem = mmap.mmap(f.fileno(), ddr_filelen, offset=ddr_offset)

    self.ddr_start = hack
    self.ddr_end = hack+ddr_size
    self.back = 12
    self.fifo_size = 1024
    self.memwrite(0, [12, self.back, 0])

  def memwrite(self, offset, data, type = 'L'):
    print 'write',data,'to',offset
    packed = ''.join([struct.pack(type, word) for word in data])
    begin = self.ddr_start + offset
    self.ddr_mem[begin:begin+len(packed)] = packed
    return len(packed)

  def memread(self, offset, length, type = 'L'):
    begin = self.ddr_start + offset
    return struct.unpack(type*length,
      self.ddr_mem[begin:begin+4*length])

  def dbgread(self, type = 'L'):
    return self.memread(8, 1, type)

  def write(self, data, type = 'L'):
    self.back += self.memwrite(self.back, data, type)
    if self.back >= self.fifo_size:
      self.back = 12
    self.memwrite(4, [self.back])

  def front(self):
    return struct.unpack('L',
      self.ddr_mem[self.ddr_start:self.ddr_start+4])[0]

