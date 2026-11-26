![Simon Says Game](tt-simon-game.jpg)

## How it works

Simon says is a simple electronic memory game: the user has to repeat a growing sequence of colors.
The sequence is displayed by lighting up the LEDs. Each color also has a corresponding tone: G3, C4, E4 and G4
(about 200, 267, 320 and 400 Hz).

In each turn, the game will play the sequence, and then wait for the user to repeat the sequence
by pressing the buttons according to the color sequence.
If the user repeated the sequence correctly, the game plays a short "ding" (C5),
adds a new color at the end of the sequence, and moves to the next turn. The sequence grows up to 15 colors;
after that, each turn replays the same 15 colors.

A wrong press ends the game at once: the LEDs blink while the game plays a low buzz. Pressing several buttons at once counts as a wrong press. After the buzz, the LEDs show the power-on chase
again, and the next button press starts a new game.

The time of the first button press picks one of 255 different games.

This is a micro tile version of [urish/tt-simon-game](https://github.com/urish/tt-simon-game). A micro tile has no bidirectional pins, so there is no score display, and there is no internal clock: the game runs from a 3.2 kHz clock on `clk`.

## How to test

Provide a 3.2 kHz clock, reset the game, press any button to start it, and enjoy!

1. Connect the four push buttons to pins `btn1`, `btn2`, `btn3`, and `btn4`.
   Also connect each button to a pull down resistor.
2. Connect the LEDs to pins `led1`, `led2`, `led3`, and `led4`, matching
   the colors of the buttons (so `led1` and `btn1` have the same color, etc.).
   Don't forget current-limiting resistors!
3. Connect the speaker to the `speaker` pin (optional).

The [Simon Says Pmod](https://github.com/urish/tt-simon-pmod) works for the buttons, LEDs and buzzer; its
7-segment display stays dark.

## External Hardware

[Simon Says Pmod](https://github.com/urish/tt-simon-pmod) or four push buttons (with pull-down resistors), four LEDs, and optionally a speaker/buzzer.
