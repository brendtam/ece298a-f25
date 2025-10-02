# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # test reset
    dut.rst_n.value = 0
    assert dut.uo_out.value == 0
    dut.rst_n.value = 1

    # test count
    await ClockCycles(dut.clk, 3)
    assert dut.uo_out.value == 3

    # sync load
    dut.ui_in.value = 10
    dut.uio_in.value = 1
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)
    assert dut.uo_out.value == 13

    # tri state
    dut.uio_in.value = 2
    await ClockCycles(dut.clk, 1)
    assert dut.uio_out.value == 1
    
