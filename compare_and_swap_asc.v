`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.05.2025 20:23:13
// Design Name: 
// Module Name: compare_and_swap_asc
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


module compare_swap_asc (
    input  signed [15:0] a,
    input  signed [15:0] b,
    output signed [15:0] s0, // min
    output signed [15:0] s1  // max
);
    assign s0 = (a < b) ? a : b;
    assign s1 = (a < b) ? b : a;
endmodule
