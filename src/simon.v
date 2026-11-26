// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: © 2023-2026 Uri Shaked

/*
 * Simon Says game in Verilog. Wokwi Simulation project:
 * https://wokwi.com/projects/408757730664700929
 *
 * Micro tile version. Differences from the 1x1 version:
 * - no score display (a micro tile has no uio pins for the segments)
 * - a time unit of 64 clock cycles (20 ms at 3.2 kHz)
 * - an 8-bit LFSR that steps once per color and steps back to replay the
 *   sequence (255 different games). The color is two LFSR bits 4 apart, so
 *   consecutive colors share no bit.
 * - the original's G-C-E-G chord from a 3-bit half-period counter
 * - a four-note tune between levels; a four-note tune, then a buzz, at game over
 * - no tone register: the tone and the LEDs are decoded from the state, the
 *   timer and the expected color. A wrong press goes straight to game over.
 * - the sequence length is capped at MAX_GAME_LEN
 */

`default_nettype none

module simon (
    input wire clk,
    input wire rst,
    input wire [3:0] btn,
    output reg [3:0] led,
    output wire sound
);

  localparam MAX_GAME_LEN = 63;
  localparam GAME_LEN_BITS = $clog2(MAX_GAME_LEN + 1);

  localparam StatePowerOn = 3'd0;  // also after the game over tone
  localparam StateInit = 3'd1;
  localparam StateRewind = 3'd2;  // step the LFSR back to the first color
  localparam StatePlayWait = 3'd3;  // show one color
  localparam StateUserWait = 3'd4;
  localparam StateUserInput = 3'd5;  // a correct press: play its color
  localparam StateNextLevel = 3'd6;  // level up tune, and step the LFSR back
  localparam StateGameOver = 3'd7;

  // Keep the 3-bit state encoding: one-hot recoding costs five more flip-flops
  (* fsm_encoding = "none" *)
  reg [2:0] state;
  reg [GAME_LEN_BITS - 1:0] seq_counter;
  reg [GAME_LEN_BITS - 1:0] level;  // sequence length - 1
  reg [5:0] prescaler;  // free running
  reg [4:0] unit_timer;  // time units (20 ms) since unit_timer was last cleared
  reg [7:0] lfsr;

  wire unit_tick = &prescaler;

  // Durations: unit_timer counts up from 0 one by one, so testing the set
  // bits is enough to catch the first time unit_timer reaches the value
  wire t320 = unit_timer[4];  // 16 units
  wire t400 = unit_timer[4] & unit_timer[2];  // 20 units
  wire t480 = unit_timer[4] & unit_timer[3];  // 24 units

  // Sequence: the LFSR steps forward once per color; to replay the sequence
  // from its start, the game steps it back once per color (one per clock
  // cycle), counting seq_counter down to 0.
  wire [1:0] color = {lfsr[4], lfsr[0]};
  wire seq_last = seq_counter == level;
  wire rewinding = (state == StateRewind || state == StateNextLevel) && seq_counter != 0;
  wire seq_next = (state == StatePlayWait && t400) || (state == StateUserInput && t320);
  wire lfsr_free = state == StatePowerOn || state == StateGameOver;
  wire lfsr_fwd = lfsr_free || (seq_next && !seq_last);

  // x^8 + x^6 + x^5 + x^4 + 1, one step forward / back
  wire [7:0] lfsr_next = {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
  wire [7:0] lfsr_prev = {lfsr[0] ^ lfsr[6] ^ lfsr[5] ^ lfsr[4], lfsr[7:1]};

  always @(posedge clk) begin
    if (rst) lfsr <= 8'hff;
    else if (rewinding) lfsr <= lfsr_prev;
    else if (lfsr_fwd) lfsr <= lfsr_next;
  end

  // Tone and LEDs, decoded from the state
  wire color_on = (state == StatePlayWait || state == StateUserInput) && !t320;

  // Half periods in clock cycles at 3.2 kHz: 8/6/5/4/3 = 200/267/320/400/533 Hz
  // (~G3, C4, E4, G4, C5). Colors: G3 C4 E4 G4; level up tune (80 ms notes):
  // C4 E4 G4 C5; game over tune (80 ms notes): G4 E4 C4 G3. Game over buzz:
  // 100 Hz from the prescaler.
  reg [2:0] half_period;  // minus one
  reg note_on;
  always @(*) begin
    note_on = 1'b1;
    half_period = 3'd2;
    if (color_on)
      case (color)
        2'd0: half_period = 3'd7;
        2'd1: half_period = 3'd5;
        2'd2: half_period = 3'd4;
        default: half_period = 3'd3;
      endcase
    else if (state == StateNextLevel)
      case (unit_timer[4:2])
        3'd1: half_period = 3'd5;
        3'd2: half_period = 3'd4;
        3'd3: half_period = 3'd3;
        3'd4: half_period = 3'd2;
        default: note_on = 1'b0;
      endcase
    else if (state == StateGameOver)
      case (unit_timer[4:2])
        3'd0: half_period = 3'd3;
        3'd1: half_period = 3'd4;
        3'd2: half_period = 3'd5;
        3'd3: half_period = 3'd7;
        default: note_on = 1'b0;
      endcase
    else note_on = 1'b0;
  end

  wire note;
  sound_gen sound_gen_inst (
      .clk(clk),
      .rst(rst),
      .enable(note_on),
      .half_period(half_period),
      .sound(note)
  );

  wire buzz_on = state == StateGameOver && !note_on;
  assign sound = buzz_on ? prescaler[4] : note;

  always @(*) begin
    led = 4'b0000;
    if (color_on) led[color] = 1'b1;
    else if (state == StateGameOver) led = {4{unit_timer[3]}};
    else if (state == StatePowerOn) begin
      led = 4'b1111;
      led[unit_timer[4:3]] = 1'b0;
    end
  end

  wire btn_ok = btn == (4'b0001 << color);

  always @(posedge clk) begin
    if (rst) begin
      prescaler <= 0;
      state <= StatePowerOn;
      level <= 0;
      seq_counter <= 0;
      unit_timer <= 0;
    end else begin
      prescaler <= prescaler + 1;
      if (unit_tick) begin
        unit_timer <= unit_timer + 1;
      end
      if (rewinding) begin
        seq_counter <= seq_counter - 1;
      end

      case (state)
        StatePowerOn: begin
          // Wait until the user presses some button - the delay will seed the LFSR
          if (btn != 0) begin
            unit_timer <= 0;
            state <= StateInit;
          end
        end
        StateInit: begin
          level <= 0;
          seq_counter <= 0;
          if (t480) begin
            unit_timer <= 0;
            state <= StatePlayWait;
          end
        end
        StateRewind: begin
          if (seq_counter == 0) begin
            // unit_timer = 1: a button already held down counts as the first press
            unit_timer <= 1;
            state <= StateUserWait;
          end
        end
        StatePlayWait: begin
          if (t400) begin
            unit_timer <= 0;
            if (seq_last) begin
              state <= StateRewind;
            end else begin
              seq_counter <= seq_counter + 1;
            end
          end
        end
        StateUserWait: begin
          // unit_timer stays 0 until all buttons are released (debounce: up to
          // one time unit), then stays 1 until the next press
          if (btn == 0) begin
            if (unit_timer != 0) unit_timer <= 1;
          end else begin
            unit_timer <= 0;
            if (unit_timer != 0) state <= btn_ok ? StateUserInput : StateGameOver;
          end
        end
        StateUserInput: begin
          if (t320) begin
            unit_timer <= 0;
            if (seq_last) begin
              if (level != MAX_GAME_LEN - 1) begin
                level <= level + 1;
              end
              state <= StateNextLevel;
            end else begin
              seq_counter <= seq_counter + 1;
              state <= StateUserWait;
            end
          end
        end
        StateNextLevel: begin
          // level up tune (decoded from unit_timer), then replay the sequence
          if (t480) begin
            unit_timer <= 0;
            state <= StatePlayWait;
          end
        end
        StateGameOver: begin
          // game over tune and buzz, then the power-on LED chase until a button is pressed
          if (t480) begin
            state <= StatePowerOn;
          end
        end
        default: ;
      endcase
    end
  end

endmodule
