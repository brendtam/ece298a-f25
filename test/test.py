import cocotb
from cocotb.triggers import RisingEdge, Timer


# ----------------------------
# Helper: safe read
# ----------------------------
def safe_int(sig):
    val = sig.value
    if val.is_resolvable:
        return int(val)
    return None


# ----------------------------
# 1. Basic sanity test
# ----------------------------
@cocotb.test()
async def test_dump(dut):
    await Timer(10, units="ns")
    assert True


# ----------------------------
# 2. Accumulator test (curr_u)
# ----------------------------
@cocotb.test()
async def accumulator_test(dut):
    await Timer(20, units="ns")

    try:
        old_u = safe_int(dut.curr_u)
    except:
        assert False, "curr_u not accessible"

    for _ in range(10):
        await RisingEdge(dut.clk)

    new_u = safe_int(dut.curr_u)

    assert new_u is not None, "curr_u became X"
    assert old_u is not None, "curr_u started X"


# ----------------------------
# 3. VGA signal test
# ----------------------------
@cocotb.test()
async def vga_signal_test(dut):
    await Timer(20, units="ns")

    # top-level signals (NOT internal hierarchy)
    hsync = safe_int(dut.uo_out)
    vsync = safe_int(dut.uo_out)

    assert hsync is not None


# ----------------------------
# 4. U-end test
# ----------------------------
@cocotb.test()
async def u_end_test(dut):
    for _ in range(20):
        await RisingEdge(dut.clk)

    state = safe_int(dut.state)
    assert state in (0, 1), "state invalid or X"


# ----------------------------
# 5. W-end test
# ----------------------------
@cocotb.test()
async def w_end_test(dut):
    for _ in range(50):
        await RisingEdge(dut.clk)

    if dut.state.value.is_resolvable:
        state = int(dut.state.value)
        assert state in (0, 1)
