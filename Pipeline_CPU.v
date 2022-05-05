`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/04/20 15:54:07
// Design Name: 
// Module Name: Pipeline_CPU
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
    ================================  Pipeline_CPU module   ================================
    Author:         Wintermelon
    Version:        1.0.8
    Last Edit:      2022.5.4

    This is the cpu topmodule for Pipeline

    Used sub-modules:
        * ALU
        * Instruction_MEM
        * Data_MEM
        * REG_FILE
        * Control
        * BranchCtrl
        * Signextend
        * Forwarding_Hazard
        * SR_MUX_CTRL
        * PC
        * REG
        * IF_ID_REG
        * ID_EX_REG
        * EX_MEM_REG
        * MEM_WB_REG
        * MUX2
        * MUX4
        * MUX8
        * DEBUG
*/

// ### Version 1.0.8 update ###
// Big changes to datapath

// ### Version 1.0.4 update ###
// Add multiplier for datapath
// Change the data width
// Change some pins

module Pipeline_CPU(
    // cpu control form PDU
    input clk, 
    input rstn,

    // IO_BUS
    output [15:0]  io_addr,	// I/O address
    output [31:0]  io_dout,	// I/O data output
    output  io_we,		    // I/O write enable
    output  io_rd,		    // I/O read enable
    input [31:0] io_din,	// I/O data input

    // Debug_BUS
    output [31:0] chk_pc, 	// Current pc
    input [15:0] chk_addr,	// Debug address
    output [31:0] chk_data  // Debug data

);

// Below is some consts =============================================================================================================
reg [31:0] zero;
reg one;

// Below is the wires and regs declaration ==========================================================================================

// Memorys
wire [11:0] im_din;
wire [31:0] im_dout;
wire [11:0] dm_addr;
wire [31:0] dm_din, dm_dout;
wire dm_wen, dm_rd;

// RF
wire [4:0] rfi_sr1_add, rfi_sr2_add, rfi_dr_add;
wire [4:0] rff_sr1_add, rff_sr2_add, rff_sr3_add, rff_dr_add;
wire [31:0] rfi_sr1_data, rfi_sr2_data, rfi_dr_data;
wire [31:0] rff_sr1_data, rff_sr2_data, rff_sr3_data, rff_dr_data;
wire rfi_wen, rff_wen;

// PC register
wire [31:0] pc_in, pc_out;
wire pc_wen;
wire [31:0] pc_offset, reg_offset;

// Iter-segment Registers
// ID part
wire [15:0] id_ctrl_ex;
wire [3:0] id_ctrl_mem;
wire [7:0] id_ctrl_wb;
wire [23:0] id_mux_sel;
wire [31:0] id_rf_de, id_is, id_pc, id_imm;
// EX part
wire [3:0] ex_ctrl_mem;
wire [7:0] ex_ctrl_wb;
wire [31:0] ex_is, ex_pc, ex_imm, ex_sr1, ex_sr2, ex_sr3, ex_dr;
wire [31:0] alu_ex, alu_mem, dm_mem, npc_mem;
// MEM part
wire [7:0] mem_ctrl_wb;
wire [31:0] mem_is, mem_pc, mem_alu_ans, mem_dm_data, mem_dm_addr, mem_dr;
// WB part
wire [31:0] wb_is, wb_pc, wb_alu_ans, wb_mdr, wb_csr, wb_dr;

// wire [1:0] ex_npc_mux_sel;
// wire ex_jalr_flag;

wire [18:0] sr_mux_dout;
wire [14:0] ctrl_ex_dout;
wire [3:0] ctrl_mem_dout;
wire [3:0] ctrl_wb_dout;

// CU
wire [34:0] control_signals;
wire [3:0] jump_ctrl;
wire [2:0] sr1_mux_sel_cu, sr2_mux_sel_cu;
wire [2:0] ex_sr1_mux_sel_cu, ex_sr2_mux_sel_cu;

// ALU
wire [31:0] alu_ans;
wire [4:0] alu_mode;
wire [2:0] mul_mode;
wire alu_error;
wire [2:0] alu_subflag;

// MUXs
// npc-mux & rf(WB)-mux
wire [1:0] npc_mux_sel;
wire [2:0] rf_mux_sel;
// b-sr-mux
wire [2:0] b_sr1_mux_sel, b_sr2_mux_sel;
wire [31:0] b_sr1_mux_out, b_sr2_mux_out;
// sr-mux
wire [2:0] sr1_mux_sel, sr2_mux_sel, sr3_mux_sel, dm_sr2_mux_sel;
wire [31:0] sr1_mux_out, sr2_mux_out, sr3_mux_out, dm_sr2_mux_out;
// rf(ID)-mux
wire rf_sr1_mux_sel, rf_sr2_mux_sel;
wire [31:0] rf_sr1_out, rf_sr2_out;


// FH
wire [2:0] b_sr1_mux_sel_fh, b_sr2_mux_sel_fh, sr1_mux_sel_fh, sr2_mux_sel_fh, sr3_mux_sel_fh, dm_sr2_mux_sel_fh;
wire [2:0] ex_b_sr1_mux_sel_fh, ex_b_sr2_mux_sel_fh, ex_sr1_mux_sel_fh, ex_sr2_mux_sel_fh, ex_sr3_mux_sel_fh, ex_dm_sr2_mux_sel_fh;

// Pipeline stop unit
wire if_id_wen, id_ex_wen, ex_mem_wen, mem_wb_wen;
wire if_id_clear, id_ex_clear, ex_mem_clear, mem_wb_clear;

// Debug data lines
wire [15:0] im_debug_din;
wire [31:0] im_debug_dout;
wire [15:0] dm_debug_din;
wire [31:0] dm_debug_dout;
wire [4:0] rfi_debug_add;
wire [31:0] rfi_debug_data;
wire [4:0] rff_debug_add;
wire [31:0] rff_debug_data;

// Below is the wires and regs connection ===========================================================================================
initial begin
    zero <= 32'b0;
    one <= 1'b1;
end

// Below is the memory and register-files connection:
assign rfi_sr1_add = id_is[19:15];
assign rfi_sr2_add = id_is[24:20];
assign rfi_dr_add = wb_dr[4:0];
assign rff_sr1_add = id_is[19:15];
assign rff_sr2_add = id_is[24:20];
assign rff_sr3_add = id_is[31:27];
assign rff_dr_add = wb_dr[4:0];
assign im_din = pc_out[13:2];
assign dm_addr = mem_dm_addr[13:2];
assign dm_din = mem_dm_data;

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
// CTRL-EX (0 + sr1mux(3), sr2mux(3), alumode(6), mulmode(3))
// CTRL-MEM (00 + dmwe(1), dmrd(1))
// CTRL-WB (000 + rfmux(3), rfiwe(1), rffwe(1))
// MUX-SEL (0000 + sr1(3), sr2(3), sr3(3), bsr1(3), bsr2(3), dsr2(3), npc(2))


// Below is the control signals connection (ID)
assign id_ctrl_ex = {{1'b0}, {control_signals[2:0]}, {control_signals[5:3]}, {control_signals[19:14]}, {control_signals[22:20]}};
assign id_ctrl_mem = {{2'b0}, {control_signals[27]}, {control_signals[28]}};
assign id_ctrl_wb = {{3'b0}, {control_signals[8:6]}, {control_signals[24]}, {control_signals[25]}};
assign id_mux_sel = {{4'b0}, {sr1_mux_sel_fh}, {sr2_mux_sel_fh}, {sr3_mux_sel_fh}, {b_sr1_mux_sel_fh}, {b_sr2_mux_sel_fh}, {dm_sr2_mux_sel_fh}, {npc_mux_sel}};
assign jump_ctrl = control_signals[33:30];
assign rf_sr1_mux_sel = control_signals[9];
assign rf_sr2_mux_sel = control_signals[10];
assign id_rf_dr = {{27'b0}, {id_is[11:7]}};

// Below is the control signals connection (EX)
// CTRL-EX (00 + sr1mux(3), sr2mux(3), alumode(5), mulmode(3))
assign ex_sr1_mux_sel_cu = ctrl_ex_dout[13:11];
assign ex_sr2_mux_sel_cu = ctrl_ex_dout[10:8];
assign alu_mode = ctrl_ex_dout[7:3];
assign mul_mode = ctrl_ex_dout[2:0];

// Below is the control signals connection (MEM)
// CTRL-MEM (00 + dmwe(1), dmrd(1))
assign dm_wen = ctrl_mem_dout[1];
assign dm_rd = ctrl_mem_dout[0];

// Below is the control signals connection (WB)
// CTRL-WB (000 + rfmux(3), rfiwe(1), rffwe(1))
assign rf_mux_sel = ctrl_wb_dout[4:2];
assign rfi_wen = ctrl_wb_dout[1];
assign rff_wen = ctrl_wb_dout[0];

// Below is the EX part mux-sel connection
assign ex_sr1_mux_sel_fh = sr_mux_dout[19:17];
assign ex_sr2_mux_sel_fh = sr_mux_dout[16:14];
assign ex_sr3_mux_sel_fh = sr_mux_dout[13:11];
assign ex_b_sr1_mux_sel_fh = sr_mux_dout[10:8];
assign ex_b_sr2_mux_sel_fh = sr_mux_dout[7:5];
assign ex_dm_sr2_mux_sel_fh = sr_mux_dout[4:2];
assign ex_npc_mux_sel = sr_mux_dout[1:0];

// Below is the MUX SEL connection
assign b_sr1_mux_sel = ex_b_sr1_mux_sel_fh;
assign b_sr2_mux_sel = ex_b_sr2_mux_sel_fh;
assign dm_sr2_mux_sel = ex_dm_sr2_mux_sel_fh;
assign sr3_mux_sel = ex_sr3_mux_sel_fh;



// Below is the sub-module declaration ==============================================================================================

// Memorys
Instruction_MEM im (
    .clk(clk),
    .add_1(im_din),
    .data_1(zero),
    .we_1(zero[0]),
    .radd_2(im_debug_din),
    .out_1(im_dout), 
    .out_2(im_debug_dout)
);

Data_MEM dm (
    .clk(clk),
    .add_1(dm_addr),
    .data_1(dm_din),
    .we_1(dm_wen),
    .radd_2(dm_debug_din),
    .out_1(dm_dout), 
    .out_2(dm_debug_dout)
);

// Reg file
REG_FILE_I rfi (
    .clk(clk),			           
    .ra0(rfi_sr1_add), 
    .ra1(rfi_sr2_add), 
    .ra2(rfi_debug_add),	
    .rd0(rfi_sr1_data), 
    .rd1(rfi_sr2_data), 
    .rd2(rfi_debug_data),	
    .wa(rfi_dr_add),		        
    .wd(rfi_dr_data),		        
    .we(rfi_wen)			            
);

REG_FILE_F rff (
    .clk(clk),			           
    .ra0(rff_sr1_add), 
    .ra1(rff_sr2_add), 
    .ra2(rff_sr3_add),	
    .ra3(rff_debug_add),
    .rd0(rff_sr1_data), 
    .rd1(rff_sr2_data), 
    .rd2(rff_sr3_data),	
    .rd3(rff_debug_data),
    .wa(rff_dr_add),		        
    .wd(rff_dr_data),		        
    .we(rff_wen)			            
);

// PC register
PC pc (
    .clk(clk),
    .wen(pc_wen),
    .din(pc_in),
    .dout(pc_out)
);

// Iter-segment Registers
IF_ID_REG if_id_reg(
    // signals
    .clk(clk),
    .rstn(rstn),
    .wen(if_id_wen),
    .clear(if_id_clear),

    // data
    .is_din(im_dout),
    .pc_din(pc_out),

    .is_dout(id_is),
    .pc_dout(id_pc)
);

ID_EX_REG id_ex_reg(
    // signals
    .clk(clk),
    .rstn(rstn),
    .wen(id_ex_wen),
    .clear(id_ex_clear),   

    // data
    .is_din(id_is),
    .pc_din(id_pc),
    .imm_din(id_imm),
    .sr1_din(rf_sr1_out),
    .sr2_din(rf_sr2_out),
    .sr3_din(rff_sr3_data),
    .dr_din(id_rf_dr),
    .ctrl_ex_din(id_ctrl_ex),
    .ctrl_mem_din(id_ctrl_mem),       
    .ctrl_wb_din(id_ctrl_wb),     
    .alu_ex_din(alu_ans),
    .alu_mem_din(mem_alu_ans),
    .npc_mem_din(mem_pc + 32'h4),
    .dm_mem_din(io_dm_mux_out),
    .mux_sel_din(id_mux_sel),
 
    .is_dout(ex_is),
    .pc_dout(ex_pc),
    .imm_dout(ex_imm),
    .sr1_dout(ex_sr1),
    .sr2_dout(ex_sr2),
    .sr3_dout(ex_sr3),
    .dr_dout(ex_dr),
    .ctrl_ex_dout(ctrl_ex_dout),
    .ctrl_mem_dout(ex_ctrl_mem),
    .ctrl_wb_dout(ex_ctrl_wb),
    .alu_ex_dout(alu_ex),
    .alu_mem_dout(alu_mem),
    .npc_mem_dout(npc_mem),
    .dm_mem_dout(dm_mem),
    .mux_sel_dout(sr_mux_dout)
);

EX_MEM_REG ex_mem_reg(
    // signals
    .clk(clk),
    .rstn(rstn),
    .wen(ex_mem_wen),
    .clear(ex_mem_clear),

    // data
    .is_din(ex_is),
    .pc_din(ex_pc),
    .ctrl_mem_din(ex_ctrl_mem),
    .ctrl_wb_din(ex_ctrl_wb),
    .alu_ans_din(alu_ans),
    .alu_ans_mux_sel_din(),
    .dm_addr_din(sr1_mux_out + sr2_mux_out),
    .dm_data_din(dm_sr2_mux_out),
    .dr_din(ex_dr),

    .is_dout(mem_is),
    .pc_dout(mem_pc),
    .ctrl_mem_dout(ctrl_mem_dout),
    .ctrl_wb_dout(mem_ctrl_wb),
    .alu_ans_dout(mem_alu_ans),
    .alu_ans_mux_sel_dout(),
    .dm_addr_dout(mem_dm_addr),
    .dm_data_dout(mem_dm_data),
    .dr_dout(mem_dr)

);

MEM_WB_REG mem_wb_reg(
    // signals
    .clk(clk),
    .rstn(rstn),
    .wen(mem_wb_wen),
    .clear(mem_wb_clear),

    // data
    .is_din(mem_is),
    .pc_din(mem_pc),
    .ctrl_wb_din(mem_ctrl_wb),
    .alu_ans_din(mem_alu_ans),
    .mdr_din(io_dm_mux_out),
    .csr_din(),
    .dr_din(mem_dr),

    .is_dout(wb_is),
    .pc_dout(wb_pc),
    .ctrl_wb_dout(ctrl_wb_dout),
    .alu_ans_dout(wb_alu_ans),
    .mdr_dout(wb_mdr),
    .csr_dout(),
    .dr_dout(wb_dr)
);



// The control unit
Control #(35) cu(
    .instruction(id_is),
    .control_signal(control_signals)
);

// The sign extend unit

Signextend sext(
    .instruction(id_is),
    .imm(id_imm)
);

// The branch control
Branch_CTRL bcu(
    .branch_sel(jump_ctrl),
    .sr1(b_sr1_mux_out), 
    .sr2(b_sr2_mux_out),
    .imm(id_imm),
    .pc(id_pc),
    .npc_mux_sel(npc_mux_sel),
    .pc_offset(pc_offset), 
    .reg_offset(reg_offset)
);


// ALU

ALU #(32) alu (
    .num1(sr1_mux_out), 
    .num2(sr2_mux_out),             
    .mul_din(fm_ans),  
    .mode_sel(alu_mode),                        
    .ans(alu_ans),                 
    .sub_flag(alu_subflag),                        
    .error(alu_error)                               
);

// MUL
FAST_MUL fm(
    .number1(fm_sr1),
    .number2(fm_sr2),
    .clk(clk),
    .ans(fm_ans),
); 


// MUXs

MUX2 #(32) io_dm_mux(
    .data1(dm_dout),
    .data2(io_din),
    .sel(io_dm_mux_sel),
    .out(io_dm_mux_out)
);

MUX2 #(32) rf_sr1_mux(
    .data1(rfi_sr1_data),
    .data2(rff_sr1_data),
    .sel(rf_sr1_mux_sel),
    .out(rf_sr1_out)
);

MUX2 #(32) rf_sr2_mux(
    .data1(rfi_sr2_data),
    .data2(rff_sr2_data),
    .sel(rf_sr2_mux_sel),
    .out(rf_sr2_out)
);



MUX4 #(32) npc_mux(
    .data1(pc_out + 32'd4),       
    .data2(pc_offset),       
    .data3(reg_offset),       
    .data4(),       
    .sel(npc_mux_sel),
    .out(pc_in)
);

MUX8 #(32) rf_mux(
    .data1(wb_alu_ans),
    .data2(wb_pc + 32'h4),
    .data3(wb_mdr),
    .data4(zero),
    .data5(zero),
    .data6(zero),
    .data7(zero),
    .data8(32'b1),
    .sel(rf_mux_sel),
    .out(rfi_dr_data)
);


MUX8 #(32) b_sr1_mux(
    .data1(rfi_sr1_data),
    .data2(zero),
    .data3(zero),
    .data4(zero),
    .data5(alu_ex),
    .data6(alu_mem),
    .data7(dm_mem),
    .data8(npc_mem),
    .sel(b_sr1_mux_sel),
    .out(b_sr1_mux_out)
);

MUX8 #(32) b_sr2_mux(
    .data1(rfi_sr2_data),
    .data2(zero),
    .data3(zero),
    .data4(zero),
    .data5(alu_ex),
    .data6(alu_mem),
    .data7(dm_mem),
    .data8(npc_mem),
    .sel(b_sr2_mux_sel),
    .out(b_sr2_mux_out)
);

MUX8 #(32) sr1_mux(
    .data1(ex_sr1),
    .data2(ex_pc),
    .data3(zero),
    .data4(zero),
    .data5(alu_ex),
    .data6(alu_mem),
    .data7(dm_mem),
    .data8(npc_mem),
    .sel(sr1_mux_sel),
    .out(sr1_mux_out)
);

MUX8 #(32) sr2_mux(
    .data1(ex_sr2),
    .data2(ex_imm),
    .data3(zero),
    .data4(zero),
    .data5(alu_ex),
    .data6(alu_mem),
    .data7(dm_mem),
    .data8(npc_mem),
    .sel(sr2_mux_sel),
    .out(sr2_mux_out)
);

MUX8 #(32) sr3_mux(
    .data1(ex_sr3),
    .data2(zero),
    .data3(zero),
    .data4(zero),
    .data5(alu_ex),
    .data6(alu_mem),
    .data7(dm_mem),
    .data8(npc_mem),
    .sel(sr3_mux_sel),
    .out(sr3_mux_out)
);

MUX8 #(32) dm_sr2_mux(
    .data1(ex_sr2),
    .data2(zero),
    .data3(zero),
    .data4(zero),
    .data5(alu_ex),
    .data6(alu_mem),
    .data7(dm_mem),
    .data8(npc_mem),
    .sel(dm_sr2_mux_sel),
    .out(dm_sr2_mux_out)
);



MUX8 #(32) fm_sr1_mux (
    .data1(),
    .data2(),
    .data3(),
    .data4(),
    .data5(),
    .data6(),
    .data7(),
    .data8(),
    .sel(),
    .out(fm_sr1)
);

MUX8 #(32) fm_sr2_mux (
    .data1(),
    .data2(),
    .data3(),
    .data4(),
    .data5(),
    .data6(),
    .data7(),
    .data8(),
    .sel(),
    .out(fm_sr2)
);


// FH

Forwarding_Hazard fh(
    .id_is(id_is),
    .ex_is(ex_is),
    .mem_is(mem_is),
    .wb_is(wb_is),
    .npc_mux_sel(ex_npc_mux_sel),

    // forwarding
    .b_sr1_mux_sel_fh(b_sr1_mux_sel_fh),
    .b_sr2_mux_sel_fh(b_sr2_mux_sel_fh),
    .sr1_mux_sel_fh(sr1_mux_sel_fh),
    .sr2_mux_sel_fh(sr2_mux_sel_fh),
    .sr3_mux_sel_fh(sr3_mux_sel_fh),
    .dm_sr2_mux_sel_fh(dm_sr2_mux_sel_fh),

    // hazard -- dealing with cpu's stop
    .pc_en(pc_wen),
    .if_id_en(if_id_en),
    .id_ex_clear(id_ex_clear)
);

// SR1&2 mux sel
SR_MUX_CTRL sr_mux_cu(
    .sr1_mux_sel_cu(ex_sr1_mux_sel_cu),
    .sr2_mux_sel_cu(ex_sr2_mux_sel_cu),
    .sr1_mux_sel_fh(ex_sr1_mux_sel_fh),
    .sr2_mux_sel_fh(ex_sr2_mux_sel_fh),

    .sr1_mux_sel(sr1_mux_sel),
    .sr2_mux_sel(sr2_mux_sel)
);

// Debuger
DEBUG debug(
    // Debug_BUS
    .chk_addr(chk_addr),	// debug address
    .chk_data(chk_data),  // debug data
    .chk_pc(chk_pc), 	// current pc

    // cpu info
    // IF PART
    .if_npc(pc_in),
    .if_pc(pc_out),
    .if_is(im_dout),

    // ID PART
    .id_pc(id_pc),
    .id_is(id_is),

    .id_ctrl(control_signals),

    .id_sr1_addr(rfi_sr1_add),
    .id_sr2_addr(rfi_sr2_add),
    .id_sr1(rfi_sr1_data),
    .id_sr2(rfi_sr2_data),
    .id_b_sr1(b_sr1_mux_out),
    .id_b_sr2(b_sr2_mux_out),
    .id_b_sr1_mux_sel(b_sr1_mux_sel),
    .id_b_sr2_mux_sel(b_sr2_mux_sel),

    .id_npc_mux_sel(npc_mux_sel),
    .id_imm(id_imm),
    .id_jalr_flag(jalr_flag),

    // EX PART
    .ex_pc(ex_pc),
    .ex_is(ex_is),

    .ex_sr1_mux_sel_cu(ex_sr1_mux_sel_cu),
    .ex_sr2_mux_sel_cu(ex_sr2_mux_sel_cu),
    .ex_sr1_mux_sel_fh(ex_sr1_mux_sel_fh),
    .ex_sr2_mux_sel_fh(ex_sr2_mux_sel_fh),
    .ex_dm_sr2_mux_sel(dm_sr2_mux_sel_fh),
    .ex_sr1_mux_sel(sr1_mux_sel),
    .ex_sr2_mux_sel(sr2_mux_sel),

    .ex_sr1(ex_sr1),
    .ex_sr2(ex_sr2),
    .ex_dm_sr2(dm_sr2_mux_out),

    .ex_alu_number1(sr1_mux_out),
    .ex_alu_number2(sr2_mux_out),
    .ex_alu_mode(alu_mode),
    .ex_alu_ans(alu_ans),

    .ex_alu_ex(alu_ex),
    .ex_alu_mem(alu_mem),
    .ex_dm_mem(dm_mem),
    .ex_npc_mem(npc_mem),

    .ex_ctrl_mem(ex_ctrl_mem),
    .ex_ctrl_wb(ex_ctrl_wb),
    .ex_npc_mux_sel(ex_npc_mux_sel),

    // MEM PART
    .mem_pc(mem_pc),
    .mem_is(mem_is),

    .mem_alu_ans(mem_alu_ans),
    .mem_dm_data(mem_dm_data),
    .mem_dm_wen(dm_wen),
    .mem_io_rd(io_rd),
    .mem_dm_dout(dm_dout),
    .mem_io_dout(io_din),
    .mem_io_dm_mux_sel(io_dm_mux_sel),
    
    // WB PART
    .wb_pc(wb_pc),
    .wb_is(wb_is),

    .wb_rf_mux_sel(rf_mux_sel),
    .wb_alu_ans(wb_alu_ans),
    .wb_dm_dout(wb_mdr),
    .rf_write_addr(rfi_dr_add),
    .rf_din(rfi_dr_data),
    .rfi_wen(rfi_wen),

    // FH 
    .pc_wen(pc_wen),
    .if_id_is_wen(if_id_en),
    .id_ex_reg_clear(id_ex_clear),
    .sr1_mux_sel_fh(sr1_mux_sel_fh),
    .sr2_mux_sel_fh(sr2_mux_sel_fh),
    .b_sr1_mux_sel_fh(b_sr1_mux_sel_fh),
    .b_sr2_mux_sel_fh(b_sr2_mux_sel_fh),
    .dm_sr2_mux_sel_fh(dm_sr2_mux_sel_fh),

    // RF data
    .rf_debug_addr(rfi_debug_add),
    .rf_debug_data(rfi_debug_data),

    // DM data
    .dm_debug_addr(dm_debug_din),
    .dm_debug_data(dm_debug_dout)
);

endmodule
