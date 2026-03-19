`ifndef TRAP_VH
`define TRAP_VH

`define TRAP_NONE                   4'b0000
`define TRAP_EBREAK                 4'b0001
`define TRAP_ECALL                  4'b0010
`define TRAP_MISALIGNED_INSTRUCTION 4'b0011
`define TRAP_MRET                   4'b0100
`define TRAP_FENCEI                 4'b0101
`define TRAP_MISALIGNED_STORE       4'b0110
`define TRAP_MISALIGNED_LOAD        4'b0111
`define TRAP_TIMER_IRQ              4'b1000

`endif
