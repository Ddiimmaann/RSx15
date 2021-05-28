`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:47:55 01/28/2021 
// Design Name: 
// Module Name:    mem34_logic 
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
module mem34_logic(
	input clk,
	input ce,
	input [5:0] mem34_addr_w,
	input [5:0] mem34_addr_r,
	input mem34_we,
	input [7:0] r_byte,
	output [7:0] mem34_xout
	);

	reg [1:0] replace = 0;
	reg [1:0] dev_on = 0;
	reg [1:0] freq_lock = 1;
	reg [7:0] new_freq_1 = 0;
	reg [7:0] new_freq_2 = 0;
	reg [7:0] freq_diff_1 = 0;
	reg [7:0] freq_diff_2 = 0;
	reg busy_1 = 0;
	reg busy_2 = 0;
	reg [3:0] mem34_we_t = 0;
	
	wire [7:0] mem34_xout_w;
	wire [7:0] mem34_xout_r;
	
	assign mem34_xout = replace[0] ? {mem34_xout_r[7], dev_on[0], freq_lock[0], mem34_xout_r[4:0]} :
								replace[1] ? {mem34_xout_r[7], dev_on[1], freq_lock[1], mem34_xout_r[4:0]} :
								mem34_xout_r;
	
	// insert true state bits: dev_on and freq_lock
	always @ (posedge clk) begin
		if (mem34_addr_r[5:1] == 0)
			replace <= mem34_addr_r[0] ? 2'b10 : 2'b01;
		else
			replace <= 2'b00;
	end
	
	// dev_on
	always @ (posedge clk) begin
		if (mem34_we & mem34_addr_w[5:3] == 0 & mem34_addr_w[2:1] == 0)
			dev_on <= mem34_addr_w[0] ? {r_byte[7], dev_on[0]} : {dev_on[1], r_byte[7]};
		else
			dev_on <= dev_on;
	end
	
	// freq_lock
	always @ (posedge clk) begin
		if (mem34_we & mem34_addr_w[5:3] == 0) begin
			case (mem34_addr_w[2:0])
				2: begin
					new_freq_1 <= {2'b00, r_byte[7:2]};
					mem34_we_t <= 4'b0001;
				end
				3: begin
					new_freq_1[7:6] <= r_byte[1:0];
					mem34_we_t <= 4'b0010;
				end
				4: begin
					new_freq_2 <= {2'b00, r_byte[7:2]};
					mem34_we_t <= 4'b0100;
				end
				5: begin
					new_freq_2[7:6] <= r_byte[1:0];
					mem34_we_t <= 4'b1000;
				end
				default: begin
					mem34_we_t <= 0;
				end
			endcase
		end else begin
			mem34_we_t <= 0;
			
			busy_1 <= mem34_we_t[1] ? 1 : (freq_diff_1 == 0) ? 0 : busy_1;
			if (mem34_we_t[0])
				freq_diff_1 <= {2'b00, mem34_xout_w[7:2]};
			else
				if (mem34_we_t[1])
					freq_diff_1 <= new_freq_1 - {mem34_xout_w[1:0], freq_diff_1[5:0]};
				else
					freq_diff_1 <= (busy_1 & ce) ? freq_diff_1[7] ? freq_diff_1 + 1 : freq_diff_1 - 1 : freq_diff_1;
					
			busy_2 <= mem34_we_t[3] ? 1 : (freq_diff_2 == 0) ? 0 : busy_2;
			if (mem34_we_t[2])
				freq_diff_2 <= {2'b00, mem34_xout_w[7:2]};
			else
				if (mem34_we_t[3])
					freq_diff_2 <= new_freq_2 - {mem34_xout_w[1:0], freq_diff_2[5:0]};
				else
					freq_diff_2 <= (busy_2 & ce) ? freq_diff_2[7] ? freq_diff_2 + 1 : freq_diff_2 - 1 : freq_diff_2;
					
			freq_lock[0] <= mem34_we_t[0] ? 1 : (busy_1 & (freq_diff_1 == 0)) ? 0 : freq_lock[0];
			freq_lock[1] <= mem34_we_t[2] ? 1 : (busy_2 & (freq_diff_2 == 0)) ? 0 : freq_lock[1];
		end
	end
	
	blk_mem_gen_v7_3 mem34_inst(
		.clka(clk),
		.clkb(clk),
		.addra(mem34_addr_w),
		.addrb(mem34_addr_r),
		.dina(r_byte),
		.dinb(),
		.wea(mem34_we),
		.web(),
		.douta(mem34_xout_w),
		.doutb(mem34_xout_r)
	);

endmodule
