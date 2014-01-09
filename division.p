#include "fifo.ph"
#include "division.pm"

.origin 0
.entrypoint START

.struct CommandDefs
  .u32 nominator
  .u32 denominator
.ends

.struct ResultDef
  .u32 quotient
  .u32 remainder
  .u32 time
.ends

.assign ResultDef, r5, r7, r
.assign FifoDefs, r8, r10, Fifo
.assign CommandDefs, r11, r12, Command

START:
  call init_fifo

NEXT_COMMAND:
  call load_command
  call check_end_command

REPEAT_LOOP:
  reset_cyclecount r.time
  divide Command.nominator, Command.denominator, r.quotient, r.remainder
  get_cyclecount r.time
  sbbo r, Fifo.addr, 40, SIZE(r)

  jmp NEXT_COMMAND

#include "fifo.p"

