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

  def acc_steps(self, v, acc):
    return int(v**2/(2*self.a*acc) + 0.5)

  def calc_c(self, acc, n):
    c = self.f*math.sqrt(2*self.a/acc) * (math.sqrt(n+1)-math.sqrt(n))
    if n==0:
      # Compensate for Taylor series error at c0
      c *= 0.676
    return int(c*self.cscale + 0.5)

  def calc_cmin(self, v):
     return int(self.f*self.a/self.v*self.cscale + 0.5)

  def stop(self):
    self.fifo.write([0]*(6+self.numaxis), 'l')

  def move(self, steps, v0, v1, v2, acc, dec):
    steps = int(steps)

    acc_steps_to_init = self.acc_steps(v0, acc)
    acc_steps_to_speed = self.acc_steps(v1, acc) - acc_steps_to_init
    dec_steps_past_end = self.acc_steps(v2, dec)

    asteps = steps + acc_steps_to_init + dec_steps_past_end

    acc_meets_dec_steps = int(asteps*dec/(acc + dec) + 0.5) - acc_steps_to_init

    c = self.calc_c(acc, acc_steps_to_init)
#    cmin = self.calc_cmin(v1)

    if acc_meets_dec_steps < acc_steps_to_speed:
      dec_n = steps - acc_meets_dec_steps + dec_steps_past_end + 1
      self.fifo.write([steps, c, acc_steps_to_init, dec_n, 
                       acc_meets_dec_steps, acc_meets_dec_steps]+
                      [steps]*self.numaxis)

    else:
      dec_steps = self.acc_steps(v1, dec)
      dec_n = dec_steps + 1
      self.fifo.write([steps, c, acc_steps_to_init, dec_n, 
                       acc_steps_to_speed, steps+dec_steps_past_end-dec_steps]+
                      [steps]*self.numaxis)

class SimFifo:
  def speed(self, c):
    cscale = 1024
    a = math.pi/200/16
    f = 2e8
    return cscale*a*f/c

  def write(self, l, type="L"):
    print l
    steps, c, n, dec_n, acc_steps, dec_start, na,nb,nc,nd  = l
    if steps>0:
      rest = 0
      for step in range(acc_steps):
        n += 1
        nom = 2*c
        den = 4*n+1
        c -= nom/den
        rest = nom%den
        if step<10 or step>=acc_steps-10:
          print n, c, self.speed(c)

      rest = 0

      dec_steps = steps-dec_start
      for step in range(dec_steps):
        dec_n -= 1
        nom = 2*c
        den = 4*dec_n-1
        c += nom/den
        rest = nom%den
        if step<10 or step>=dec_steps-10:
          print dec_n, c, self.speed(c)

if sim:
  fifo = SimFifo()
else:
  fifo = init('./stepper.bin')

stepper = Stepper(fifo)

if len(sys.argv)==7:
  steps, v0, v1, v2, acc, dec = (float(arg) for arg in sys.argv[1:7])

  stepper.move(steps, v0, v1, v2, acc, dec)
  stepper.stop()

else:
  # Do a test sequence
  acc = dec = 1000
  v = [25, 100, 50, 125]
  n = [10000, 20000, 10000, 20000]

  for steps, v0, v1, v2 in zip(n, [0]+v[:-1], v, v[1:]+[0]):
    if v2>v1:
      v2=v1
    if v0>v1: 
      v0=v1
    stepper.move(steps, v0, v1, v2, acc, dec)

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
