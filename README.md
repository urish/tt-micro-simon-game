![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# Simon Says Game for Tiny Tapeout - micro tile edition

A port of [urish/tt-simon-game](https://github.com/urish/tt-simon-game) (commit ced4034) to a sky130A micro tile.

- [Read the documentation for project](docs/info.md)

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

![Simon Says](docs/tt-simon-game.jpg)

## About the game

Simon says is a simple electronic memory game: the user has to repeat a growing sequence of colors.
The sequence is displayed by lighting up the LEDs. Each color also has a corresponding tone.

In each turn, the game will play the sequence, and then wait for the user to repeat the sequence
by pressing the buttons according to the color sequence.
If the user repeated the sequence correctly, the game will play a "leveling-up" sound,
add a new color at the end of the sequence, and move to the next turn.

The game continues until the user has made a mistake. Then a game over sound is played, and the next button
press starts a new game. In this micro tile version a wrong press ends the game at once, several buttons at once count
as a wrong press, and the LEDs return to the power-on chase after the buzz.

## Online simulation

You can play the 1x1 version of the game (with the score display) using the online Wokwi simulation at
https://wokwi.com/projects/408757730664700929.
The simulation also shows the wiring diagram.
