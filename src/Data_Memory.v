`default_nettype none

module Data_Memory (
    input CLK,
    input WE,
    input [31:0] A,    // Byte address
    input [31:0] WD,
    output [31:0] RD
);
    // Increased memory size for better functionality
    reg [31:0] mem [0:63];  // 256 bytes of data memory (was only 44 bytes)
    
    // Check for word alignment (lower 2 bits must be 00)
    wire address_ok = (A[1:0] == 2'b00);
    
    // Bounds checking - ensure address is within valid range
    wire address_valid = address_ok && (A[31:2] < 64);
    
    // Initialize memory to zero
    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            mem[i] = 32'h0;
        end
    end
    
    always @(posedge CLK) begin
        if (WE && address_valid) 
            mem[A[31:2]] <= WD;  // Word write with bounds checking
    end

    // Safe read with bounds checking
    assign RD = address_valid ? mem[A[31:2]] : 32'h0;  // Return 0 for invalid addresses
    
endmodule