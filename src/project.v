/*
 * Copyright (c) 2024-2026 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Micro tile: clk, rst_n, ui_in and uo_out only (no uio, no ena)
module tt_um_urish_micro_simon (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire [3:0] led;
  wire sound;

  assign uo_out = {3'b000, sound, led};

  simon simon1 (
      .clk  (clk),
      .rst  (!rst_n),
      .btn  (ui_in[3:0]),
      .led  (led),
      .sound(sound)
  );

  // List all unused inputs to prevent warnings
  wire _unused = &{ui_in[7:4], 1'b0};

endmodule
