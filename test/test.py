import cocotb
from cocotb.triggers import RisingEdge, Timer


# ----------------------------
# Helper: reset DUT safely
# ----------------------------
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.ena.value = 1

    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1

    for _ in range(5):
        await RisingEdge(dut.clk)


# ----------------------------
# 1. Basic smoke test
# ----------------------------
@cocotb.test()
async def test_dump(dut):
    await reset_dut(dut)
    assert True


# ----------------------------
# 2. Output sanity test (no X values)
# ----------------------------
@cocotb.test()
async def output_sanity_test(dut):
    await reset_dut(dut)

    for _ in range(20):
        await RisingEdge(dut.clk)

        out = int(dut.uo_out.value)

        # Ensure no unknowns (X/Z)
        assert dut.uo_out.value.is_resolvable(), "uo_out has X/Z values"


# ----------------------------
# 3. Activity test (design is alive)
# ----------------------------
@cocotb.test()
async def activity_test(dut):
    await reset_dut(dut)

    seen_values = set()

    for _ in range(30):
        await RisingEdge(dut.clk)
        seen_values.add(int(dut.uo_out.value))

    # If design is working, output should vary over time
    assert len(seen_values) > 1, "uo_out is static (design may be stuck)"


# ----------------------------
# 4. Reset test (basic stability)
# ----------------------------
@cocotb.test()
async def reset_test(dut):
    dut.rst_n.value = 0
    dut.ena.value = 1

    for _ in range(3):
        await RisingEdge(dut.clk)

    # After reset, output should still be defined
    assert dut.uo_out.value.is_resolvable(), "uo_out invalid after reset"
