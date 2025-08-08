`default_nettype none

module Data_Memory (
    input CLK,
    input WE,
    input [31:0] A,    // Byte address
    input [31:0] WD,
    output [31:0] RD
);
    reg [31:0] mem [0:10];  // Word-addressable memory
    
    // Check for word alignment (lower 2 bits must be 00)
    wire address_ok = (A[1:0] == 2'b00);
    
    always @(posedge CLK) begin
        if (WE && address_ok) 
            mem[A[31:2]] <= WD;  // Word write
    end

    assign RD = address_ok ? mem[A[31:2]] : 32'h0;  // Word read
endmodule