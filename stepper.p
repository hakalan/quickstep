#include "fifo.ph"
#include "division.pm"

.origin 0
.entrypoint START

.struct CmdParams
  .u32 steps
  .u32 c
  .u32 n
  .u32 dec_n
  .u32 acc_steps
  .u32 dec_start
  .u32 steps1
  .u32 steps2
  .u32 steps3
  .u32 steps4
.ends

.struct StepperRuntime
  .u32 out
  .u32 error
.ends

.struct RamDefs
  .u32 ddr_address
  .u32 sim
.ends

.struct Global
  .u32 remainder
  .u32 stepsdone
.ends

// r0-r3 are temporary variables
#define tmp r0
#define nom r1
#define den r2
#define quot r3

// r5 and up are global
.assign Global, r4, r5, global

.assign FifoDefs, r7, r9, Fifo

// Sharing memory for command parameters
.assign CmdParams, r10, r19, Command

.assign StepperRuntime, r20, r21, stepper1
.assign StepperRuntime, r22, r23, stepper2
.assign StepperRuntime, r24, r25, stepper3
.assign StepperRuntime, r26, r27, stepper4

#define GPIO0 0x44E07000
#define GPIO1 0x4804c000
#define GPIO_CLEARDATAOUT 	0x190
#define GPIO_SETDATAOUT 	0x194
#define TOGGLE_GPIO 0x4

#define STEP1 (1<<27)
#define STEP2 (1<<22)
#define STEP3 (1<<23)
#define STEP4 (1<<24)

.macro stepmotor
.mparam motor, msteps, xsteps, outmask
  sub motor.error, motor.error, msteps
  qbbc step_done, motor.error,31
  add motor.error, motor.error, xsteps

  // toggle output pin
  mov r2, outmask
  sbbo r2, motor.out, 0, 4
  xor motor.out, motor.out, TOGGLE_GPIO
step_done:
.endm

START:
  call init_fifo
  mov stepper1.out, GPIO0 | GPIO_SETDATAOUT
  mov stepper2.out, GPIO1 | GPIO_SETDATAOUT
  mov stepper3.out, GPIO1 | GPIO_SETDATAOUT
  mov stepper4.out, GPIO1 | GPIO_SETDATAOUT

//  mov r0, PRUSS_PRU_CTRL
//  lbbo r1, r0, CONTROL, 4
//  set r1, 8 // singlestep
//  sbbo r1, r0, CONTROL, 4


NEXT_COMMAND:
  call load_command
  reset_cyclecount r3

  // End?
  qbne not_end, Command.steps, 0
  mov R31.b0, PRU0_ARM_INTERRUPT+16
  halt
not_end:

  // Do move
  mov global.stepsdone, 0
  mov global.remainder, 0
  lsr stepper1.error, Command.steps, 1
  lsr stepper2.error, Command.steps, 1
  lsr stepper3.error, Command.steps, 1
  lsr stepper4.error, Command.steps, 1

wait:
  get_cyclecount r1

// Apply c-scale factor 256=1<<8
  lsl r1, r1, 8
  qbgt wait, r1, Command.c

  reset_cyclecount r3

//  sub r1, r1 ,r1
//  lbbo r0, r1, OFFSET(RamDefs.sim), 4
//  qbeq dostep, r0, 0

  // Dump current c in ddr
  sbbo Command.c, Fifo.addr, 8, SIZE(Command.c)

  qba done
dostep:
// Move steppers
  stepmotor stepper1, Command.steps1, Command.steps, STEP1
  stepmotor stepper2, Command.steps2, Command.steps, STEP2
  stepmotor stepper3, Command.steps3, Command.steps, STEP3
  stepmotor stepper3, Command.steps4, Command.steps, STEP4

done:
  add global.stepsdone, global.stepsdone, 1

  qbgt acc_done, Command.acc_steps, global.stepsdone

  // quot = (c*2)/(4*n+1)
  // remainder = (c*2)%(4*n+1)
  add Command.n, Command.n, 1
  lsl nom, Command.c, 1
//  add nom, nom, global.remainder
  lsl den, Command.n, 2
  add den, den, 1
  divide nom, den, quot, global.remainder, r0
  sub Command.c, Command.c, quot

  qba wait

acc_done:
  qbgt decel, Command.dec_start, global.stepsdone
  qba wait

decel:
  qbgt NEXT_COMMAND, Command.steps, global.stepsdone

  // quot = (c*2+remainder)/(4*n+1)
  // remainder = (c*2+remainder)%(4*n+1)
  sub Command.dec_n, Command.dec_n, 1
  lsl nom, Command.c, 1
//  add nom, nom, global.remainder
  lsl den, Command.dec_n, 2
  sub den, den, 1
  divide nom, den, quot, global.remainder, r0
  add Command.c, Command.c, quot

  qba wait

#include "fifo.p"


