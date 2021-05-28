`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:56:00 12/18/2020 
// Design Name: 
// Module Name:    timeout 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module timeout(
	input clk,
	input received,
	output reg busy = 0, // consequtive reception
	output timeout
	);

	parameter TOCNTSIZE = 7; // timeout counter size
	
	reg [(TOCNTSIZE - 1):0] cnt_busy = 0; // timeout counter
	
	assign timeout = (cnt_busy == {TOCNTSIZE{1'b1}});
	
	always @ (posedge clk) begin
		busy <= received ? 1 : timeout ? 0 : busy;
		cnt_busy <= (received | !busy) ? 0 : cnt_busy + 1;
	end

endmodule
