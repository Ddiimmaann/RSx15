`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:02:02 12/20/2020 
// Design Name: 
// Module Name:    main 
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
module main(
	input CLK20MHZ,
	output reg CLK25MHZ = 0,
	
	input [14:0] rx,
	output [14:0] tx,
	
	output [16:0] zero_bus,
	output [30:0] one_bus
	);

	wire clk;
	wire ce;
	
	reg [14:0] rx_b = 0;
	reg [10:0] ce_cnt = 0;
	
	assign zero_bus = {17{1'b0}};
	assign one_bus = {31{1'b1}};
	assign ce = (ce_cnt == 0);
	
	always @ (posedge clk) begin
		CLK25MHZ <= ~CLK25MHZ;
		rx_b <= rx;
		ce_cnt <= ce_cnt + 1;
	end

	pll pll_inst(
		.CLKIN_IN(CLK20MHZ), 
      .RST_IN(0), 
      .CLKFX_OUT(clk), 
      .CLKIN_IBUFG_OUT(), 
      .CLK0_OUT(), 
      .LOCKED_OUT()
	);

	genvar i;
	generate
		for (i = 0; i < 14; i = i + 1) begin : device_gen
			device #(.UART_ADDR(i + 1)) device_inst(
				.clk(clk),
				.ce(ce),
				.rx(rx_b[i]),
				.tx(tx[i])
			);
		end
	endgenerate

	device #(.UART_ADDR(16),
				.BCYC(434),
				.BCYC2(9),
				.TOCNTSIZE(13)) device_inst_115200(
		.clk(clk),
		.ce(ce),
		.rx(rx_b[14]),
		.tx(tx[14])
	);

endmodule
