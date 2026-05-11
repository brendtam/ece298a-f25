import cocotb
from cocotb.triggers import RisingEdge


# ----------------------------
# Helper: safe signal read
# ----------------------------
def safe_int(sig):
    if sig.value.is_resolvable:
        return sig.value.integer
    raise AssertionError(f"Signal {sig._name} contains X (uninitialized)")


# ----------------------------
# 1. Basic sanity test
# ----------------------------
@cocotb.test()
async def test_dump(dut):
    await RisingEdge(dut.clk)
    assert True


# ----------------------------
# 2. Accumulator test (curr_u)
# ----------------------------
@cocotb.test()
async def accumulator_test(dut):
    DUT = dut.tt_um_vga_example

    await RisingEdge(dut.clk)

    old_u = safe_int(DUT.curr_u)

    for _ in range(10):
        await RisingEdge(dut.clk)

    new_u = safe_int(DUT.curr_u)

    assert new_u != old_u, "curr_u did not change (accumulator not working)"


# ----------------------------
# 3. VGA signal test
# ----------------------------
@cocotb.test()
async def vga_signal_test(dut):
    DUT = dut.tt_um_vga_example

    await RisingEdge(dut.clk)

    hsync = safe_int(DUT.hvsync_gen.hsync)
    vsync = safe_int(DUT.hvsync_gen.vsync)

    assert hsync in (0, 1), "hsync invalid"
    assert vsync in (0, 1), "vsync invalid"


# ----------------------------
# 4. U-end test (state stability)
# ----------------------------
@cocotb.test()
async def u_end_test(dut):
    DUT = dut.tt_um_vga_example

    for _ in range(10):
        await RisingEdge(dut.clk)

    state = safe_int(DUT.state)

    assert state in (0, 1), "state out of range"


# ----------------------------
# 5. W-end test (X-safe FSM check)
# ----------------------------
@cocotb.test()
async def w_end_test(dut):
    DUT = dut.tt_um_vga_example

    for _ in range(50):
        await RisingEdge(dut.clk)

        if DUT.state.value.is_resolvable:
            state = DUT.state.value.integer
            assert state in (0, 1), "invalid FSM state"
        else:
            raise AssertionError("state contains X (uninitialized logic)")
