`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
   A micro tile has only clk, rst_n, ui_in and uo_out.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave.
  `ifndef NO_VCD
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end
  `endif

  // inputs from testbench
  reg [3:0] btn;

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  wire [7:0] ui_in = {4'b0000, btn};
  wire [7:0] uo_out;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  wire [3:0] led = uo_out[3:0];
  wire speaker = uo_out[4];

  tt_um_urish_micro_simon user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
