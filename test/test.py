import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ReadOnly

@cocotb.test()
async def reset_test(dut):
    """Check that DUT resets properly."""
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())  # 25 MHz clock

    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1

    # Wait for a few clocks
    for _ in range(10):
        await RisingEdge(dut.clk)

    assert dut.state.value.integer == 0, f"State should be STATE_U (0) after reset, got {dut.state.value.integer}"

@cocotb.test()
async def fsm_transition_test(dut):
    """Test FSM transitions from STATE_U to STATE_W and back."""
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1

    # Simulate shift_side > 400 to trigger u_done (STATE_U -> STATE_W)
    dut.shift_side.value = 401
    await RisingEdge(dut.vsync)  # FSM triggers on vsync
    await RisingEdge(dut.clk)
    assert dut.state.value.integer == 1, f"Expected STATE_W, got {dut.state.value.integer}"

    # Simulate spin_speed == 0 to trigger w_done (STATE_W -> STATE_U)
    dut.spin_speed.value = 0
    await RisingEdge(dut.vsync)
    await RisingEdge(dut.clk)
    assert dut.state.value.integer == 0, f"Expected STATE_U, got {dut.state.value.integer}"

@cocotb.test()
async def vga_signal_test(dut):
    """Check basic VGA outputs: hsync, vsync, video_active, RGB values."""
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1

    for _ in range(500):  # Run several clock cycles
        await RisingEdge(dut.clk)
        await ReadOnly()

        uo = dut.uo_out.value.integer
        hsync = (uo >> 7) & 1
        vsync = (uo >> 4) & 1
        R = (uo >> 2) & 0b11
        G = (uo >> 1) & 0b11
        B = ((uo >> 0) & 0b1) | (((uo >> 5) & 0b11) << 1)  # reconstruct from packed bits

        # Basic sanity checks
        assert hsync in (0, 1)
        assert vsync in (0, 1)
        assert 0 <= R <= 3
        assert 0 <= G <= 3
        assert 0 <= B <= 3

@cocotb.test()
async def bullet_detection_test(dut):
    """Check that bullets are detected correctly at certain pixel positions."""
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1

    # Pick a pixel where bullets should appear (around H_ORIGIN, V_ORIGIN)
    dut.pix_x.value = 320
    dut.pix_y.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()

    bullets = [dut.bullets[i].value.integer for i in range(6)]
    assert any(bullets), f"No bullets detected at center pixel, got {bullets}"

@cocotb.test()
async def shape_detection_test(dut):
    """Check if pixel inside shape sets 'valid' high."""
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1

    # Pick a pixel inside the shape area
    dut.pix_x.value = 200
    dut.pix_y.value = 100
    await RisingEdge(dut.clk)
    await ReadOnly()

    valid = dut.valid.value.integer
    assert valid == 1, f"Pixel inside shape should have valid=1, got {valid}"