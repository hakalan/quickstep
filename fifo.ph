#define PRU0_ARM_INTERRUPT 19

#define PRUSS_PRU_CTRL 0x22000
#define CONTROL 0x00
#define CYCLECOUNT 0x0C

#define COUNTER_ENABLE_BIT 3

#define FIFO_ADDR 8
#define FIFO_LENGTH 1024
#define COMMAND_RAM 4

.struct FifoDefs
  .u32 front
  .u32 back
  .u32 addr
.ends

.macro reset_cyclecount
.mparam counts
.mparam addr = r0
.mparam ctrl = r1
.mparam tmp = r2
  mov addr, PRUSS_PRU_CTRL

  lbbo ctrl, addr, CONTROL, 4
  clr ctrl, COUNTER_ENABLE_BIT
  sbbo ctrl, addr, CONTROL, 4

  lbbo counts, addr, CYCLECOUNT, 4
  mov tmp, 4 // make up for disabled cycles
  sbbo tmp, addr, CYCLECOUNT, 4

  set ctrl, COUNTER_ENABLE_BIT
  sbbo ctrl, addr, CONTROL, 4
.endm

.macro get_cyclecount
.mparam counts
.mparam addr = r0
  mov addr, PRUSS_PRU_CTRL
  lbbo counts, addr, CYCLECOUNT, 4
.endm
