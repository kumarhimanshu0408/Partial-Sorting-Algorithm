`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.05.2025 20:25:40
// Design Name: 
// Module Name: max_k
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


module max_k #(
    parameter K = 16
) (
    input  signed [K*16-1:0] asc_in,
    input  signed [K*16-1:0] desc_in,
    output signed [K*16-1:0] largest_out
);
    wire signed [15:0] asc_elem  [0:K-1];
    wire signed [15:0] desc_elem [0:K-1];
    wire signed [15:0] larger    [0:K-1];
    wire signed [15:0] smaller   [0:K-1];

    genvar i_mk;
    generate
        for (i_mk = 0; i_mk < K; i_mk = i_mk + 1) begin : unpack_mk
            assign asc_elem[i_mk]  = asc_in[(i_mk*16)+:16];
            assign desc_elem[i_mk] = desc_in[(i_mk*16)+:16];
        end
        for (i_mk = 0; i_mk < K; i_mk = i_mk + 1) begin : compare_mk
            compare_swap_asc cmp_inst_mk (
                .a(asc_elem[i_mk]),
                .b(desc_elem[i_mk]),
                .s0(smaller[i_mk]),
                .s1(larger[i_mk])
            );
        end
        for (i_mk = 0; i_mk < K; i_mk = i_mk + 1) begin : pack_mk
            assign largest_out[(i_mk*16)+:16] = larger[i_mk];
        end
    endgenerate
endmodule

