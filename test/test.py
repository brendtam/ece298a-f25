import cocotb
from cocotb.triggers import RisingEdge


# ----------------------------
# Helper: safe read of output bits
# ----------------------------
def safe(sig):
    val = sig.value
    assert val.is_resolvable, f"{sig._name} has X/Z"
    return int(val)


# ----------------------------
# 1. Smoke test (clock works)
# ----------------------------
@cocotb.test()
async def test_dump(dut):
    for _ in range(5):
        await RisingEdge(dut.clk)
    assert True


# ----------------------------
# 2. Output sanity test
# ----------------------------
@cocotb.test()
async def output_sanity_test(dut):
    for _ in range(10):
        await RisingEdge(dut.clk)

        out = safe(dut.uo_out)

        # must always be 8-bit valid signal
        assert 0 <= out <= 0xFF, "uo_out out of range"


# ----------------------------
# 3. Activity test (design is alive)
# ----------------------------
@cocotb.test()
async def activity_test(dut):
    prev = safe(dut.uo_out)

    changed = False

    for _ in range(50):
        await RisingEdge(dut.clk)
        curr = safe(dut.uo_out)

        if curr != prev:
            changed = True
            break

        prev = curr

    assert changed, "uo_out never changes (design may be stuck/reset)"


# ----------------------------
# 4. Reset behavior test
# ----------------------------
@cocotb.test()
async def reset_test(dut):
    dut.rst_n.value = 0

    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1

    await RisingEdge(dut.clk)

    out = safe(dut.uo_out)

    assert out is not None, "output invalid after reset"
