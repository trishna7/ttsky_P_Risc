`default_nettype none
module Instruction_Memory (
    input wire CLK,           // Clock for synchronous writes
    input wire WE,            // Write enable for UART programming
    input wire [31:0] A,      // PC from core or UART address
    input wire [31:0] WD,     // Write data from UART
    output wire [31:0] RD     // Instruction output
);
    // Memory array (256 words, 32-bit)
    reg [31:0] memory [0:14];

    initial begin
    // Simple GPIO blink program
    memory[0] = 32'h00100093; // addi x1, x0, 1      # Load 1
    memory[1] = 32'h80000337; // lui x6, 0x80000     # GPIO base
    memory[2] = 32'h00132023; // sw x1, 0(x6)        # Write to GPIO
    memory[3] = 32'h00000013; // nop                 # Wait
    memory[4] = 32'h00000013; // nop                 # Wait  
    memory[5] = 32'h00000093; // addi x1, x0, 0      # Load 0
    memory[6] = 32'h00132023; // sw x1, 0(x6)        # Write to GPIO
    memory[7] = 32'hff9ff06f; // jal x0, -8          # Jump back
end

    // Synchronous write for UART programming
    always @(posedge CLK) begin
        if (WE && A[31:2] < 14) begin
            memory[A[31:2]] <= WD;
            //$display("IMEM Write: addr=%h, data=%h @%0t", A, WD, $time);
        end
    end

    // Asynchronous read
    assign RD = (A[31:2] < 14) ? memory[A[31:2]] : 32'h00000013; // NOP if invalid

    // // Simulation
    // initial begin
    //     $display("Loading instruction.mem:");
    //     for (integer i = 0; i < 7; i++) 
    //        //$display("mem[%0d] = %h", i, memory[i]);
    // end
endmodule