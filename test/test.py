import cocotb
import math
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ReadOnly

def dump_hierarchy(obj, indent=0):
    for name in dir(obj):
        try:
            child = getattr(obj, name)
            if hasattr(child, "_fullname"):
                print("  " * indent + name)
                dump_hierarchy(child, indent+1)
        except Exception:
            pass

@cocotb.test()
async def test_dump(dut):
    dut._log.info("dut members: %s", dir(dut))
    dump_hierarchy(dut)

def within_2px(val, expected):
    return expected-2.0 <= val <= expected+2.0

def get_expected_signs(angle_idx):
    q = angle_idx >> 3   # quadrant 0–3

    # x step uses cos
    # y step uses sin
    if q == 0:
        return (1, 1)
    elif q == 1:
        return (-1, 1)
    elif q == 2:
        return (-1, -1)
    else:
        return (1, -1)

def to_signed14(x):
    x &= 0x3FFF               # keep only 14 bits
    if x & 0x2000:            # if sign bit is set
        return x - 0x4000     # convert to negative value
    return x

@cocotb.test()
async def accumulator_test(dut):
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1
    dut.user_project.state.value = 1

    for _ in range(5):
        await RisingEdge(dut.clk)

    for step in range(1000000):
        await ReadOnly()

        old_u = dut.user_project.curr_u.value.signed_integer
        old_v = dut.user_project.curr_v.value.signed_integer

        cos_val = dut.user_project.cos_val.value.signed_integer
        sin_val = dut.user_project.sin_val.value.signed_integer
        angle_idx = dut.user_project.angle_idx.value.integer

        sign_x, sign_y = get_expected_signs(angle_idx)

        expected_u = to_signed14(old_u + sign_x * cos_val)
        expected_v = to_signed14(old_v + sign_y * sin_val)

        await RisingEdge(dut.clk)
        await ReadOnly()

        new_u = dut.user_project.curr_u.value.signed_integer
        new_v = dut.user_project.curr_v.value.signed_integer

        pix_x = dut.user_project.hvsync_gen.hpos.value.integer
        pix_y = dut.user_project.hvsync_gen.vpos.value.integer

        if (pix_x > 640 or pix_y > 480):
            continue

        assert abs(new_u - expected_u) <= 15, \
            f"accumulator U step wrong at {pix_x},{pix_y} (angle {angle_idx}): old={old_u} new={new_u} expected={expected_u}"

        assert abs(new_v - expected_v) <= 15, \
            f"accumulator V step wrong at {pix_x},{pix_y} (angle {angle_idx}): old={old_v} new={new_v} expected={expected_v}"

@cocotb.test()
async def vga_signal_test(dut):
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1

    for frame in range(0, 5):
        dut._log.info(f"testing frame {frame}")
        for i in range(0, 525):
            for j in range(0, 800):
                await RisingEdge(dut.clk)

                hsync = dut.user_project.hvsync_gen.hsync.value.integer
                if (j > 656 and j <= 752):
                    assert hsync == 1, f"hsync not enabled on x={j}"
                else:
                    assert hsync == 0, f"hsync not disabled on x={j}"
                
                pix_x = dut.user_project.hvsync_gen.hpos.value.integer
                assert pix_x == j, f"value from module {pix_x} and expected value {j} are not equal"

                display_on = dut.user_project.hvsync_gen.display_on.value.integer
                if (j < 640 and i < 480):
                    assert display_on == 1, f"display at {j},{i} should be on"
                else:
                    assert display_on == 0, f"display at {j},{i} should be off"
            
            vsync = dut.user_project.hvsync_gen.vsync.value.integer
            if (i >= 490 and i < 492):
                assert vsync == 1, f"vsync not enabled on y={i}"
            else:
                assert vsync == 0, f"vsync not disabled on y={i}"
            
            pix_y = dut.user_project.hvsync_gen.vpos.value.integer
            assert pix_y == i, f"value from module {pix_y} and expected value {i} are not equal"

