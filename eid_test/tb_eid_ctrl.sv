`timescale 1ns/1ps
// ============================================================================
// Testbench   tb_eid_ctrl.sv     (Icarus Verilog friendly)
// ============================================================================
module tb_eid_ctrl;
  // ---------------- clock / reset ------------------------------------------
  localparam CLK_PER = 10;                    // 100 MHz
  logic clk = 0; always #(CLK_PER/2) clk = ~clk;
  logic rst_n = 0; initial begin #80 rst_n = 1; end

  // ---------------- helper Q16.16 ------------------------------------------
  function automatic [31:0] FL (real r);
    FL = $rtoi(r * (1<<16));
  endfunction

  // ---------------- AXI-Lite signals ---------------------------------------
  logic [3:0] awaddr;  logic awvalid, awready;
  logic [31:0] wdata;  logic wvalid, wready;
  // read left un-used
  logic [3:0] araddr = 0; logic arvalid = 0, arready;
  logic [31:0] rdata; logic rvalid;

  // ---------------- stream signals -----------------------------------------
  logic [31:0] din_h, din_f, din_o;
  logic        din_valid, din_ready;
  logic [31:0] dout_dhdt;
  logic        dout_alarm;
  logic        dout_valid, dout_ready = 1;

  // ---------------- DUT -----------------------------------------------------
  eid_ctrl DUT (
    .clk(clk), .rst_n(rst_n),
    // AXI write
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata),   .s_axi_wvalid(wvalid),   .s_axi_wready(wready),
    // AXI read (tie off)
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata),   .s_axi_rvalid(rvalid),   .s_axi_rready(1'b0),
    // stream
    .din_h(din_h), .din_f(din_f), .din_o(din_o),
    .din_valid(din_valid), .din_ready(din_ready),
    .dout_dhdt(dout_dhdt), .dout_alarm(dout_alarm),
    .dout_valid(dout_valid), .dout_ready(dout_ready)
  );

  // ---------------- waveform dump ------------------------------------------
  initial begin
    $dumpfile("eid.vcd");
    $dumpvars(0, tb_eid_ctrl);
  end

  // ---------------- scenario ------------------------------------------------
  initial begin
    // === Case 1 : α = 1.2  → alarm = 0
    axi_write(4'h0, FL(1.2)); axi_write(4'h4, FL(1.0));
    axi_write(4'h8, FL(0.05)); axi_write(4'hC, FL(0.01));
    send_sample(FL(1.0), FL(0.1), 32'd0);
    wait(dout_valid);
    $display("Case1 dhdt=%0d alarm=%0b", dout_dhdt, dout_alarm);
    assert(!dout_alarm) else $fatal(1, "Case1 : alarm should be 0");

    // === Case 2 : α = 0.8  → alarm = 1
    axi_write(4'h0, FL(0.8));
    send_sample(FL(1.0), FL(0.1), 32'd0);
    wait(dout_valid);
    $display("Case2 dhdt=%0d alarm=%0b", dout_dhdt, dout_alarm);
    assert(dout_alarm)  else $fatal(1, "Case2 : alarm should be 1");

    $display("\\n*** Test PASSED ***\\n");
    #50 $finish;
  end

  // ----------------------- tasks -------------------------------------------
  task automatic axi_write(input [3:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      awaddr  <= addr; wdata <= data; awvalid <= 1; wvalid <= 1;
      @(posedge clk);
      awvalid <= 0;    wvalid <= 0;
    end
  endtask

  task automatic send_sample(
      input [31:0] h, input [31:0] f, input [31:0] o);
    begin
      @(posedge clk);
      din_h <= h; din_f <= f; din_o <= o; din_valid <= 1;
      @(posedge clk);
      din_valid <= 0;
    end
  endtask
endmodule
