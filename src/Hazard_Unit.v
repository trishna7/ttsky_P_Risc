`default_nettype none

module Hazard_Unit(
//source and destination regs execute stage
    input  [4:0] Rs1E,
    input  [4:0] Rs2E,
    input  [4:0] RdE,
    input  [4:0] RdM,
    input  [4:0] RdW,


//source and destination regs decode stage
    input  [4:0] Rs1D,
    input  [4:0] Rs2D,

    input PCSrcE,
    input [1:0] ResultSrcE,
    input RegWriteM,
    input RegWriteW,

//Outputs
output reg StallF,
output reg StallD,
output reg FlushD,
output reg FlushE,
output reg [1:0] ForwardAE,
output reg [1:0] ForwardBE

);

reg lwStall;
//reg store_hazard;
initial begin
// Rs1E= 4'b0000;
//     Rs2E= 4'b0000;
//     RdE= 4'b0000;
//     RdM= 4'b0000;
//     RdW= 4'b0000;
//     Rs1D = 4'b0000;
//     Rs2D= 4'b0000;
//     PCSrcE= 0;
//     ResultSrcE= 0;
//     RegWriteM = 0;
//     RegWriteW = 0;
    StallF = 0;
    StallD = 0;
    FlushD = 0;
    FlushE = 0;
    ForwardAE = 2'b00;
    ForwardBE = 2'b00;
end

always @(*) begin
    // Detect when SW is writing to a register being read by next instruction
    //store_hazard = (ResultSrcE == 2'b00) && ((Rs1D == RdE) || (Rs2D == RdE));

    lwStall =  ((ResultSrcE == 2'b01) && ((Rs1D == RdE) || (Rs2D == RdE)));

    StallF = lwStall; //|| store_hazard;
    StallD = lwStall; //|| store_hazard;
    FlushD = PCSrcE;
    FlushE = lwStall || PCSrcE; //|| store_hazard 

//ForwardAE
    if (((Rs1E == RdM) && RegWriteM) && (Rs1E != 0))
        ForwardAE = 2'b10;
    else if (((Rs1E == RdW) && RegWriteW) && (Rs1E != 0))
        ForwardAE = 2'b01;
    else
        ForwardAE = 2'b00;

//ForwardBE    
    if (((Rs2E == RdM) && RegWriteM) && (Rs2E != 0))
        ForwardBE = 2'b10;
    else if (((Rs2E == RdW) && RegWriteW) && (Rs2E != 0))
        ForwardBE = 2'b01;
    else
        ForwardBE = 2'b00;

end

endmodule