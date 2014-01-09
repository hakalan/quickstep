#include "fifo.ph"

.origin 0
.entrypoint START

#define GPIO1 0x4804c000
#define GPIO_CLEARDATAOUT 0x190
#define GPIO_SETDATAOUT 0x194
#define LED_MASK (7<<22)

.struct CommandDefs
  .u32 pwm1
  .u32 pwm2
  .u32 pwm3
  .u32 time
  .u32 reps
.ends

.struct PwmStatus
  .u32 pwmPtr
  .u32 time
  .u32 mask
  .u32 bit
  .u32 pwm
  .u32 tmp
.ends

.assign PwmStatus, r1, r6, s
.assign FifoDefs, r8, r10, Fifo
.assign CommandDefs, r11, r15, Command

START:
  call init_fifo

NEXT_COMMAND:
  call load_command
  call check_end_command

REPEAT_LOOP:
  reset_cyclecount s.time
  call DO_ONE_PERIOD
  
  sub Command.reps, Command.reps, 1
  qbne REPEAT_LOOP, Command.reps, 0

  jmp NEXT_COMMAND

// Subroutines
DO_ONE_PERIOD:
  mov s.tmp, COMMAND_RAM
  sbbo Command, s.tmp, 0, SIZE(Command)

  mov s.mask, 0
  mov s.bit, 1<<22
  mov s.pwmPtr, COMMAND_RAM + OFFSET(Command.pwm1)

  LOOP_LEDS:
  lbbo s.pwm, s.pwmPtr, 0, SIZE(Command.pwm1)
  qbeq OFF, s.pwm, 0
  or s.mask, s.mask, s.bit

  OFF:
  lsl s.bit, s.bit, 1
  add s.pwmPtr, s.pwmPtr, SIZE(Command.pwm1)

  mov s.tmp, COMMAND_RAM + OFFSET(Command.pwm3)
  qble LOOP_LEDS, s.tmp, s.pwmPtr

  // Set output
  mov s.tmp, GPIO1 | GPIO_SETDATAOUT
  sbbo s.mask, s.tmp, 0, 4

  // Wait to clear outputs depending on pwms
  WAIT:
  get_cyclecount s.time, r0

  mov s.mask, 0
  mov s.bit, 1<<22
  mov s.pwmPtr, COMMAND_RAM + OFFSET(Command.pwm1)

  LOOP_PWM:
  lbbo s.pwm, s.pwmPtr, 0, SIZE(Command.pwm1)
  qbeq NOT_YET, s.pwm, 0 // Already off
  qbge NOT_YET, s.time, s.pwm // Keep on
  mov s.tmp, 0
  sbbo s.tmp, s.pwmPtr, 0, SIZE(Command.pwm1) // Clear pwm to signal off
  or s.mask, s.mask, s.bit // Set clear bit

  NOT_YET:  
  add s.pwmPtr, s.pwmPtr, SIZE(Command.pwm1)
  lsl s.bit, s.bit, 1
  mov s.tmp, COMMAND_RAM + OFFSET(Command.pwm3)
  qble LOOP_PWM, s.tmp, s.pwmPtr

  // Clear output
  qbeq NOTHING_TO_CLEAR, s.mask, 0
  mov s.tmp, GPIO1 | GPIO_CLEARDATAOUT
  sbbo s.mask, s.tmp, 0, 4

  NOTHING_TO_CLEAR:
  qblt WAIT, Command.time, s.time
  ret

#include "fifo.p"

