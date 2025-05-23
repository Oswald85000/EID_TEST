/* verilator coverage_off */

/* verilator lint_off MODDUP */
`include "qtypes.svh"
import qtypes::*;
/* verilator lint_on  MODDUP */

module qadd_sat
  (input  logic signed [31:0] a,
   input  logic signed [31:0] b,
   output logic signed [31:0] y);

  logic signed [32:0] s = a + b;         // 1 bit de garde
  assign y = (s >  33'sh3FFF_FFFF) ? 32'sh7FFF_FFFF :
             (s < -33'sh4000_0000) ? -32'sh8000_0000 :
             s[31:0];
endmodule

/* verilator coverage_on */
