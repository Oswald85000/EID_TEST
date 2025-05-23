// =============================================================================
// EID_CTRL — Entropy-Informed Derivative core (Q16.16, 3 pipeline stages)
// =============================================================================
`timescale 1ns/1ps
`include "qtypes.svh"
import qtypes::*;

module eid_ctrl #(
    parameter integer WIDTH = 32,
    parameter integer FRAC  = 16          // Q16.16
)(
    input  wire                 clk,
    input  wire                 rst_n,

    // ---------- AXI-Lite WRITE-ONLY (α β γ δ) ------------------------------
    input  wire  [3:0]          s_axi_awaddr,
    input  wire                 s_axi_awvalid,
    output wire                 s_axi_awready,
    input  wire  [31:0]         s_axi_wdata,
    input  wire                 s_axi_wvalid,
    output wire                 s_axi_wready,

    // ---------- AXI-Lite READ (jamais utilisé) -----------------------------
    input  wire  [3:0]          s_axi_araddr,
    input  wire                 s_axi_arvalid,
    output wire                 s_axi_arready,
    output wire [31:0]          s_axi_rdata,
    output wire                 s_axi_rvalid,
    input  wire                 s_axi_rready,

    // ---------- flux H, F, O -----------------------------------------------
    input  wire [WIDTH-1:0]     din_h,
    input  wire [WIDTH-1:0]     din_f,
    input  wire [WIDTH-1:0]     din_o,
    input  wire                 din_valid,
    output wire                 din_ready,

    // ---------- sorties -----------------------------------------------------
    output wire [WIDTH-1:0]     dout_dhdt,
    output wire                 dout_alarm,
    output wire                 dout_valid,
    input  wire                 dout_ready
);

    // ---------------------------------------------------------------------[1]
    // registres coefficients
    // -------------------------------------------------------------------------
    logic signed [31:0] alpha, beta, gamma, delta;

    /* verilator coverage_off */   // “fil-de-fer” inertes → ignorés
    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_arready = 1'b1;
    assign s_axi_rvalid  = 1'b0;
    assign s_axi_rdata   = 32'h0;
    /* verilator coverage_on */

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alpha <= 32'sh0001_3334;   //  1.2
            beta  <= 32'sh0001_0000;   //  1.0
            gamma <= 32'sh0000_0CCD;   //  0.05
            delta <= 32'sh0000_0000;   //  0.0
        end
        else if (s_axi_awvalid && s_axi_wvalid) begin
            case (s_axi_awaddr[3:2])
                2'd0: alpha <= s_axi_wdata;
                2'd1: beta  <= s_axi_wdata;
                2'd2: gamma <= s_axi_wdata;
                2'd3: delta <= s_axi_wdata;
            endcase
        end
    end

    // ---------------------------------------------------------------------[2]
    // datapath Q16.16 saturé – 3 étapes
    // -------------------------------------------------------------------------
    logic signed [31:0] m_alpha, m_beta, m_gamma;
    logic signed [31:0] add1, add2, dhdt_q32;

    qmul_sat mul_alpha (.a(-alpha), .b(din_h), .y(m_alpha));          // −α·H
    qmul_sat mul_beta  (.a( beta),  .b(din_f), .y(m_beta));           // +β·F
    qadd_sat add_s1    (.a(m_alpha), .b(m_beta),  .y(add1));

    qmul_sat mul_gamma (.a( gamma), .b(din_o), .y(m_gamma));          // −γ·O
    qadd_sat add_s2a   (.a(add1),    .b(-m_gamma), .y(add2));
    qadd_sat add_s2b   (.a(add2),    .b( delta),   .y(dhdt_q32));     // +δ

    // ---------------------------------------------------------------------[3] pipeline valid/ready
    reg v0, v1, v2;
    always @(posedge clk) begin
        v0 <= din_valid;
        v1 <= v0;
        v2 <= v1;
    end

    assign din_ready  = 1'b1;
    assign dout_valid = v2 & dout_ready;
    assign dout_dhdt  = dhdt_q32;

    // ---------------------------------------------------------------------[4] alarme μ < 1  (α < β)
    reg alarm_r;
    always @(posedge clk) alarm_r <= (alpha < beta);
    assign dout_alarm = alarm_r;

endmodule
