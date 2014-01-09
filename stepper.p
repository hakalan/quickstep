#include "fifo.ph"
#include "division.pm"

.origin 0
.entrypoint START

.struct CommandDefs
  .u32 steps
  .u32 c
  .u32 n
  .u32 const
.ends

.assign FifoDefs, r8, r10, Fifo
.assign CommandDefs, r11, r14, Command

#define GPIO0 0x44E07000
#define GPIO_CLEARDATAOUT 	0x190
#define GPIO_SETDATAOUT 	0x194
#define STEP (1<<27)

#define t_addr r7

START:
  call init_fifo
  mov t_addr, Fifo.addr
  add t_addr, t_addr, 80

NEXT_COMMAND:
  mov r6, Command.c // Store current c
  call load_command

  // If new c is 0, reuse last c
  qbne keep_c, Command.c, 0
  mov Command.c, r6
keep_c:
  call check_end_command
  reset_cyclecount r6

wait:
  get_cyclecount r1
// Apply c-scale factor 128=1<<7
  lsl r1, r1, 7
  qbgt wait, r1, Command.c

  // step on
  MOV r2, STEP
  MOV r3, GPIO0 | GPIO_SETDATAOUT
  SBBO r2, r3, 0, 4

  reset_cyclecount r6

//  sbbo Command.c, t_addr, 0, 4
//  add t_addr, t_addr, 4

  qbeq const_speed, Command.const, 1
  call calc_next_delay
const_speed:

  mov r6, 380 // 1.9us min step time for DRV8825
min_ontime:
  get_cyclecount r1
  qbgt min_ontime, r1, r6

  // step off?
  MOV r2, STEP
  MOV r3, GPIO0 | GPIO_CLEARDATAOUT
  SBBO r2, r3, 0, 4

//  sbbo r5, t_addr, 0, 8
//  add t_addr, t_addr, 8

  sub Command.steps, Command.steps, 1
  qblt wait, Command.steps, 0

  jmp NEXT_COMMAND

#include "fifo.p"

#define nom r3
#define den r4
#define quot r5
#define rem r6

calc_next_delay:
  // c = c - c*2/(4*(++n)+1)
  lsl nom, Command.c, 1
  add Command.n, Command.n, 1
  lsl den, Command.n, 2
  add den, den, 1
  divide nom, den, quot, rem, r0
  sub Command.c, Command.c, quot
  ret
