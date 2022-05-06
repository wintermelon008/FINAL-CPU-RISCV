`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/04/06 14:21:41
// Design Name: 
// Module Name: Control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/*
    ================================  Control module   ================================
    Author:         Wintermelon
    Last Edit:      2022.4.20

    This is the control unit for our cpu
    decides all the control signals
*/


module Control#(
    parameter SIGNUM = 35
)
(
    input [31:0] instruction,
    output wire [SIGNUM-1:0] control_signals    // The number of ctrl sigs is unsure yet
);

reg [2:0] rs2_mux_sel_ctrl, rs1_mux_sel_ctrl;
reg [2:0] rf_wb_mux_sel;
reg rf_sr1_mux_sel, rf_sr2_mux_sel;
reg rfi_we, rff_we, dm_we, dm_rd;
reg [3:0] jump_ctrl;
reg [2:0] mul_mode;
reg [4:0] alu_mode;

// Below is the instruction opcode list ================================================================================================

    localparam ArithmeticR = 7'b0110011;        // RISCV 32IBM - Register
    localparam ArithmeticI = 7'b0010011;        // RISCV 32IBM - Immediate
    localparam ControlStatus = 7'b1110011;      // RISCV 32I - CSR
    localparam Conditionjump = 7'b1100011;      // RISCV 32I - Branch-type
    localparam MemoryLoad = 7'b0000011;         // RISCV 32I - Immediate(MEM)
    localparam MemoryStore = 7'b0100011;        // RISCV 32I - Store-type
    localparam JumpandlinkR = 7'b1100111;       // RISCV 32I - Jump-type(R)
    localparam JumpandlinkI = 7'b1101111;       // RISCV 32I - Jump-type(I)
    localparam Adduppertopc = 7'b0010111;       // RISCV 32I - Upper-type
    localparam Loadupperimm = 7'b0110111;       // RISCV 32I - Upper-type

    localparam FloatArithmetic = 7'b1010011;    // RISCV 32F - Arithmetic
    localparam FloatMemoryLoad = 7'b0000111;    // RISCV 32F - Immediate(MEM)
    localparam FloatMemoryStore = 7'b0100111;   // RISCV 32F - Store-type
    localparam FloatMulAdd = 7'b1000011;        // RISCV 32F - R4-type
    localparam FloatMulSub = 7'b1000111;        // RISCV 32F - R4-type
    localparam FloatMulNegAdd = 7'b1001111;     // RISCV 32F - R4-type
    localparam FloatMulNegSub = 7'b1001011;     // RISCV 32F - R4-type

/*                                              Below is the CCU working mode table 
    ========================================================================================================================
*/
    // Integer Arithmetic Logic Unit (Except MUL & DIV)
    // Code begin with 8'h0 ~ 8'h2

    // RISCV 32I
    localparam SUB = 8'h00;
    localparam ADD = 8'h01;
    localparam AND = 8'h02;
    localparam OR = 8'h03;
    localparam XOR = 8'h04;
    localparam RMV = 8'h05;      // Right shift (logic)
    localparam LMV = 8'h06;      // Left shift  (logic)
    localparam ARMV = 8'h07;     // Right shift (arithmetic)
    localparam SLTS = 8'h08;      // Sign less then set bit
    localparam SLTUS = 8'h09;     // Unsign less then set bit

    // RISCV 32B
    localparam ANDN = 8'h10;     // Not then and
    localparam MAX = 8'h11;      
    localparam MAXU = 8'h12;
    localparam MIN = 8'h13;
    localparam MINU = 8'h14;
    localparam ORN = 8'h15;      // Not then or
    localparam SH1ADD = 8'h16;
    localparam SH2ADD = 8'h17;
    localparam SH3ADD = 8'h18;
    localparam XNOR = 8'h19;

    // Integer Bit Calculate Unit
    // Code begin with 8'h3

    // RISCV 32B ALU
    localparam BCLR = 8'h30;     // Clear single bit
    localparam BEXT = 8'h31;     // Get single bit
    localparam BINV = 8'h32;     // Not single bit
    localparam BSET = 8'h33;     // Set single bit
    localparam CLZ = 8'h34;      // Leading zeros count
    localparam CPOP = 8'h35;     // Set bits count     
    localparam CTZ = 8'h36;      // Suffix zeros count
    localparam ROL = 8'h37;      // High bits reverse
    localparam ROR = 8'h38;      // Low bits reverse

    // Integer Arithmetic Unit For MUL & DIV
    // Code begin with 8'h4

    // RISCV 32M ALU
    localparam MUL = 8'h40;      // Multiply
    localparam MULH = 8'h41;     // High bit multiply
    localparam MULHSU = 8'h42;   // High bit sign - unsign multiply
    localparam MULHU = 8'h43;    // High bit unsign multiply
    localparam DIV = 8'h44;      // Divide
    localparam DIVU = 8'h45;     // Unsigned Divide
    localparam REM = 8'h46;      // Remind number
    localparam REMU = 8'h47;     // Unsigned remide number


// Below is the Branch control list ================================================================================================

    localparam NPC = 4'h0;
    localparam OFFPC = 4'h1;
    localparam NEQ = 4'h2;
    localparam EQ = 4'h3;
    localparam SLT = 4'h4;  // sign less than
    localparam ULT = 4'h5;  // unsign less than
    localparam SGT = 4'h6;  // sign greater than
    localparam UGT = 4'h7;  // unsign greater than
    localparam JALR = 4'h8; 
    
/*===================================== Control Unit signals table =====================================
    control_signals - 35 bit
    
    MUX Ctrl signal:
        control_signals[2:0] - alu-sr1mux (3)
        control_signals[5:3] - alu-sr2mux (3)
        control_signals[8:6] - rfmux (3)
        control_signals[9] - rf-sr1mux (1)
        control_signals[10] - rf-sr2mux (1)

    ALU mode signal:
        control_signals[19:14] - alumode (6)
        control_signals[22:20] - mulmode (3)   // Multiplier & Devider

    Regfile writing enable:
        control_signals[24] - rfi_we (1)
        control_signals[25] - rff_we (1)

    Data memory unit reading and writing enable:
        control_signals[27] - dm_we (1)
        control_signals[28] - dm_rd (1)

    B & J control signal:
        control_signals[33:30] - jump_ctrl (4)
*/ //===================================================================================================
// Below is the control signals connection
assign control_signals[2:0] = rs1_mux_sel_ctrl;
assign control_signals[5:3] = rs2_mux_sel_ctrl;
assign control_signals[8:6] = rf_wb_mux_sel;
assign control_signals[9] = rf_sr1_mux_sel;
assign control_signals[10] = rf_sr2_mux_sel;

assign control_signals[19:14] = alu_mode;
assign control_signals[22:20] = mul_mode;

assign control_signals[24] = rfi_we;
assign control_signals[25] = rff_we;

assign control_signals[27] = dm_we;
assign control_signals[28] = dm_rd;

assign control_signals[33:30] = jump_ctrl;




// READ ME!
// the control signals havent edited yet


always @(instruction) begin
       
        case (instruction[6:0])     // Check the opcode
            
            ArithmeticR: begin      // The arithmetic instructions (Reg)
                
                case (instruction[31:25])  // Check the func7
                    7'b0000000: begin
                        case (instruction[14:12])   //Check the func3
                            3'b000: begin   // add
                                alu_mode = ADD;
                            end

                            3'b001: begin   // sll
                                alu_mode = LMV;
                            end

                            3'b010: begin   // slt
                                alu_mode = SLTS;
                            end

                            3'b011: begin   // sltu
                                alu_mode = SLTUS; 
                            end

                            3'b100: begin   // xor
                                alu_mode = XOR;
                            end

                            3'b101: begin   // srl
                                alu_mode = RMV;
                            end

                            3'b110: begin   // or
                                alu_mode = OR;
                            end

                            3'b111: begin   // and
                                alu_mode = AND;
                            end

                            default: begin  // the same as add
                                alu_mode = ADD;
                            end
                        endcase
                    end

                    7'b0100000: begin
                        case (instruction[14:12])   // Check the func3
                            3'b000: begin   // sub
                                alu_mode = SUB;
                            end

                            3'b101: begin   // sra
                                alu_mode = ARMV;
                            end

                            default: begin  // the same as add
                                alu_mode = ADD;
                            end
                        endcase
                    end

                    default: begin  
                        alu_mode = ADD;
                    end
                endcase

                rs1_mux_sel_ctrl = 3'b000;
                rs2_mux_sel_ctrl = 3'b000;
                rf_wb_mux_sel = 3'b000;
                rfi_we = 1'b1;
                dm_we = 1'b0;
                dm_rd = 1'b0;
                jump_ctrl = NPC;

            end

            ArithmeticI: begin
                case (instruction[14:12]) // Check func3

                    3'b000: begin   // addi
                        alu_mode = ADD;
                    end

                    3'b001: begin   // slli
                        alu_mode = LMV;
                    end

                    3'b010: begin
                        alu_mode = SLTS;
                    end

                    3'b011: begin
                        alu_mode = SLTUS;
                    end

                    3'b100: begin   // xori
                        alu_mode = XOR;
                    end 

                    3'b101: begin   // srli and srai
                        if (instruction[31:26] == 6'b000000) begin  //srli
                            alu_mode = RMV;
                        end

                        else begin  // srai
                            alu_mode = ARMV;
                        end
                    end

                    3'b110: begin   // ori
                        alu_mode = OR;
                    end

                    3'b111: begin   // andi
                        alu_mode = AND;
                    end

                    default: begin  // the same as addi
                        alu_mode = ADD;
                    end

                endcase

                rs1_mux_sel_ctrl = 3'b000;
                rs2_mux_sel_ctrl = 3'b001;
                rf_wb_mux_sel = 3'b000;
                rfi_we = 1'b1;
                dm_we = 1'b0;
                dm_rd = 1'b0;
                jump_ctrl = NPC;

            end

            Conditionjump: begin

                alu_mode = SUB;

                case (instruction[14:12]) 

                    3'b000: begin   // beq
                        jump_ctrl = EQ;
                    end

                    3'b001: begin   // bne
                        jump_ctrl = NEQ;
                    end

                    3'b100: begin   // blt
                        jump_ctrl = SLT;
                    end

                    3'b101: begin   // bge
                        jump_ctrl = SGT;
                    end

                    3'b110: begin   // bltu
                        jump_ctrl = ULT;
                    end

                    3'b111: begin   // bgeu
                        jump_ctrl = UGT;
                    end


                    default: begin  // the same as beq
                        jump_ctrl = EQ;
                    end
                endcase

                rs1_mux_sel_ctrl = 3'b000;
                rs2_mux_sel_ctrl = 3'b000;
                rf_wb_mux_sel = 3'b000;
                rfi_we = 1'b0;
                dm_rd = 1'b0;
                dm_we = 1'b0;

            end

            MemoryLoad: begin   // lw
                rs1_mux_sel_ctrl = 3'b000;
                rs2_mux_sel_ctrl = 2'b001;
                rf_wb_mux_sel = 3'b010;
                rfi_we = 1'b1;
                dm_we = 1'b0;
                dm_rd = 1'b1;
                jump_ctrl = NPC;
                alu_mode = ADD;
            end

            MemoryStore: begin  // sw
                rs1_mux_sel_ctrl = 3'b000;
                rs2_mux_sel_ctrl = 3'b001;
                rf_wb_mux_sel = 3'b000;
                rfi_we = 1'b0;
                dm_we = 1'b1;
                dm_rd = 1'b0;
                jump_ctrl = NPC;
                alu_mode = ADD;
            end

            JumpandlinkI: begin  // jal
                rs1_mux_sel_ctrl = 3'b000;
                rs2_mux_sel_ctrl = 3'b000;
                rf_wb_mux_sel = 3'b001;
                rfi_we = 1'b1;
                dm_we = 1'b0;
                dm_rd = 1'b0;
                jump_ctrl = OFFPC;
                alu_mode = ADD;
            end

            JumpandlinkR: begin  // jalr
                rs1_mux_sel_ctrl = 3'b000;
                rs2_mux_sel_ctrl = 3'b001;
                rf_wb_mux_sel = 3'b001;
                rfi_we = 1'b1;
                dm_we = 1'b0;
                dm_rd = 1'b0;
                jump_ctrl = JALR;
                alu_mode = ADD;
            end

            Adduppertopc: begin  // auipc
                rs1_mux_sel_ctrl = 3'b001;
                rs2_mux_sel_ctrl = 3'b001;
                rf_wb_mux_sel = 3'b000;
                rfi_we = 1'b1;
                dm_we = 1'b0;
                dm_rd = 1'b0;
                jump_ctrl = NPC;
                alu_mode = ADD;
            end

            Loadupperimm: begin  // lui     
                rs1_mux_sel_ctrl = 3'b010;
                rs2_mux_sel_ctrl = 3'b001;
                rf_wb_mux_sel = 3'b000;
                rfi_we = 1'b1;
                dm_we = 1'b0;
                dm_rd = 1'b0;
                jump_ctrl = NPC;
                alu_mode = ADD;
            end

            7'b0000000: begin   //not an is
                rs1_mux_sel_ctrl = 3'b000;
                rs2_mux_sel_ctrl = 3'b000;
                rf_wb_mux_sel = 3'b000;     // always zero
                rfi_we = 1'b0;
                dm_we = 1'b0;
                dm_rd = 1'b0;
                jump_ctrl = NPC;
                alu_mode = ADD;
            end

            default: begin  // all the signals are zero
                rs1_mux_sel_ctrl = 2'b00;
                rs2_mux_sel_ctrl = 2'b00;
                rf_wb_mux_sel = 3'b000;
                rfi_we = 1'b0;
                dm_we = 1'b0;
                dm_rd = 1'b0;
                jump_ctrl = NPC;
                alu_mode = ADD;
            end

        endcase
    end



endmodule
