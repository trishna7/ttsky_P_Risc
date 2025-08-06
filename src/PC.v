`default_nettype none
module PC (
    input wire CLK,                      // clock signal
    input reset,
    input wire EN,                    // EN signal 
    input PCSrcE,
    output wire [31:0] PCFI,             // next pc value (input oc value)
    input wire [31:0] PCTargetE,                // output of pc + imm or rs1 + imm
    input wire [31:0] PCPlus4F,           // Pc +4
    output reg [31:0] PCF        // Current PC value 

);

assign PCFI = PCSrcE ? PCTargetE : PCPlus4F;

always @(posedge CLK or posedge reset) begin
    if (reset)
        PCF <= 32'b0;            // pc to 0
    else if (EN)
        PCF <= PCFI;            // update PC if enabled

end

endmodule 
