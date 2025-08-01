`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.05.2025 20:24:11
// Design Name: 
// Module Name: compare_swap_dsc
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


module compare_swap_desc (
    input  signed [15:0] a,
    input  signed [15:0] b,
    output signed [15:0] s0, // max
    output signed [15:0] s1  // min
);
    assign s0 = (a > b) ? a : b;
    assign s1 = (a > b) ? b : a;
endmodule
