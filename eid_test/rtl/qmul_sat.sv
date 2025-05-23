/* verilator coverage_off */

/* verilator lint_off MODDUP */
`include "qtypes.svh"
import qtypes::*;
/* verilator lint_on  MODDUP */

module qmul_sat
  (input  logic signed [31:0] a,
   input  logic signed [31:0] b,
   output logic signed [31:0] y);

  logic signed [63:0] p = a * b;     // produit 64 bits
  logic signed [31:0] r = p[47:16];  // alignement Q16.16
  assign y = (r >  32'sh7FFF_FFFF) ? 32'sh7FFF_FFFF :
             (r < -32'sh8000_0000) ? -32'sh8000_0000 :
             r;
endmodule

/* verilator coverage_on */
