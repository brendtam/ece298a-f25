from machine import Pin, PWM
import time

clk_pin = 2
rst_n_pin = 3
speed_pin = 4

# Create 25 MHz clock output
clk_pwm = PWM(Pin(clk_pin))
clk_pwm.freq(25_000_000)      # 25 MHz
clk_pwm.duty_u16(32768)       # 50% duty cycle (0-65535)

# Reset pin
rst_n = Pin(rst_n_pin, Pin.OUT)
rst_n.value(1)      # set to 1 since active low

# Quick reset to set chip default values
def reset_chip(duration_ms=10):
    rst_n.value(0)
    time.sleep_ms(duration_ms)
    rst_n.value(1)

reset_chip()

# Speed control
# value 0 = ramping spin speed, value 1 = constant spin speed
speed_control = Pin(speed_pin, Pin.OUT)
speed_control.value(0)
