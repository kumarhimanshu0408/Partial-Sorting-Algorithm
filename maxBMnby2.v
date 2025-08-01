`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.05.2025 20:28:17
// Design Name: 
// Module Name: maxBMnby2
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


module maxBMnby2 #(
    parameter K = 8,
    parameter sortdir = 0
) (
    input wire clk,
    input wire rst,
    input  signed [K*16-1:0] asc_in,
    input  signed [K*16-1:0] desc_in,
    output signed [K*16-1:0] out_data
);
    wire signed [K*16-1:0] max_k_out_w_maxbm;
    reg  signed [K*16-1:0] merged_max_r_maxbm;

    max_k #(.K(K)) max_selector (
        .asc_in(asc_in),
        .desc_in(desc_in),
        .largest_out(max_k_out_w_maxbm)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            merged_max_r_maxbm <= {(K*16){1'sh0}};
        end else begin
            merged_max_r_maxbm <= max_k_out_w_maxbm;
        end
    end

    BMK_unit #(.K(K), .sortdir(sortdir)) sort_unit (
        .clk(clk), .rst(rst),
        .in_data(merged_max_r_maxbm),
        .out_data(out_data)
    );
endmodule
