import pypruss
import mmap
import struct
import sys

class Fifo:
  def __init__(self, ddr_addr, ddr_size):
    hack = 0x20000000
    ddr_offset = ddr_addr-hack
    ddr_filelen = ddr_size+hack
    with open("/dev/mem", "r+b") as f:
      self.ddr_mem = mmap.mmap(f.fileno(), ddr_filelen, offset=ddr_offset)

    self.ddr_start = hack
    self.ddr_end = hack+ddr_size
    self.back = 8
    self.fifo_size = 1024
    self.memwrite(0,[8, self.back])

  def memwrite(self, offset, data, type = 'L'):
    print 'write',data,'to',offset
    packed = ''.join([struct.pack(type, word) for word in data])
    begin = self.ddr_start + offset
    self.ddr_mem[begin:begin+len(packed)] = packed
    return len(packed)

  def memread(self, offset, length):
    begin = self.ddr_start + offset
    return struct.unpack('l'*length,
      self.ddr_mem[begin:begin+4*length])

  def write(self, data):
    self.back += self.memwrite(self.back, data, 'l')
    if self.back >= self.fifo_size:
      self.back = 8
    self.memwrite(4, [self.back])

  def front(self):
    return struct.unpack('L',
      self.ddr_mem[self.ddr_start:self.ddr_start+4])[0]

pypruss.modprobe(1024)
ddr_addr = pypruss.ddr_addr()
ddr_size = pypruss.ddr_size()

print "DDR memory address is 0x%x and the size is 0x%x"%(ddr_addr, ddr_size)

fifo = Fifo(ddr_addr, ddr_size)

pypruss.init()
pypruss.open(0)
pypruss.pruintc_init()
pypruss.pru_write_memory(0,0,[ddr_addr])
pypruss.exec_program(0, "./division.bin")

fifo.write([int(i) for i in sys.argv[1:3]]) 
fifo.write([0,0])

olda = fifo.front()
while True:
  a = fifo.front()
  if not olda == a:
    print 'front:',a
    olda = a
  if a == fifo.back:
    break

print fifo.memread(40, 3)
pypruss.wait_for_event(0)
pypruss.clear_event(0)
pypruss.pru_disable(0)
pypruss.exit()
