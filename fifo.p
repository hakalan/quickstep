init_fifo:
  // Enable OCP master ports
  lbco r0, C4, 4, 4
  clr  r0, r0, 4
  sbco r0, C4, 4, 4

  // Init fifo pointers
  mov r0, 0
  lbbo Fifo.addr, r0, 0, SIZE(Fifo.addr)
  mov Fifo.front, FIFO_ADDR
  ret

load_command:
  lbbo Fifo.back, Fifo.addr, OFFSET(Fifo.back), SIZE(Fifo.back)
  qbeq load_command, Fifo.back, Fifo.front

  lbbo Command, Fifo.addr, Fifo.front, SIZE(Command)
  add Fifo.front, Fifo.front, SIZE(Command)

  // Check for fifo wraparound
  mov r1, FIFO_LENGTH
  qblt no_wrap, r1, Fifo.front
  mov Fifo.front, FIFO_ADDR

  no_wrap:
  // Store front in ram just for debugging purposes
  sbbo Fifo.front, Fifo.addr, OFFSET(Fifo.front), SIZE(Fifo.front)
  ret

check_end_command:
  // 0 signals end
  qbne not_end, Command, 0
  mov R31.b0, PRU0_ARM_INTERRUPT+16
  halt
  not_end:
  ret  

