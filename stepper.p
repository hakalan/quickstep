#include "fifo.ph"
#include "division.pm"

.origin 0
.entrypoint START

#define StateAcc 0
#define StateConst 1
#define StateDec 2

.struct CmdParams
  .u32 steps
  .u32 c
  .u32 n
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
.ends

.struct Global
  .u32 remainder
  .u32 stepsdone
  .u32 t_addr
.ends

// r0-r3 are temporary variables
#define tmp r0
#define nom r1
#define den r2
#define quot r3

// r5 and up are global
.assign Global, r5, r7, global

.assign FifoDefs, r8, r10, Fifo

// Sharing memory for command parameters
.assign CmdParams, r11, r19, Command

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
.mparam motor, msteps, xsteps, next
  sub motor.error, motor.error, msteps
  qbbc next, motor.error,31
  add motor.error, motor.error, xsteps

  // toggle output pin
  mov r2, STEP1
  sbbo r2, motor.out, 0, 4
  xor motor.out, motor.out, TOGGLE_GPIO
.endm

START:
  call init_fifo
  mov global.t_addr, Fifo.addr
  add global.t_addr, global.t_addr, 80
  mov stepper1.out, GPIO0 | GPIO_SETDATAOUT
  mov stepper2.out, GPIO1 | GPIO_SETDATAOUT
  mov stepper3.out, GPIO1 | GPIO_SETDATAOUT
  mov stepper4.out, GPIO1 | GPIO_SETDATAOUT
  
NEXT_COMMAND:
  call load_command
  reset_cyclecount r1

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
// Apply c-scale factor 1024=1<<10
  lsl r1, r1, 10
  qbgt wait, r1, Command.c

  reset_cyclecount r1

// Move steppers
  stepmotor stepper1, Command.steps1, Command.steps, step2
step2:
  stepmotor stepper2, Command.steps2, Command.steps, step3
step3:
  stepmotor stepper3, Command.steps3, Command.steps, step4
step4:
  stepmotor stepper3, Command.steps4, Command.steps, done

done:
  add global.stepsdone, global.stepsdone, 1
  qbgt acc_done, Command.acc_steps, global.stepsdone

  // quot = (c*2+remainder)/(4*n+1)
  // remainder = (c*2+remainder)%(4*n+1)
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
  sub Command.n, Command.n, 1
  lsl nom, Command.c, 1
//  add nom, nom, global.remainder
  lsl den, Command.n, 2
  sub den, den, 1
  divide nom, den, quot, global.remainder, r0
  add Command.c, Command.c, quot

  qba wait

#include "fifo.p"


