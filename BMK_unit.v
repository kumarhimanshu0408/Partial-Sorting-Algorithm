`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.05.2025 20:26:33
// Design Name: 
// Module Name: BMK_unit
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


module BMK_unit #(
    parameter K = 8,
    parameter sortdir = 0
) (
    input wire clk,
    input wire rst,
    input  signed [K*16-1:0] in_data,
    output signed [K*16-1:0] out_data
);

    generate
        if (K == 1) begin : bmk_k1_case
             assign out_data = in_data;
        end else if (K == 2) begin : base_case_bmk
            wire signed [15:0] in0_bmk, in1_bmk;
            wire signed [15:0] s0_w_bmk, s1_w_bmk;
            assign in0_bmk = in_data[15:0];
            assign in1_bmk = in_data[31:16];

            if (sortdir == 0) begin : use_asc_bmk_base
                compare_swap_asc cmp_inst_bmk_base (
                    .a(in0_bmk), .b(in1_bmk), .s0(s0_w_bmk), .s1(s1_w_bmk)
                );
            end else begin : use_desc_bmk_base
                compare_swap_desc cmp_inst_bmk_base (
                    .a(in0_bmk), .b(in1_bmk), .s0(s0_w_bmk), .s1(s1_w_bmk)
                );
            end
            assign out_data[15:0]  = s0_w_bmk;
            assign out_data[31:16] = s1_w_bmk;
        end
        else if (K > 2) begin : recursive_case_bmk
            localparam HALF_BMK = K/2;
            wire signed [K*16-1:0] stage1_comp_out_w_bmk;
            reg  signed [K*16-1:0] stage1_comp_out_r_bmk;

            genvar i_bmk_recur;
            for (i_bmk_recur = 0; i_bmk_recur < HALF_BMK; i_bmk_recur = i_bmk_recur + 1) begin : bmk_compare_swaps_bank
                wire signed [15:0] a_val_bmk, b_val_bmk, s0_val_bmk, s1_val_bmk;
                assign a_val_bmk = in_data[(i_bmk_recur*16) +: 16];
                assign b_val_bmk = in_data[((i_bmk_recur+HALF_BMK)*16) +: 16];

                if (sortdir == 0) begin : use_asc_bmk_recursive
                    compare_swap_asc cmp_inst_bmk_r (
                        .a(a_val_bmk), .b(b_val_bmk), .s0(s0_val_bmk), .s1(s1_val_bmk)
                    );
                end else begin : use_desc_bmk_recursive
                    compare_swap_desc cmp_inst_bmk_r (
                        .a(a_val_bmk), .b(b_val_bmk), .s0(s0_val_bmk), .s1(s1_val_bmk)
                    );
                end
                assign stage1_comp_out_w_bmk[(i_bmk_recur*16) +: 16]        = s0_val_bmk;
                assign stage1_comp_out_w_bmk[((i_bmk_recur+HALF_BMK)*16) +: 16] = s1_val_bmk;
            end

            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    stage1_comp_out_r_bmk <= {(K*16){1'sh0}};
                end else begin
                    stage1_comp_out_r_bmk <= stage1_comp_out_w_bmk;
                end
            end

            wire signed [HALF_BMK*16-1:0] top_half_in_recursive_bmk,  bottom_half_in_recursive_bmk;
            wire signed [HALF_BMK*16-1:0] top_half_out_recursive_bmk, bottom_half_out_recursive_bmk;

            assign top_half_in_recursive_bmk    = stage1_comp_out_r_bmk[HALF_BMK*16-1:0];
            assign bottom_half_in_recursive_bmk = stage1_comp_out_r_bmk[K*16-1:HALF_BMK*16];

            BMK_unit #(.K(HALF_BMK), .sortdir(sortdir)) bm_top (
                .clk(clk), .rst(rst),
                .in_data (top_half_in_recursive_bmk),
                .out_data(top_half_out_recursive_bmk)
            );
            BMK_unit #(.K(HALF_BMK), .sortdir(sortdir)) bm_bottom (
                .clk(clk), .rst(rst),
                .in_data (bottom_half_in_recursive_bmk),
                .out_data(bottom_half_out_recursive_bmk)
            );
            assign out_data[HALF_BMK*16-1:0]   = top_half_out_recursive_bmk;
            assign out_data[K*16-1:HALF_BMK*16] = bottom_half_out_recursive_bmk;
        end
    endgenerate
endmodule
