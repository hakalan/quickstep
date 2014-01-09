// Divide reg N with D
// result in reg Q and R, where |R| < D/2
// uses tmp reg for temporary data
.macro divide
.mparam N, D, Q, R, tmp = r0
  clr tmp, tmp, 31
  qbbc positive_d, D, 31
  set tmp, tmp, 31 
  not D, D
  add D, D, 1
positive_d:
  mov Q, 0
  mov R, 0
  mov tmp.b0, 31
next_bit:
  add N, N, N // set carry to leftmost bit in N
  adc R, R, R // R = R<<1 + carry
  qblt below, D, R
  sub R, R, D
  set Q, tmp
below:
  sub tmp, tmp, 1
  qbgt next_bit, tmp.b0, 31

  // perform rounding?
  lsl N, R, 1
  qble no_round, D, N
  add Q, Q, 1
  sub R, R, D
no_round:
  qbbc positive_d2, tmp, 31
  not Q, Q
  add Q, Q, 1
positive_d2:
.endm
