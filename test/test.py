import cocotb
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

@cocotb.test()
async def vga_signal_test(dut):
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1

    for i in range(1, 525+1):
        for j in range(1, 800+1):
            await RisingEdge(dut.clk)
            await ReadOnly()

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
        if (i > 523 and i <= 525):
            assert vsync == 1, f"vsync not enabled on y={i}"
        else:
            assert vsync == 0, f"vsync not disabled on y={i}"
        
        pix_y = dut.user_project.hvsync_gen.vpos.value.integer
        assert pix_y == i, f"value from module {pix_y} and expected value {i} are not equal"
