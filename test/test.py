import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer


@cocotb.test()
async def smoke_test(dut):

    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Initialize inputs
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Hold reset briefly
    await Timer(100, units="ns")

    # Release reset
    dut.rst_n.value = 1

    # Let sim run a bit
    await Timer(1000, units="ns")

    assert True
