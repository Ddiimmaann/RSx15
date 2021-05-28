`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:26:49 12/20/2020 
// Design Name: 
// Module Name:    device 
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
module device(
   input clk,
	input ce,
	input rx,
	output tx
	);

	parameter UART_ADDR = 8'h01; // device address
	parameter SIDE_CHANNEL = 0; // side channels react to 0xFF dst addr
	parameter TOCNTSIZE = 7; // timeout counter size
	parameter BCYC = 8; // UART cycles per bit
	parameter BCYC2 = 4; // UART bit for cycles counter

	// UART
	wire received;
	wire [7:0] r_byte;
	wire transmit;
	wire transmited;
	wire [7:0] t_byte;
	
	// CRC8 receive
	wire crc8_ce_rx;
	wire crc8_rst_rx;
	wire crc8_xin_rx;
	wire [7:0] crc8_crc_rx;
	
	// CRC8 transmit
	wire crc8_ce_tx;
	wire crc8_rst_tx;
	wire crc8_xin_tx;
	wire [7:0] crc8_crc_tx;
	
	// CRC16 receive
	wire crc16_ce_rx;
	wire crc16_rst_rx;
	wire crc16_stop_rx;
	wire crc16_xin_rx;
	wire [15:0] crc16_crc_rx;
	
	// CRC16 transmit
	wire crc16_ce_tx;
	wire crc16_rst_tx;
	wire crc16_stop_tx;
	wire crc16_xin_tx;
	wire [15:0] crc16_crc_tx;
	
	// mem34
	wire mem34_we;
	wire [7:0] mem34_xout;
	wire [5:0] mem34_addr_w;
	wire [5:0] mem34_addr_r;
	
	// CRC16 logic
	assign crc16_xin_rx = crc8_xin_rx;
	assign crc16_ce_rx = crc8_ce_rx & ~crc16_stop_rx;
	assign crc16_xin_tx = crc8_xin_tx;
	assign crc16_ce_tx = crc8_ce_tx & ~crc16_stop_tx;

	interface #(.UART_ADDR(UART_ADDR),
					.SIDE_CHANNEL(SIDE_CHANNEL),
					.TOCNTSIZE(TOCNTSIZE))
	interface_inst(
		.clk(clk),
		
		// UART
		.received(received),
		.r_byte(r_byte),
		.transmit(transmit),
		.t_byte(t_byte),
		.transmited(transmited),
		
		// CRC
		.crc8(crc8_crc_rx),
		.crc8_rst(crc8_rst_rx),
		.crc8_r(crc8_crc_tx),
		.crc8_r_rst(crc8_rst_tx),
		.crc16(crc16_crc_rx),
		.crc16_rst(crc16_rst_rx),
		.crc16_stop(crc16_stop_rx),
		.crc16_r(crc16_crc_tx),
		.crc16_r_rst(crc16_rst_tx),
		.crc16_r_stop(crc16_stop_tx),
		
		// mem34
		.mem34_xout(mem34_xout),
		.mem34_addr_w(mem34_addr_w),
		.mem34_addr_r(mem34_addr_r),
		.mem34_we(mem34_we)
	);
	
	UART 	#(.BCYC(BCYC),
			  .BCYC2(BCYC2))
	UART_inst(
		.clk(clk),
		
		.rx(rx),
		.r_byte(r_byte),
		.received(received),
		
		.tx(tx),
		.t_byte(t_byte),
		.transmit(transmit),
		.transmited(transmited),
		
		.r_bit(crc8_xin_rx),
		.r_bit_re(crc8_ce_rx),
		
		.t_bit(crc8_xin_tx),
		.t_bit_re(crc8_ce_tx)
   );
	
	crc8 crc8_rx(
		.clk(clk),
		.ce(crc8_ce_rx),
		.rst(crc8_rst_rx),
		.xin(crc8_xin_rx),
		.crc(crc8_crc_rx)
	);
	
	crc8 crc8_tx(
		.clk(clk),
		.ce(crc8_ce_tx),
		.rst(crc8_rst_tx),
		.xin(crc8_xin_tx),
		.crc(crc8_crc_tx)
	);
	
	crc16 crc16_rx(
		.clk(clk),
		.ce(crc16_ce_rx),
		.rst(crc16_rst_rx),
		.xin(crc16_xin_rx),
		.crc(crc16_crc_rx)
	);
	
	crc16 crc16_tx(
		.clk(clk),
		.ce(crc16_ce_tx),
		.rst(crc16_rst_tx),
		.xin(crc16_xin_tx),
		.crc(crc16_crc_tx)
	);

	mem34_logic mem34_logic_inst(
		.clk(clk),
		.ce(ce),
		.mem34_addr_w(mem34_addr_w),
		.mem34_addr_r(mem34_addr_r),
		.mem34_we(mem34_we),
		.r_byte(r_byte),
		.mem34_xout(mem34_xout)
	);
	
endmodule
