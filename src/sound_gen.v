/*
 * Copyright (c) 2024-2026 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Square wave with a half period of half_period + 1 clock cycles, while enabled
module sound_gen (
    input wire clk,
    input wire rst,
    input wire enable,
    input wire [2:0] half_period,  // in clock cycles, minus one
    output wire sound
);

  reg [2:0] counter;
  reg wave;

  always @(posedge clk) begin
    if (rst || !enable) begin
      counter <= 0;
      wave <= 0;
    end else if (counter == 0) begin
      counter <= half_period;
      wave <= !wave;
    end else begin
      counter <= counter - 1;
    end
  end

  // wave clears one cycle after enable falls: mute that cycle too
  assign sound = wave && enable;

endmodule
