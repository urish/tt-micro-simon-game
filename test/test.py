# SPDX-FileCopyrightText: © 2023-2026 Uri Shaked
# SPDX-License-Identifier: Apache-2.0
#
# Micro tile version: no 7-segment score (no uio pins), so the tests check the
# LEDs and the speaker only. The tests wait for events (with timeouts) instead
# of fixed delays, so they work with the micro tile timing.

import os
from collections import Counter
from itertools import pairwise

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, Timer

CLOCK_HZ = 3200
# Speaker half periods, in clock cycles
COLOR_HALF_PERIODS = [8, 6, 5, 4]  # G3 C4 E4 G4
LEVEL_UP_HALF_PERIODS = {6, 5, 4, 3}  # C4 E4 G4 C5
BUZZ_HALF_PERIOD = 16  # 100 Hz
GAME_SEQUENCE_TEST_LENGTH = int(os.getenv("GAME_SEQUENCE_TEST_LENGTH", "5"))


def half_periods(edges):
    """The set of intervals between speaker edges"""
    return {b - a for a, b in pairwise(edges)}


def notes(edges, min_count=8):
    """The intervals between speaker edges that occur at least min_count
    times (a note), leaving out the odd intervals where notes change"""
    counts = Counter(b - a for a, b in pairwise(edges))
    return {hp for hp, n in counts.items() if n >= min_count}


class SimonDriver:
    def __init__(self, dut):
        self._dut = dut
        self._dut.btn.value = 0
        cocotb.start_soon(Clock(dut.clk, round(1e9 / CLOCK_HZ), unit="ns").start())

    async def new_game(self, delay_cycles=32):
        """Reset, then press a button after delay_cycles to start a game (the
        delay seeds the LFSR)"""
        self._dut.rst_n.value = 0
        await ClockCycles(self._dut.clk, 10)
        self._dut.rst_n.value = 1
        await ClockCycles(self._dut.clk, delay_cycles)
        await self.press_button(0)

    async def wait_ms(self, n):
        """Wait n milliseconds, then for a falling clock edge: the outputs are
        combinational, so in the gate level simulation they are only read away
        from the rising edge"""
        await Timer(n, unit="ms")
        await FallingEdge(self._dut.clk)

    async def press_button(self, index, hold_ms=40):
        """Press a button, index is zero based"""
        self._dut.btn.value = 1 << index
        await self.wait_ms(hold_ms)
        self._dut.btn.value = 0
        await FallingEdge(self._dut.clk)

    def read_one_led(self):
        """Returns the index of the currently lit LED, or None if no LED is lit"""
        leds = int(self._dut.led.value)
        if leds == 0:
            return None
        for i in range(4):
            if leds == 1 << i:
                return i
        raise ValueError(f"Unexpected value for leds: {self._dut.led.value}")

    async def _wait_led_state(self, lit, timeout_ms):
        cycles = 0
        while (self.read_one_led() is not None) != lit:
            await FallingEdge(self._dut.clk)
            cycles += 1
            assert cycles < timeout_ms * CLOCK_HZ // 1000, f"timeout waiting for LED {'on' if lit else 'off'}"

    async def wait_for_led(self, timeout_ms=2000):
        await self._wait_led_state(True, timeout_ms)

    async def wait_for_leds_off(self, timeout_ms=2000):
        await self._wait_led_state(False, timeout_ms)

    async def speaker_edges(self, duration_ms):
        """Clock cycle numbers of the speaker edges over the given time"""
        edges = []
        last = int(self._dut.speaker.value)
        for cycle in range(duration_ms * CLOCK_HZ // 1000):
            await FallingEdge(self._dut.clk)
            v = int(self._dut.speaker.value)
            if v != last:
                edges.append(cycle)
            last = v
        return edges


async def play_round(simon, sequence):
    """Watch the game play len(sequence) + 1 colors, then repeat them"""
    for expected in sequence:
        await simon.wait_for_led()
        assert simon.read_one_led() == expected
        await simon.wait_for_leds_off()
    await simon.wait_for_led()
    sequence.append(simon.read_one_led())
    await simon.wait_for_leds_off()
    # Wait for the game to be ready for input
    await simon.wait_ms(120)
    for expected in sequence:
        await simon.press_button(expected)
        assert simon.read_one_led() == expected
        assert half_periods(await simon.speaker_edges(50)) == {COLOR_HALF_PERIODS[expected]}
        await simon.wait_for_leds_off(timeout_ms=500)
        await simon.wait_ms(30)


@cocotb.test()
async def test_simon(dut):
    simon = SimonDriver(dut)
    await simon.new_game()

    await simon.wait_for_led(timeout_ms=1000)
    initial_led_index = simon.read_one_led()
    dut._log.info(f"Initial LED index: {initial_led_index}")
    await simon.wait_for_leds_off(timeout_ms=500)
    assert await simon.speaker_edges(20) == []

    # Repeat the color with a short press: its LED lights while the button is pressed
    await simon.wait_ms(120)
    await simon.press_button(initial_led_index, hold_ms=10)
    assert simon.read_one_led() == initial_led_index
    await simon.wait_for_leds_off(timeout_ms=500)

    # Level up: a rising tune
    assert notes(await simon.speaker_edges(450)) == LEVEL_UP_HALF_PERIODS

    # Next level: the first color is replayed
    await simon.wait_for_led(timeout_ms=1500)
    assert simon.read_one_led() == initial_led_index


@cocotb.test()
async def test_tones(dut):
    """Each color plays its own tone (restart until all four colors were first)"""
    simon = SimonDriver(dut)
    seen = {}
    for i in range(40):
        await simon.new_game(delay_cycles=10 + 7 * i)
        await simon.wait_for_led(timeout_ms=1000)
        seen[simon.read_one_led()] = half_periods(await simon.speaker_edges(100))
        if len(seen) == 4:
            break
    dut._log.info(f"Half periods per color: {seen}")
    assert seen == {c: {hp} for c, hp in enumerate(COLOR_HALF_PERIODS)}


@cocotb.test()
async def test_long_game_sequence(dut):
    simon = SimonDriver(dut)
    await simon.new_game()
    sequence = []
    for i in range(GAME_SEQUENCE_TEST_LENGTH):
        dut._log.info(f"Testing round {i + 1}")
        await play_round(simon, sequence)
    # The next round starts with the same colors
    await simon.wait_for_led(timeout_ms=1500)
    assert simon.read_one_led() == sequence[0]
    dut._log.info(f"Sequence: {sequence}")


@cocotb.test()
async def test_game_over(dut):
    simon = SimonDriver(dut)
    await simon.new_game()

    await simon.wait_for_led(timeout_ms=1000)
    led_index = simon.read_one_led()
    await simon.wait_for_leds_off()
    await simon.wait_ms(120)

    # A wrong press ends the game at once: its LED does not light
    wrong = (led_index + 1) % 4
    await simon.press_button(wrong)
    assert int(dut.led.value) != 1 << wrong

    # Game over: all four LEDs blink while the speaker plays a falling tune
    # (the four colors' tones), then the buzz
    seen_all_on = False
    edges = []
    for i in range(48):
        seen_all_on |= int(dut.led.value) == 0b1111
        edges += [i * (25 * CLOCK_HZ // 1000) + e for e in await simon.speaker_edges(25)]
    assert seen_all_on
    assert notes(edges) == set(COLOR_HALF_PERIODS) | {BUZZ_HALF_PERIOD}

    # After the game over tone, any button starts a new game
    assert await simon.speaker_edges(50) == []
    await simon.press_button(0)
    await simon.wait_for_led(timeout_ms=1000)


# Skipped by default, as it takes a long time to run. To run it, use:
#
#     make COCOTB_TEST_FILTER=test_pseudo_randomness
@cocotb.test(skip=True)
async def test_pseudo_randomness(dut):
    simon = SimonDriver(dut)

    led_bins = [0, 0, 0, 0]

    def normalize_bins(bins):
        return [count / sum(bins) for count in bins]

    for i in range(400):
        # Vary the time of the first press by one clock cycle each iteration
        await simon.new_game(delay_cycles=10 + i)
        await simon.wait_for_led(timeout_ms=1000)
        led_bins[simon.read_one_led()] += 1

    dut._log.info(f"LED bins: {normalize_bins(led_bins)} (raw: {led_bins})")
    assert all(0.2 <= count <= 0.3 for count in normalize_bins(led_bins))
