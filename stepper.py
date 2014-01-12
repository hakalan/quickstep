import pypruss
import sys
import math
from fifo import Fifo
import time

# Engage simulator instead of PRU?
sim = True

def init(pru_bin):
  pypruss.modprobe()
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
    self.cscale = 1024
    self.a = math.pi/200/16
    self.f = 2e8
    self.numaxis = 4

  def acc_steps(self, speed_diff, acc):
    return int(speed_diff**2/(2*self.a*acc))

  def ramp(self, acc):
    n = 0
    c = int(0.676*self.f*math.sqrt(2*self.a/acc)*self.cscale)
    return c, n

  def stop(self):
    self.fifo.write([0]*(6+self.numaxis), 'l')

  def move(self, steps, speed, acc, dec):
    steps = int(steps)
    acc_steps_to_speed = self.acc_steps(speed, acc)
    acc_meets_dec_steps = int(steps*dec/(acc + dec) + 0.5)
    c, n = self.ramp(acc)
    if acc_meets_dec_steps < acc_steps_to_speed:
      dec_n = steps-acc_meets_dec_steps+1
      self.fifo.write([steps, c, n, dec_n, acc_meets_dec_steps, acc_meets_dec_steps, steps, steps, steps, steps])
    else:
      dec_steps = self.acc_steps(speed, dec)
      dec_n = dec_steps+1
      self.fifo.write([steps, c, n, dec_n, acc_steps_to_speed, steps-dec_steps]+[steps]*self.numaxis)

class SimFifo:
  def __init__(self):
    pass

  def write(self, l, type="L"):
    print l
    steps, c, n, dec_n, acc_steps, dec_start, a,b,c,d  = l
    if steps>0:
      rest = 0
      for step in range(acc_steps):
        n += 1
        nom = 2*c+rest
        den = 4*n+1
        c -= nom/den
        rest = nom%den
        if step<10 or step>=acc_steps-10:
          print n, c

      rest = 0

      dec_steps = steps-dec_start
      for step in range(dec_steps):
        dec_n -= 1
        nom = 2*c+rest
        den = 4*dec_n+1
        c += nom/den
        rest = nom%den
        if step<10 or step>=dec_steps-10:
          print dec_n, c

steps, speed, acc, dec = (float(arg) for arg in sys.argv[1:5])

if sim:
  fifo = SimFifo()
else:
  fifo = init('./stepper.bin')

stepper = Stepper(fifo)
stepper.move(steps, speed, acc, dec)
stepper.stop()

if not sim:
  olda = fifo.front()
  while True:
    a = fifo.front()
    if not olda == a:
      print 'front:',a
      olda = a
    if a == fifo.back:
      break
    time.sleep(0.1)

  pypruss.wait_for_event(0)
  pypruss.clear_event(0)
  pypruss.pru_disable(0)
  pypruss.exit()
