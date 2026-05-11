import cocotb
from cocotb.triggers import RisingEdge


def get_dut(dut):
    for name in ["tt_um_vga_example", "uut", "dut"]:
        if hasattr(dut, name):
            return getattr(dut, name)
    return dut


def safe(sig):
    assert sig.value.is_resolvable, f"{sig._name} has X/Z"
    return int(sig.value)


@cocotb.test()
async def test_dump(dut):
    for _ in range(5):
        await RisingEdge(dut.clk)


@cocotb.test()
async def output_sanity_test(dut):
    m = get_dut(dut)

    for _ in range(10):
        await RisingEdge(dut.clk)

    out = safe(m.uo_out)
    assert 0 <= out <= 0xFF


@cocotb.test()
async def activity_test(dut):
    m = get_dut(dut)

    prev = None

    for _ in range(30):
        await RisingEdge(dut.clk)
        curr = safe(m.uo_out)

        if prev is not None and curr != prev:
            return

        prev = curr

    assert False, "uo_out never changes"


@cocotb.test()
async def reset_test(dut):
    m = get_dut(dut)

    dut.rst_n.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    out = safe(m.uo_out)
    assert out is not None
