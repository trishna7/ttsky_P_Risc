`default_nettype none

module tt_um_trish_P_Risc (
     input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
    
  wire reset;
  wire uart_rx, uart_tx;
  wire gpio_pin;
  
  
  // Reset logic - active low rst_n from TT, active high reset for processor
  assign reset = ~rst_n;  // External reset or manual reset
  
  // Input assignments
  assign uart_rx = ui_in[3];
  
  // Output assignments
  assign uo_out[4] = uart_tx;
  assign uo_out[5] = gpio_pin;
  assign uo_out[3:0] = 4'b0000;
  assign uo_out[7:6] = 2'b00;
   
   assign uio_oe = 8'h00;  // All bidirectional pins as outputs
   assign uio_out = 8'h00;
   //assign uio_in = 8'h00;
  
  // Instantiate the main processor
  Processor main_processor (
    .CLK(clk),
    .reset(reset),
    .RX(uart_rx),
    .TX(uart_tx),
    .gpio_out(gpio_pin)
  );
  

endmodule