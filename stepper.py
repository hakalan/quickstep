import pypruss
import sys
import math
from fifo import Fifo

def init(pru_bin):
  pypruss.modprobe(1024)
  ddr_addr = pypruss.ddr_addr()
  ddr_size = pypruss.ddr_size()
  print "DDR memory address is 0x%x and the size is 0x%x"%(ddr_addr, ddr_size)
  fifo = Fifo(ddr_addr, ddr_size)

  pypruss.init()
  pypruss.open(0)
  pypruss.pruintc_init()
  pypruss.pru_write_memory(0,0,[ddr_addr])
  pypruss.exec_program(0, pru_bin)
  return fifo

class Stepper:
  def __init__(self, fifo):
    self.fifo = fifo
    self.cscale = 128
    self.a = math.pi/200/16
    self.f = 2e8
    self.lastacc = None
    self.n = 0

  def acc_steps(self, speed_diff, acc):
    return int(speed_diff**2/(2*self.a*acc))

  def change_n(self, acc):
    self.n = int(self.lastacc/acc*self.n)
#    self.n = int(round(self.lastacc/acc*(self.n+0.5)-0.5))
    self.lastacc = acc

  def ramp(self, steps, acc):
    c = 0
    if abs(self.n) <= 1:
      self.n = 0
      c = int(0.676*self.f*math.sqrt(2*self.a/acc)*self.cscale)
#      c = int(round(0.676*self.f*math.sqrt(2*self.a/acc)))
      self.lastacc = acc
    else:
      self.change_n(acc)

    self.fifo.write([steps, c, self.n, 0], 'l')
    self.n += steps

  def run(self, steps):
    self.fifo.write([steps, 0, 0, 1], 'l')

  def constant(self, steps, speed):
    cspeed = int(round(self.a*self.f/speed*self.cscale))
    self.fifo.write([steps, cspeed, 0, 1],'l')

  def move(self, steps, speed, acc, dec):
    acc_steps_to_speed = self.acc_steps(speed, acc)
    acc_meets_dec_steps = int(steps*dec/(acc + dec) + 0.5)
    if acc_meets_dec_steps < acc_steps_to_speed:
      self.ramp(acc_meets_dec_steps, acc)
      self.ramp(steps - acc_meets_dec_steps, -dec)
    else:
      self.ramp(acc_steps_to_speed, acc)
      dec_steps = self.acc_steps(speed, dec)
      self.constant(steps - acc_steps_to_speed - dec_steps, speed)
      self.ramp(dec_steps, -dec)

class SimFifo:
  def __init__(self):
    self.back = 0
    self.c = 0
    self.rest = 0

  def write(self, l, type="L"):
    print l
    steps, newc, n, const = l
    if newc != 0:
      self.c = newc 
    if const==0:
      for step in range(int(steps)-1):
        n += 1
        nom = 2*self.c
        den = 4*n+1
        self.c = self.c - (nom+self.rest)/den
        self.rest = nom%den
        if step<20 or step>=steps-20:
          print n, self.c
    else:
#      self.rest = 0
      pass

  def front(self):
    return 0

steps, speed, acc, dec = (float(arg) for arg in sys.argv[1:5])

sim = False
if sim:
  fifo = SimFifo()
else:
  fifo = init('./stepper.bin')

stepper = Stepper(fifo)
stepper.move(steps, speed, acc, dec)

fifo.write([0,0,0,0])

olda = fifo.front()
while True:
  a = fifo.front()
  if not olda == a:
    print 'front:',a
    olda = a
  if a == fifo.back:
    break

if not sim:
  pypruss.wait_for_event(0)
  pypruss.clear_event(0)
  pypruss.pru_disable(0)
  pypruss.exit()
