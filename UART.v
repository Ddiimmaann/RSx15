`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    12:54:00 12/14/2020 
// Design Name: 
// Module Name:    UART 
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
module UART(
   input clk,
	
	// UART receiver
	input rx, // rx pin
	output [7:0] r_byte,
	output reg received = 0,
	
	// UART transmitter
	output reg tx = 1, // tx pin
	input [7:0] t_byte,
	input transmit,
	output reg transmited = 0,
	
	output r_bit, // rx bit output for CRC calc
	output r_bit_re,
	
	output t_bit, // tx bit output for CRC calc
	output t_bit_re
   );

	parameter BCYC = 8; // cycles per bit
	parameter BCYC2 = 4; // bit for cycles counter

	reg [(BCYC2 - 1):0] cnt_r = 0; // cycles counter
	reg [3:0] bit_cnt_r = 0; // bit counter
	
	reg busy_r = 0; // byte reception sequence
	reg rx_t = 0; // delayed rx
	reg [9:0] r_buf = 0; // input buffer
	
	wire start; // byte reception sequence start
	wire bit_r_time; // bit read moment
	
	assign start = !rx & rx_t & !busy_r;
	assign bit_r_time = (cnt_r == (BCYC - 1));
	assign r_byte = r_buf[8:1];
	
	assign r_bit = rx_t;
	assign r_bit_re = bit_r_time & ~(bit_cnt_r == 9) & ~(bit_cnt_r == 0);
	
	// receiver
	always @ (posedge clk) begin
		rx_t <= rx;
		busy_r <= (bit_cnt_r == 10) ? 0 : start ? 1 : busy_r;
		
		cnt_r <= busy_r ? (cnt_r < (BCYC - 1)) ? cnt_r + 1 : 0 : (BCYC / 2);
		bit_cnt_r <= busy_r ? bit_r_time ? bit_cnt_r + 1 : bit_cnt_r : 0;
		
		r_buf <= bit_r_time ? {rx_t, r_buf[9:1]} : r_buf;
		received <= (bit_r_time & (r_buf[1] == 0) & (rx_t == 1)) & (bit_cnt_r == 9);
	end
	
	///////////////////////////////////////////////////////////
	
	reg [(BCYC2 - 1):0] cnt_t = 0; // cycles counter
	reg [3:0] bit_cnt_t = 0; // bit counter
	
	reg busy_t = 0; // byte transmission sequence
	reg [9:0] t_buf = 0; // output buffer
	reg bit_w_time_t = 0;  // bit write moment delayed
	
	wire bit_w_time; // bit write moment
	
	assign bit_w_time = (cnt_t == (BCYC - 1));
	
	assign t_bit = t_buf[1];
	assign t_bit_re = bit_w_time & ~bit_cnt_t[3];
	
	// transmitter
	always @ (posedge clk) begin
		t_buf <= (transmit & !busy_t) ? {1'b1, t_byte, 1'b0} : bit_w_time ? (t_buf >> 1) : t_buf;
		busy_t <= (bit_cnt_t == 10) ? 0 : transmit ? 1 : busy_t;
		
		cnt_t <= busy_t ? (cnt_t < (BCYC - 1)) ? cnt_t + 1 : 0 : 3;
		bit_cnt_t <= busy_t ? bit_w_time ? bit_cnt_t + 1 : bit_cnt_t : 0;
		bit_w_time_t <= bit_w_time;
		
		tx <= busy_t ? bit_w_time ? t_buf[0] : tx : 1;
		transmited <= bit_w_time_t & (bit_cnt_t == 10);
	end

endmodule
