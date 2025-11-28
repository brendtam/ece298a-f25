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

@cocotb.test()
async def w_rotate_test(dut):
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1
    dut.user_project.state.value = 1

    for frame in range(0, 16):
        dut._log.info(f"testing frame {frame}")
        for i in range(0, 525):
            for j in range(0, 800):
                await RisingEdge(dut.clk)
                await ReadOnly()

                pix_x = dut.user_project.hvsync_gen.hpos.value.integer
                pix_y = dut.user_project.hvsync_gen.vpos.value.integer
                if (pix_x > 640 or pix_y > 480):
                    continue

                rotated_x = dut.user_project.curr_u.value.integer
                rotated_y = dut.user_project.curr_v.value.integer
                angle_idx = dut.user_project.angle_idx.value.integer
                
                rot_x = rotated_x / 32.0
                rot_y = rotated_y / 32.0
                exp_x = (pix_x-320) * math.cos(angle_idx*2*math.pi / 16.0)
                exp_y = (pix_y-240) * math.sin(angle_idx*2*math.pi / 16.0)
                assert within_2px(rot_x, exp_x), \
                    f"({pix_x}, {pix_y}) is not rotated correctly. x given: {rot_x}, x expected: {exp_x}"
                assert within_2px(rot_y, exp_y), \
                    f"({pix_x}, {pix_y}) is not rotated correctly. y given: {rot_y}, y expected: {exp_y}"

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

