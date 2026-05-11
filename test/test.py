import cocotb
from cocotb.triggers import RisingEdge


def safe(sig):
    assert sig.value.is_resolvable
    return int(sig.value)


@cocotb.test()
async def test_dump(dut):
    for _ in range(5):
        await RisingEdge(dut.clk)


@cocotb.test()
async def output_sanity_test(dut):
    for _ in range(10):
        await RisingEdge(dut.clk)

    out = safe(dut.uo_out)
    assert 0 <= out <= 0xFF


@cocotb.test()
async def activity_test(dut):
    prev = safe(dut.uo_out)

    for _ in range(30):
        await RisingEdge(dut.clk)
        curr = safe(dut.uo_out)

        if curr != prev:
            return

        prev = curr

    assert False, "uo_out never changes"


@cocotb.test()
async def reset_test(dut):
    dut.rst_n.value = 0

    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1

    await RisingEdge(dut.clk)

    assert dut.uo_out.value.is_resolvable
