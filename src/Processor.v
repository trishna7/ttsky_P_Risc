`default_nettype none
module Processor (
   input CLK,
    input reset,
    input RX,                // UART receive line
    output TX,               // UART transmit line
    output gpio_out
);

    //Hazard Unit
    wire StallF, StallD, FlushD, FlushE;
    wire [1:0] ForwardAE, ForwardBE;
    //Control unit and ALU decode
    wire RegWriteD, RegWriteE, RegWriteM, RegWriteW;
    wire MemWriteD, MemWriteE;
    wire JumpD, JumpE;
    wire BranchD, BranchE;
    wire ALUSrcD, ALUSrcE;
    wire JalSrcD, JalSrcE;
    wire USrcD, USrcE;
    wire UOControlD, UOControlE;
    wire [1:0] ResultSrcD, ResultSrcE, ResultSrcM, ResultSrcW, ALUOp;
    wire [2:0] ImmSrcD;
    wire [3:0] ALUControlD, ALUControlE;
   
    wire PCSrcE;
    wire [31:0] PCFI, PCF, PCD, PCE, PCPlus4F, PCPlus4D, PCPlus4E, PCPlus4M, PCPlus4W;
    wire [31:0] Instr, InstrD;
    wire ZeroE;

    wire [31:0] RD1D, RD1E, RD2D, RD2E;
    wire [4:0] Rs1E, Rs2E, RdE, RdM, RdW;
    wire [31:0] ImmExtD, ImmExtE;
    wire [31:0] ALUResultE, ALUResultW;
    wire [31:0] ReadDataM, ReadDataW;
    wire [31:0] UOutM, UOutW;

    wire [31:0] ALUResultM; 
    wire MemWriteM;
    wire [31:0] WriteDataM;

    reg [31:0] SrcAE, SrcBE;
    reg [31:0] PCTargetE, UOutE, WriteDataE;
    
    reg [31:0] ResultW;

    wire gpio_WE;
    wire [31:0] gpio_RD;
    wire [31:0] uart_RD;
    wire uart_WE;
    wire imem_WE;
    wire [31:0] imem_A, imem_WD;
    wire cpu_stall;

// Instantiate GPIO module
GPIO gpio_module (
    .CLK(CLK),
    .reset(reset),
    .WE(gpio_WE),
    .A(ALUResultM),
    .WD(WriteDataM),
    .RD(gpio_RD),
    .gpio_pin(gpio_out)
);

// Instantiate UART module
    UART uart_module (
        .CLK(CLK),
        .reset(reset),
        .RX(RX),
        .TX(TX),
        .A(ALUResultM),
        .WD(WriteDataM),
        .WE(uart_WE),
        .RD(uart_RD),
        .imem_WE(imem_WE),
        .imem_A(imem_A),
        .imem_WD(imem_WD),
        .cpu_stall(cpu_stall)
    );

    // Memory-mapped I/O select
    assign gpio_WE = MemWriteM && (ALUResultM == 32'h80000000);
    assign uart_WE = MemWriteM && (ALUResultM[31:2] == 32'h8000000 && ALUResultM != 32'h80000000);

//Program Counter
    PC pc_module (  
        .CLK(CLK),
        .reset(reset),
        .EN(~StallF),
        .PCFI(PCFI),
        .PCF(PCF),
        .PCTargetE(PCTargetE),
        .PCPlus4F(PCPlus4F),
        .PCSrcE(PCSrcE)
    );

    assign PCPlus4F = PCF + 4;

//Instruction Memory
    
   // Instruction Memory
    Instruction_Memory im_module (
        .CLK(CLK),
        .WE(imem_WE),
        .A(imem_WE ? imem_A : PCF),
        .WD(imem_WD),
        .RD(Instr)
    );


// Decode register
    Decode_Reg decode_module(
        .CLR(FlushD),
        .CLK(CLK),            
        .EN(~StallD & ~cpu_stall),    // Stall if UART is programming
        .Instr(Instr),
        .PCF(PCF),
        .PCPlus4F(PCPlus4F),
        .InstrD(InstrD),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D)

);

//Hazard Unit
    Hazard_Unit Hazard_module(
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .RdM(RdM),
        .RdW(RdW),
        .Rs1D(InstrD[19:15]),
        .Rs2D(InstrD[24:20]),
        .PCSrcE(PCSrcE),
        .ResultSrcE(ResultSrcE),
        .RegWriteM(RegWriteM),
        .RegWriteW(RegWriteW),
        .StallF(StallF),
        .StallD(StallD),
        .FlushD(FlushD),
        .FlushE(FlushE),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE)

    );

          //Control unit
    
    Control_unit CU_module( 
        .opcode(InstrD[6:0]),
        .Des_Reg(InstrD[11:7]),
        .RegWriteD(RegWriteD),
        .ImmSrcD(ImmSrcD),
        .ALUSrcD(ALUSrcD),
        .ResultSrcD(ResultSrcD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ALUOp(ALUOp),
        .JalSrcD(JalSrcD),
        .USrcD(USrcD),
        .UOControlD(UOControlD)
    );

//ALU Decoder
    ALU_Decoder ALUDecode_module(
        .opcode_bit5(InstrD[4]),
        .funct3(InstrD[14:12]),
        .funct7_bit5(InstrD[29]),
        .ALUOp(ALUOp),
        .ALUControlD(ALUControlD)

    );
    
    //immediate extension
    
    immediate immediate_module ( // checked
        .InstrD(InstrD[31:7]),
        .ImmSrcD(ImmSrcD),
        .ImmExtD(ImmExtD)
    );

    // Registers
    
    Registers register_module (     //checked
        .CLK(CLK),
        .A1(InstrD[19:15]),
        .A2(InstrD[24:20]),
        .A3(RdW),
        .WE3(RegWriteW),
        .WD3(ResultW),
        .RD1(RD1D),
        .RD2(RD2D)
    );

    //Execute 
   Execute_Reg execute_module(
        .CLK(CLK),
        .CLR(FlushE),
        .ZeroE(ZeroE),
        .RegWriteD(RegWriteD),
        .ALUSrcD(ALUSrcD),
        .ResultSrcD(ResultSrcD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ALUControlD(ALUControlD),
        .RD1D(RD1D),
        .RD2D(RD2D),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D),
        .Rs1D(InstrD[19:15]),
        .Rs2D(InstrD[24:20]),
        .RdD(InstrD[11:7]),
        .ImmExtD(ImmExtD),
        .JalSrcD(JalSrcD),
        .USrcD(USrcD),
        .UOControlD(UOControlD),

        .RegWriteE(RegWriteE),
        .ALUSrcE(ALUSrcE),
        .ResultSrcE(ResultSrcE),
        .MemWriteE(MemWriteE),
        .JumpE(JumpE),
        .BranchE(BranchE),
        
        .ALUControlE(ALUControlE),
        .RD1E(RD1E),
        .RD2E(RD2E),
        .PCE(PCE),
        .PCPlus4E(PCPlus4E),
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .ImmExtE(ImmExtE),
        .JalSrcE(JalSrcE),
        .USrcE(USrcE),
        .UOControlE(UOControlE)
   );

   assign PCSrcE = ((ZeroE && BranchE) || JumpE);
   
   reg [31:0] Imm, Add1, Add2;

   always @(*) begin 
        case (ForwardAE)
        2'b00 : SrcAE = RD1E;
        2'b01 : SrcAE = ResultW;
        2'b10 : SrcAE = ALUResultM;
        endcase

        case (ForwardBE)
        2'b00 : WriteDataE = RD2E;
        2'b01 : WriteDataE = ResultW;
        2'b10 : WriteDataE = ALUResultM;
        endcase
        
        SrcBE = (ALUSrcE == 1) ? ImmExtE : WriteDataE;
        Add1 = (JalSrcE == 1) ? RD1E : PCE;
        Add2 = (USrcE == 1) ? (ImmExtE) : ImmExtE;

        PCTargetE = Add1 + Add2;
        //PCTargetE = (BranchE | MemWriteE) ? (RD1E + ImmExtE) : (Add1 + Add2);

        UOutE = (UOControlE == 1) ? (ImmExtE) : PCTargetE;
   end
// always @(posedge CLK) begin
//     if (InstrD == 32'h00132023 ) begin
//         $display("Store RegWrite Trace: D=%b E=%b M=%b W=%b, RdD=%d RdE=%d RdM=%d RdW=%d", 
//                  RegWriteD, RegWriteE, RegWriteM, RegWriteW,
//                  InstrD[11:7], RdE, RdM, RdW);
//     end
// end
    //ALU
    
    ALU ALU_module(   
        .SrcAE(SrcAE),
        .SrcBE(SrcBE),
        .ALUControlE(ALUControlE),
        .ALUResultE(ALUResultE),
        .ZeroE(ZeroE)
    );

// Memory 
    Mem_Reg Mem_module (
        .CLK(CLK),
        .RegWriteE(RegWriteE),
        .ResultSrcE(ResultSrcE),
        .MemWriteE(MemWriteE),
        .PCPlus4E(PCPlus4E),
        .RdE(RdE),
        .UOutE(UOutE),
        .WriteDataE(WriteDataE),
        .ALUResultE(ALUResultE),
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .MemWriteM(MemWriteM),
        .WriteDataM(WriteDataM),
        .ALUResultM(ALUResultM),
        .PCPlus4M(PCPlus4M),
        .RdM(RdM),
        .UOutM(UOutM)

    );

// Data Memory
    Data_Memory data_module (    
        .CLK(CLK),
        .WE(MemWriteM && !uart_WE), // Only write if not UART access
        .A(ALUResultM),      
        .WD(WriteDataM),
        .RD(ReadDataM)
    );

// Write back register
    Writeback_Reg Writeback_module (
        .CLK(CLK),
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .PCPlus4M(PCPlus4M),
        .RdM(RdM),
        .UOutM(UOutM),
        .ReadDataM(ReadDataM),
        .ALUResultM(ALUResultM),
        .RegWriteW(RegWriteW),
        .ResultSrcW(ResultSrcW),
        .ReadDataW(ReadDataW),
        .ALUResultW(ALUResultW),
        .PCPlus4W(PCPlus4W),
        .RdW(RdW),
        .UOutW(UOutW)

    );


    // selecting data to write
    always @(*) begin
        case (ResultSrcW)
            2'b00 : ResultW = ALUResultW;
            2'b01 : ResultW = (ALUResultW[31:2] == 32'h8000000) ? uart_RD : 
                             (ALUResultW == 32'h80000000) ? gpio_RD : ReadDataW;
            2'b10 : ResultW = PCPlus4W;
            2'b11 : ResultW = UOutW;
        endcase
    end

    // always @(posedge CLK) begin
    //     if (RegWriteW && RdW == 1) begin
    //         $display("x1 Write Debug: ResultSrcW=%b, ALUResultM=%h, ALUResultW=%h, ReadDataW=%h, ResultW=%h", 
    //                  ResultSrcW, ALUResultM, ALUResultW, ReadDataW, ResultW);
    //     end
    // end

endmodule

