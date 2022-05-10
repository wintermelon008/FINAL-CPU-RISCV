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

/*  ================================= CSR table =================================

    With the original CSRs below:
        mtevc (Machine Trp-Vecor Base-Address Register)     address 0x305
        mcause (Machine CauseRegister)                      address 0x342
        mepc (Machine Exception Program Counter)            address 0x341
        mtval (Machine Trap Value Resiste)                  address 0x343

    With new designed CSRs below:
        mipd (Machine Interrupt Program Done)               address 0x100

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
    
    // CSR
    input [31:0] csr_din,
    output [31:0] csr_dout
    input [31:0] csr_radd,
    input [31:0] csr_wadd,
    input csr_wen,
    

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

    localparam Reset = 4'h0;
    localparam Wait = 4'h1;
    localparam Set_CSR_PCU = 4'h2;      // Set CSR according to the CPU status
    localparam Wait_done = 4'h3;
    localparam Reload = 4'h4;
    localparam Set_CSR_CPU = 4'h3;      // Set CSR according to the CPU program


/*
    ================================= CPU clock State machine table =================================
*/
    localparam CLOCK_STOP = 2'b00;
    localparam CLOCK_RUN = 2'b01;





wire if_id_en_fh, id_ex_clear_fh, pc_wen_fh;

wire user_breakpoint;
wire csr_we;        // The final write enable signal

reg [3:0] current_state, next_state;
reg [1:0] clk_cs, clk_ns;
reg [31:0] mtevc, mtval, mepc, mcause, mipd;
wire [31:0] mtevc_dout, mtval_dout, mepc_dout, mcause_dout, mipd_dout;


reg [31:0] cpu_clk_conter;
reg slow_clk;
reg cpu_clk_en;
reg pcu_csr_wen;        // Control by state machine

// Below is the wires connection
assign user_breakpoint = (pdu_breakpoint == id_pc) ? 1'b1 : 1'b0;
assign cpu_clk = slow_clk & cpu_clk_en;
assign cpu_stop = (clk_cs == CLOCK_STOP) ? 1'b1 : 1'b0;
assign csr_we = csr_wen | pcu_csr_wen;


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

// CSR read
always @(*) begin
    csr_dout = 32'h0;
    case (csr_addr)
        32'h0305: csr_dout = mtevc_dout;
        32'h0342: csr_dout = mcause_dout;
        32'h0341: csr_dout = mepc_dout;
        32'h0343: csr_dout = mtval_dout;
        32'h0100: csr_dout = mipd_dout;
    endcase
end


// Below is the PCU state machine

always @(*) begin
    if (~rstn) begin
        next_state = Reset;
    end
    else begin
        case (current_state) 
            Wait: begin
                mtevc = 32'h0;
                mcause = 32'h0;
                mepc = 32'h0;
                mtval = 32'h0;      // no working infomation
                next_state = Wait;

                if (ebreak) begin
                    // Progrom starts at 0xF000
                    mtevc = 32'hF000;
                    mcause = Program_Breakpoint;
                    mepc = ex_pc + 32'h4;
                    mtval = 32'b0;      // no working infomation
                    next_state = Set_CSR_PCU;
                end 
                else if (user_breakpoint) begin
                    // Program starts at 0xF004
                    mtevc = 32'hF004;
                    mcause = User_Breakpoint;
                    mepc = ex_pc + 32'h4;
                    mtval = id_pc;      // Store the current PC
                    next_state = Set_CSR_PCU;
                end
                else if (csr_wen) begin
                    // Program CSR instruction write
                    case (csr_addr) 
                        32'h0305: mtevc = csr_din;
                        32'h0342: mcause = csr_din;
                        32'h0341: mepc = csr_din;
                        32'h0343: mtval = csr_din;
                        32'h0100: mpid = csr_din;
                    endcase
                    next_state = Set_CSR_CPU;
                end

            end

            Set_CSR_PCU: next_state = Wait_done;

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
    pcu_csr_wen = 1'b0;
    case (next_state)
        Set_CSR_PCU: begin  
            pcu_csr_wen = 1'b1;
        end
    endcase
end


// Below is the CPU clock control

always @(*) begin
    if (~rstn) begin
        clk_ns = CLOCK_STOP;
    end
    else begin
        case (clk_cs) 
            CLOCK_RUN: begin
                if (ebreak || user_breakpoint) begin
                    // Breakpoint
                    clk_ns = CLOCK_STOP;
                end
                else
                    clk_ns = CLOCK_RUN;
            end

            CLOCK_STOP: begin
                if (pdu_run || mipd_dout == 32'b1) begin
                    // Breakpoints: user press [enter], then pdu_run will be 1
                    // Other interrupt: the program will set Mipd to 1

                    clk_ns = CLOCK_RUN;
                end
                else
                    clk_ns = CLOCK_STOP;
            end
    
            default: clk_ns = CLOCK_STOP;
        endcase
    end
end

always @(posedge clk or negedge rstn) begin
    if (~rstn)
        clk_cs <= CLOCK_STOP;
    else
        clk_cs <= clk_ns;
end

always @(*) begin
    case (clk_ns) 
        CLOCK_RUN: begin
            cpu_clk_en = 1'b1;
        end

        CLOCK_STOP: begin
            cpu_clk_en = 1'b0;
        end

        default: begin
            cpu_clk_en = 1'b0;
        end
    endcase
end

// CPU clock control
localparam CPU_CLK_N = 11'd5;
//localparam CPU_CLK_N = 11'd25000000;

always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
        cpu_clk_conter <= 0;
        slow_clock <= 0;
    end
    else begin
        if (cpu_clk_conter == CPU_CLK_N + CPU_CLK_N) begin
            cpu_clk_conter <= 32'b1;
            slow_clock <= 1'b1;
        end
        else begin               
            if (cpu_clk_conter < CPU_CLK_N)
                slow_clk <= 1'b1;
            else 
                slow_clk <= 1'b0;
            cpu_clk_conter <= cpu_clk_conter + 'h1;
        end
 
       
    end
end



// CSRs
CSR_UNIT csr(
    .csr_we(),
    .csr_clk(),
    .rstn(),

    // CSRs
    .mtevc_din(mtevc),
    .mtevc_dout(mtevc_dout),

    .mcause_din(mcause),
    .mcause_dout(mcause_dout),

    .mepc_din(mepc),
    .mepc_dout(mepc_dout),

    .mtval_din(mtval),
    .mtval_dout(mtval_dout),

    .mipd_din(mipd),
    .mipd_dout(mipd_dout),

    .csr_debug_addr(),
    .csr_debug_dout()
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
    .dm_sr2_mux_sel_fh(dm_sr2_mux_sel_fh),

    // hazard -- dealing with cpu's stop
    .pc_en(pc_wen_fh),
    .if_id_en(if_id_en_fh),
    .id_ex_clear(id_ex_clear_fh)
);

endmodule
