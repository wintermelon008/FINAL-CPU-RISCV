`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/05/06 18:58:17
// Design Name: 
// Module Name: Pipline_CTRL
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
    ================================   Pipline_CTRL module   ================================ 
    Author:         Wintermelon
    Last Edit:      2022.5.9

    This is the PCU
    Function: 1. Solve the interrupt (with CSRs inside)
              2. Solve the data hazard (with the forwarding control, pipeline stop etc.)
*/

module Pipline_CTRL(
    input clk,    // 100Mhz
    input rstn,
    input [31:0] if_is, id_is, ex_is, mem_is, wb_is,
    input [31:0] if_pc, id_pc, ex_pc, mem_pc, wb_pc,
    input [2:0] ex_npc_mux_sel,
    input [3:0] error,
    input ebreak,               // No.1
    input pdu_breakpoint,       // No.2
    
    input [31:0] csr_data,
    input [31:0] csr_addr,
    

    output cpu_clk,
    output reg if_id_wen, id_ex_wen, ex_mem_wen, mem_wb_wen,
    output reg if_id_clear, id_ex_clear, ex_mem_clear, mem_wb_clear,
    output reg pc_wen,
    output [2:0] b_sr1_mux_sel_fh,
    output [2:0] b_sr2_mux_sel_fh,
    output [2:0] sr1_mux_sel_fh,
    output [2:0] sr2_mux_sel_fh,
    output [2:0] dm_sr2_mux_sel_fh,

    output cpu_stop
);

/*  ================================= CPU Interrupt table =================================

    1. Program Interrupt (We make it as ebreak)
    2. User Interrupt (We make it as user breakpoint)
    3. Divide by 0
    4. Memory access error
    5. Instruction decode error
    ......
*/

localparam No_Error = 4'h0;
localparam Program_Breakpoint = 4'h1;
localparam User_Breakpoint = 4'h2;
localparam Divide_By_Zero = 4'h3;
localparam Memory_Access_Error = 4'h4;
localparam Is_Decode_Error = 4'h5;


/*  ================================= PCU State machine table =================================

    1. Wait (CPU continue working)
    2. Set CSRs (mtevc, mcause, mepc, mtval) (CPU stop, set the muxs)
    3. Wait for interrupt solveing program finish
    4. Reload PC (CPU stop, set the muxs)
    5. Wait(1.) (CPU continue working)
    ......
*/

// With the CSRs below:
//         mtevc (Machine Trp-Vecor Base-Address Register)     address 0x305
//         mcause (Machine CauseRegister)                      address 0x342
//         mepc (Machine Exception Program Counter)            address 0x341
//         mtval (Machine Trap Value Resiste)                  address 0x343

localparam Reset = 4'h0;
localparam Wait = 4'h1;
localparam Set_CSR = 4'h2;
localparam Wait_done = 4'h3;
localparam Reload = 4'h4;


wire if_id_en_fh, id_ex_clear_fh, pc_wen_fh;
wire pcu_clk, cpu_clk_en;

reg [3:0] current_state, next_state;
reg [31:0] mtevc, mtval, mepc, mcause;

always @(*) begin
    if (~rstn) begin
        next_state = Reset;
    end
    else begin
        case (current_state) 
            Wait: begin
                next_state = Wait;
                if (ebreak) begin
                    // Progrom starts at 0xF000
                    mtevc = 32'hF000;
                    mcause = Program_Breakpoint;
                    mepc = ex_pc + 32'h4;
                    mtval = 32'b0;      // no working infomation
                    next_state = Set_CSR;
                end 
                else if (pdu_breakpoint) begin
                    // Program starts at 0xF004
                    mtevc = 32'hF004;
                    mcause = User_Breakpoint;
                    mepc = 
                    mtval = id_pc;      // Store the current PC
                    next_state = Set_CSR;
                end

            end

            Set_CSR: next_state = Wait_done;

        endcase
    end
end

always @(posedge clk or negedge rstn) begin
    if (~rstn)
        current_state <= Reset;
    else
        current_state <= next_state;
end

always @(*) begin
    case (next_state)
    endcase
end


// Below is the wires connection
assign cpu_clk = clk & cpu_clk_en;

always @(*) begin
    if_id_wen = if_id_en_fh;
    id_ex_wen = 1'b1;
    ex_mem_wen = 1'b1;
    mem_wb_wen = 1'b1;

    if_id_clear = 1'b0;
    id_ex_clear = id_ex_clear_fh;
    ex_mem_clear = 1'b0;
    mem_wb_clear = 1'b0;

    pc_wen = pc_wen_fh;
end



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
    .dm_sr2_mux_sel_fh(dm_sr2_mux_sel_fh),

    // hazard -- dealing with cpu's stop
    .pc_en(pc_wen_fh),
    .if_id_en(if_id_en_fh),
    .id_ex_clear(id_ex_clear_fh)
);

endmodule
