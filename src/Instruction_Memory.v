`default_nettype none
module Instruction_Memory (
    input wire CLK,           // Clock for synchronous writes
    input wire WE,            // Write enable for UART programming
    input wire [31:0] A,      // PC from core or UART address
    input wire [31:0] WD,     // Write data from UART
    output wire [31:0] RD     // Instruction output
);
    // Memory array (256 words, 32-bit)
    reg [31:0] memory [0:19];

    // Initial load for simulation and Tiny Tapeout submission
    initial begin
        for (integer i = 0; i < 20; i = i + 1)
            memory[i] = 32'b0;
        $readmemh("../src/instruction.mem", memory); // Loads your program from instruction.mem
    end

    // Synchronous write for UART programming
    always @(posedge CLK) begin
        if (WE && A[31:2] < 20) begin
            memory[A[31:2]] <= WD;
            //$display("IMEM Write: addr=%h, data=%h @%0t", A, WD, $time);
        end
    end

    // Asynchronous read
    assign RD = (A[31:2] < 20) ? memory[A[31:2]] : 32'h00000013; // NOP if invalid

    // // Simulation
    // initial begin
    //     $display("Loading instruction.mem:");
    //     for (integer i = 0; i < 7; i++) 
    //        //$display("mem[%0d] = %h", i, memory[i]);
    // end
endmodule