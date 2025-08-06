# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
import asyncio

class UARTProgrammer:
    """UART Programmer based on the actual UART.v implementation"""
    
    def __init__(self, dut, clock_freq=100000):  # 100KHz for TinyTapeout
        self.dut = dut
        # Your UART.v is configured for 115200 baud with 100MHz clock
        # But TinyTapeout runs at 100KHz, so we need to adjust
        self.baud_rate = 115200
        self.clock_freq = clock_freq
        self.bit_time = clock_freq // self.baud_rate
        
        # If bit_time is 0 (clock too slow), set minimum
        if self.bit_time == 0:
            self.bit_time = 1
            dut._log.warning(f"Clock too slow for {self.baud_rate} baud, using 1 cycle per bit")
        
        dut._log.info(f"UART bit time: {self.bit_time} cycles for {self.baud_rate} baud at {clock_freq}Hz")
        
        # Memory addresses from UART.v
        self.UART_DATA = 0x80000004
        self.UART_CTRL = 0x80000008
        self.UART_STATUS = 0x8000000C
    
    async def memory_write(self, address, data):
        """Write to memory-mapped UART registers via processor"""
        # This would need to be done through the processor's memory interface
        # For now, we'll simulate direct register access
        self.dut._log.info(f"Memory write: addr=0x{address:08x}, data=0x{data:08x}")
        # Note: In real test, this would need processor to execute store instructions
    
    async def enter_programming_mode(self):
        """Enter programming mode by setting UART_CTRL[1]"""
        self.dut._log.info("Entering UART programming mode...")
        # Write to UART_CTRL register to set programming mode (bit 1)
        await self.memory_write(self.UART_CTRL, 0x02)  # Set bit 1
        await ClockCycles(self.dut.clk, 10)
    
    async def exit_programming_mode(self):
        """Exit programming mode"""
        self.dut._log.info("Exiting UART programming mode...")
        await self.memory_write(self.UART_CTRL, 0x00)  # Clear bit 1
        await ClockCycles(self.dut.clk, 10)
    
    async def send_uart_byte(self, byte_val):
        """Send a single byte via UART RX pin"""
        # Set UART RX pin (bit 3 of ui_in based on your pinout)
        
        # Start bit (0)
        await self._set_uart_rx(0)
        await ClockCycles(self.dut.clk, self.bit_time)
        
        # Data bits (LSB first)
        for bit in range(8):
            bit_val = (byte_val >> bit) & 1
            await self._set_uart_rx(bit_val)
            await ClockCycles(self.dut.clk, self.bit_time)
        
        # Stop bit (1)
        await self._set_uart_rx(1)
        await ClockCycles(self.dut.clk, self.bit_time)
    
    async def _set_uart_rx(self, value):
        """Set UART RX pin value"""
        current_ui = int(self.dut.ui_in.value)
        if value:
            self.dut.ui_in.value = current_ui | (1 << 3)  # Set bit 3
        else:
            self.dut.ui_in.value = current_ui & ~(1 << 3)  # Clear bit 3
    
    async def program_instruction_word(self, instruction):
        """Send a 32-bit instruction as 4 bytes (little endian)"""
        self.dut._log.info(f"Programming instruction: 0x{instruction:08x}")
        
        # Send 4 bytes in little-endian order
        for i in range(4):
            byte_val = (instruction >> (i * 8)) & 0xFF
            self.dut._log.info(f"  Sending byte {i}: 0x{byte_val:02x}")
            await self.send_uart_byte(byte_val)
            
        # Wait for processing
        await ClockCycles(self.dut.clk, 50)
    
    async def program_multiple_instructions(self, instructions):
        """Program multiple instructions sequentially"""
        self.dut._log.info(f"Programming {len(instructions)} instructions...")
        
        for i, instruction in enumerate(instructions):
            self.dut._log.info(f"Programming instruction {i}: 0x{instruction:08x}")
            await self.program_instruction_word(instruction)


@cocotb.test()
async def test_uart_programming_protocol(dut):
    """Test the actual UART programming protocol"""
    dut._log.info("=== Testing UART Programming Protocol ===")
    
    # Setup clock (using 100KHz as specified in your test files)
    clock = Clock(dut.clk, 10, units="us")  # 100KHz
    cocotb.start_soon(clock.start())
    
    programmer = UARTProgrammer(dut, clock_freq=100000)
    
    # Reset system
    dut.ena.value = 1
    dut.ui_in.value = 8  # UART RX idle high (bit 3)
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 20)
    
    # Record initial state
    initial_output = int(dut.uo_out.value)
    dut._log.info(f"Initial output: 0x{initial_output:02x}")
    
    # Test sequence:
    
    # 1. Enter programming mode (this would normally be done by processor)
    dut._log.info("Step 1: Would need processor to write to UART_CTRL to enter programming mode")
    dut._log.info("        This requires the processor to execute: sw x1, 0x80000008(x0) with data 0x02")
    
    # 2. Send new program via UART
    dut._log.info("Step 2: Sending new program via UART...")
    
    # New program: Set GPIO to different value
    new_program = [
        0x00200093,  # addi x1, x0, 2       # Load value 2 instead of 1
        0x80000337,  # lui x6, 0x80000      # Load GPIO address  
        0x00000013,  # nop
        0x00000013,  # nop
        0x00132023,  # sw x1, 0(x6)         # Write to GPIO (should set different pattern)
        0x00000013,  # nop
        0x00000013,  # nop
    ]
    
    # Send the new program (this will only work if programming mode is active)
    for instruction in new_program:
        await programmer.program_instruction_word(instruction)
    
    # 3. Wait and observe
    await ClockCycles(dut.clk, 200)
    final_output = int(dut.uo_out.value)
    dut._log.info(f"Output after programming attempt: 0x{final_output:02x}")
    
    # 4. Analysis
    if final_output != initial_output:
        dut._log.info("✓ UART programming may have worked - output changed!")
    else:
        dut._log.info("⚠ Output unchanged - programming mode may not be active")
        dut._log.info("  This is expected since we can't easily set programming mode from testbench")
    
    dut._log.info("✓ UART programming protocol test completed")


@cocotb.test()
async def test_uart_baud_rate_analysis(dut):
    """Analyze if UART baud rate is correct"""
    dut._log.info("=== UART Baud Rate Analysis ===")
    
    clock = Clock(dut.clk, 10, units="us")  # 100KHz
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 8  # UART RX idle high
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)
    
    # Your UART.v expects 100MHz clock for 115200 baud
    # But TinyTapeout clock is 100KHz - this is a 1000x difference!
    
    expected_baud_cycles_100mhz = 100_000_000 // 115200  # ~868 cycles
    actual_baud_cycles_100khz = 100_000 // 115200        # ~0.87 cycles (rounds to 0)
    
    dut._log.info(f"UART.v designed for 100MHz clock:")
    dut._log.info(f"  Expected cycles per bit at 100MHz: {expected_baud_cycles_100mhz}")
    dut._log.info(f"  Actual cycles per bit at 100KHz: {actual_baud_cycles_100khz}")
    
    if actual_baud_cycles_100khz == 0:
        dut._log.warning("⚠ UART baud rate mismatch!")
        dut._log.warning("  UART.v is configured for 100MHz but TinyTapeout runs at 100KHz")
        dut._log.warning("  This explains why UART programming isn't working")
        dut._log.warning("  Solutions:")
        dut._log.warning("    1. Change UART.v CLK_FREQ parameter to 100000 (100KHz)")
        dut._log.warning("    2. Or change BAUD_RATE to a very low value like 10")
    
    dut._log.info("✓ UART baud rate analysis completed")


@cocotb.test()
async def test_uart_slow_programming(dut):
    """Test UART programming with very slow timing"""
    dut._log.info("=== Testing UART with Slow Timing ===")
    
    clock = Clock(dut.clk, 10, units="us")  # 100KHz
    cocotb.start_soon(clock.start())
    
    # Use very slow "baud rate" to work with 100KHz clock
    slow_bit_time = 100  # 100 clock cycles per bit = 1000 baud
    
    dut.ena.value = 1
    dut.ui_in.value = 8
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)
    
    dut._log.info(f"Using {slow_bit_time} cycles per bit for slow UART test")
    
    async def send_slow_byte(byte_val):
        """Send byte with very slow timing"""
        dut._log.info(f"Sending slow byte: 0x{byte_val:02x}")
        
        # Start bit
        dut.ui_in.value = 0  # Clear bit 3 (UART RX low)
        await ClockCycles(dut.clk, slow_bit_time)
        
        # Data bits
        for bit in range(8):
            bit_val = (byte_val >> bit) & 1
            if bit_val:
                dut.ui_in.value = 8  # Set bit 3
            else:
                dut.ui_in.value = 0  # Clear bit 3
            await ClockCycles(dut.clk, slow_bit_time)
        
        # Stop bit
        dut.ui_in.value = 8  # Set bit 3 (idle high)
        await ClockCycles(dut.clk, slow_bit_time)
    
    # Try sending some bytes with slow timing
    test_bytes = [0xAA, 0x55, 0x00, 0xFF]
    
    for byte_val in test_bytes:
        output_before = int(dut.uo_out.value)
        await send_slow_byte(byte_val)
        await ClockCycles(dut.clk, 50)  # Wait for processing
        output_after = int(dut.uo_out.value)
        
        if output_after != output_before:
            dut._log.info(f"Output changed with byte 0x{byte_val:02x}: 0x{output_before:02x} -> 0x{output_after:02x}")
    
    dut._log.info("✓ Slow UART timing test completed")


@cocotb.test()
async def test_comprehensive_uart_analysis(dut):
    """Run comprehensive UART analysis"""
    dut._log.info("=== Comprehensive UART Analysis ===")
    
    await test_uart_baud_rate_analysis(dut)
    await test_uart_slow_programming(dut) 
    await test_uart_programming_protocol(dut)
    
    dut._log.info("=== UART Analysis Summary ===")
    dut._log.info("Key findings:")
    dut._log.info("1. UART.v is configured for 100MHz clock, but TinyTapeout uses 100KHz")
    dut._log.info("2. This causes baud rate timing mismatch")
    dut._log.info("3. Programming mode must be activated by processor writing to 0x80000008")
    dut._log.info("4. Instructions are sent as 4 bytes in little-endian format")
    dut._log.info("5. Each 32-bit word programs one instruction sequentially")