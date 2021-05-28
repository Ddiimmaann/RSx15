`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:40:38 12/14/2020 
// Design Name: 
// Module Name:    interface 
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
module interface(
	input clk,
	
	// UART
	input received,
	input [7:0] r_byte,
	output transmit,
	output reg [7:0] t_byte,
	input transmited,
	
	// CRC
	input [7:0] crc8, // UART rx CRC8
	output crc8_rst, // CRC8 reset
	
	input [7:0] crc8_r, // UART tx CRC8 (responce)
	output crc8_r_rst, // CRC8 reset
	
	input [15:0] crc16, // DATA rx CRC16
	output crc16_rst, // CRC16 reset
	output crc16_stop, // CRC16 clock disable
	
	input [15:0] crc16_r, // DATA tx CRC16 (responce)
	output crc16_r_rst, // CRC16 reset
	output crc16_r_stop, // CRC16 clock disable
	
	// mem34
	input [7:0] mem34_xout,
	output [5:0] mem34_addr_w,
	output [5:0] mem34_addr_r,
	output mem34_we
	);

	reg [7:0] uart_addr_r = 0;
	
	parameter UART_ADDR = 8'h01; // device address
	parameter SIDE_CHANNEL = 0; // side channels react to 0xFF dst addr
	parameter TOCNTSIZE = 7; // timeout counter size
	
	// state machine
	localparam STATE_NUM = 12; // number of states
	localparam CH0 = 0, CH1 = 3; // check byte
	localparam SV0 = 1, SV1 = 5; // save byte
	localparam DATAN = 2, CRC8 = 4, ADDR = 6, CMD = 7, READ = 8, WRITE = 9;
	localparam CRC16 = 10, IDLE = 11;
	
	reg [(STATE_NUM - 1):0] state_mask = 1; // state reg (bit for each state)
	reg [(STATE_NUM - 1):0] next_state; // next state_mask wire
	
	// mems and addresses
	reg [7:0] check_mem [0:3]; // compare received bytes to this mem
	reg [7:0] save_mem [0:7]; // save received bytes to form response
	
	reg [1:0] check_mem_addr = 0; // check mem counter
	reg [2:0] save_mem_addr = 0; // write counter
	
	initial begin // according to protocol
		check_mem[0] = 8'h00;
		check_mem[1] = UART_ADDR;
		check_mem[2] = 8'h00;
		check_mem[3] = 8'h03;
	end
	
	// parameters from message
	reg [7:0] data_size = 0; // X + 7
	reg [7:0] data_size_r = 0; // data size to read from internal mem
	reg [7:0] data_addr = 0; // starting address (internal mem)
	reg [7:0] data_addr_s = 0; // starting address saved
	reg [7:0] data_addr_r = 0; // starting address for read operation
	reg cmd = 0; // 1 - read, 0 - write
	
	// additional logic
	wire timeout; // turns on for a cycle in the gap beetwen packets
	wire check_state; // time to compare bytes with check_mem
	wire save_state; // time to save bytes in save_mem
	wire data_field; // data field of the message (protocol)
	
	// errors
	reg error_h = 0; // header error (const bytes, dst addr, crc8)
	reg error_crc16 = 0; // CRC16 error
	reg crc16_b = 0; // first byte / second byte
	
	wire check_mem_err; // const bytes or dst addr error
	wire crc8_err; 
	wire crc16_LSB_err;
	wire crc16_MSB_err;
	wire broadcast_addr; // broadcast received by side channel -> denie dst addr error
	
	// additional logic
	assign crc8_rst = timeout;
	assign crc16_rst = state_mask[CRC8] & received;
	assign crc16_stop = state_mask[CRC16];
	
	assign mem34_addr_w = data_addr[5:0];
	assign mem34_addr_r = data_addr_r[5:0];
	assign mem34_we = received & state_mask[WRITE] & ~error_h;
	
	assign check_state = state_mask[CH0] | state_mask[CH1];
	assign save_state = state_mask[SV0] | state_mask[SV1];
	assign data_field = state_mask[SV1] | state_mask[ADDR] | state_mask[CMD] | 
													state_mask[READ] | state_mask[WRITE];
		
	// errors
	assign broadcast_addr = state_mask[CH0] & check_mem_addr[0]; // do not check device address
	assign check_mem_err = ~broadcast_addr & check_state & (r_byte != check_mem[check_mem_addr]);
	assign crc8_err = state_mask[CRC8] & (crc8 != 8'h00);
	assign crc16_LSB_err = state_mask[CRC16] & ~crc16_b & (r_byte != crc16[7:0]);
	assign crc16_MSB_err = state_mask[CRC16] & crc16_b & (r_byte != crc16[15:8]);
	
	// state outputs for input message
	always @ (posedge clk)
		if (timeout) begin // reset state, counters and errors after 16 stop bits (message timeout)
			state_mask <= {{(STATE_NUM - 1){1'b0}}, 1'b1};
			check_mem_addr <= 0;
			save_mem_addr <= 0;
			crc16_b <= 0;
			error_h <= 0;
			error_crc16 <= 0;
		end else
			if (received) begin // perform each byte reception
				state_mask <= next_state;
				
				// mems and addresses
				check_mem_addr <= check_state ? check_mem_addr + 1 : check_mem_addr;
				save_mem_addr <= save_state ? save_mem_addr + 1 : save_mem_addr;
				save_mem[save_mem_addr] <= save_state ? (save_mem_addr == 2) ? r_byte + 1 : r_byte : save_mem[save_mem_addr];
				
				// message data
				data_addr <= state_mask[ADDR] ? r_byte : state_mask[WRITE] ? data_addr + 1 : data_addr;
				data_addr_s <= state_mask[ADDR] ? r_byte : data_addr_s;
				cmd <= state_mask[CMD] ? r_byte[7] : cmd;
				data_size_r <= (state_mask[READ] & ~(data_size == 1)) ? r_byte : data_size_r;
				data_size <= state_mask[DATAN] ? r_byte : data_field ? data_size - 1 : data_size;
				crc16_b <= state_mask[CRC16] ? crc16_b + 1 : crc16_b;
				
				// errors
				error_h <= (check_mem_err | crc8_err) ? 1 : error_h;
				error_crc16 <= (crc16_LSB_err | crc16_MSB_err) ? 1 : error_crc16;
				
				// uart_addr_r
				uart_addr_r <= broadcast_addr ? r_byte : uart_addr_r;
			end
			
	// state change
	always @ (*) begin
		next_state = {STATE_NUM{1'b0}};
		case (1'b1) // synopsys parallel_case full_case
			state_mask[CH0]: // check first 2 bytes
				if (check_mem_addr[0])
					next_state[SV0] = 1;
				else
					next_state[CH0] = 1;

			state_mask[SV0]: // save source address
				next_state[DATAN] = 1;

			state_mask[DATAN]: // number of data bytes
				next_state[CH1] = 1;

			state_mask[CH1]: // check another 2 bytes
				if (check_mem_addr[0])
					next_state[CRC8] = 1;
				else
					next_state[CH1] = 1;

			state_mask[CRC8]: // verify header CRC8
				next_state[SV1] = 1;

			state_mask[SV1]: // save first 7 data bytes
				if (save_mem_addr == 7)
					next_state[ADDR] = 1;
				else
					next_state[SV1] = 1;

			state_mask[ADDR]: // starting address (internal mem)
				next_state[CMD] = 1;

			state_mask[CMD]: // command 1 - read, 0 - write
				if (r_byte[7])
					next_state[READ] = 1;
				else
					next_state[WRITE] = 1;

			state_mask[READ]: // read operation - save amount of bytes to be read
				if (data_size == 1)
					next_state[CRC16] = 1;
				else
					next_state[READ] = 1;

			state_mask[WRITE]: // write operation - save incoming bytes in the mem
				if (data_size == 1)
					next_state[CRC16] = 1;
				else
					next_state[WRITE] = 1;

			state_mask[CRC16]: // verify data CRC16
				if (crc16_b)
					next_state[IDLE] = 1;
				else
					next_state[CRC16] = 1;
				
			state_mask[IDLE]: // wait for timeout beetwen messages
				next_state[IDLE] = 1;
		endcase
	end
	
	// response state machine
	localparam STATE_NUM_R = 12; // number of states
	localparam CH0_R = 0, CH1_R = 2, CH2_R = 4; // send byte from check mem
	localparam SV0_R = 1, SV1_R = 6; // send byte from save mem
	localparam DATAN_R = 3, CRC8_R = 5, ADDR_R = 7, CMD_R = 8, READ_R = 9;
	localparam CRC16_R = 10, IDLE_R = 11;
	
	reg [(STATE_NUM_R - 1):0] state_mask_r = 1; // state reg (bit for each state)
	reg [(STATE_NUM_R - 1):0] next_state_r; // next state_mask wire
	
	// mems and addresses
	reg [7:0] check_mem_r = 0; // read register (store read value)
	reg [7:0] save_mem_r = 0; // read register (store read value)
	reg [1:0] check_mem_addr_r = 0; // read counter
	reg [2:0] save_mem_addr_r = 0; // read counter
	
	// parameters from message
	reg [7:0] data_size_r_r = 0; // data size to read from internal mem
	
	// additional logic
	reg transmited_t = 0; // next transmission should start next cycle after transmited
	reg state_idle_t = 0; // change trigger to start response sequence
	reg start_r = 0; // start response sequence
	reg crc16_b_r = 0; // first byte / second byte
	
	wire check_state_r; // time to send bytes from check_mem
	wire save_state_r; // time to send bytes from save_mem

	assign crc8_r_rst = start_r;
	assign crc16_r_rst = (save_mem_addr_r == 3'b001) & transmited_t;
	assign crc16_r_stop = state_mask_r[CRC16_R] & crc16_b_r;

	assign transmit = (transmited_t | start_r) & ~state_mask_r[IDLE_R];
	assign check_state_r = state_mask_r[CH0_R] | state_mask_r[CH1_R] | state_mask_r[CH2_R];
	assign save_state_r = state_mask_r[SV0_R] | state_mask_r[SV1_R];
	
	always @ (posedge clk) begin
		// start response sequence after message is received without errors
		transmited_t <= transmited;
		state_idle_t <= state_mask[IDLE];
		start_r <= state_mask[IDLE] & ~state_idle_t & ~error_h & ~error_crc16;
		
		// mem read register (ram mem organization)
		check_mem_r <= check_mem[check_mem_addr_r];
		save_mem_r <= save_mem[save_mem_addr_r];
	end
	
	// state outputs for output message
	always @ (posedge clk)  // reset state and counters after crc16 transmission
		if (transmited_t & state_mask_r[IDLE_R]) begin
			state_mask_r <= {{(STATE_NUM_R - 1){1'b0}}, 1'b1};
			check_mem_addr_r <= 0;
			save_mem_addr_r <= 0;
			crc16_b_r <= 0;
		end else
			if (start_r | transmited_t) begin // perform after each byte transmission
				state_mask_r <= next_state_r;
				
				// mem addresses
				check_mem_addr_r <= check_state_r ? check_mem_addr_r + 1 : check_mem_addr_r;
				save_mem_addr_r <= save_state_r ? save_mem_addr_r + 1 : save_mem_addr_r;
				
				// message data from mem34
				data_size_r_r <= start_r ? data_size_r : state_mask_r[READ_R] ? data_size_r_r - 1 : data_size_r_r;
				data_addr_r <= start_r ? data_addr : state_mask_r[READ_R] ? data_addr_r + 1 : data_addr_r;
				
				crc16_b_r <= state_mask_r[CRC16_R] ? crc16_b_r + 1 : crc16_b_r;
			end
			
	// state change and t_byte
	always @ (*) begin
		next_state_r = {STATE_NUM_R{1'b0}};
		t_byte = 8'h00;
		case (1'b1) // synopsys parallel_case full_case
			state_mask_r[CH0_R]: begin // first byte is const
				next_state_r[SV0_R] = 1;
				t_byte = check_mem_r;
			end

			state_mask_r[SV0_R]: begin // dst addr as received src
				next_state_r[CH1_R] = 1;
				t_byte = save_mem_r;
			end

			state_mask_r[CH1_R]: begin // device address
				next_state_r[DATAN_R] = 1;
				t_byte = uart_addr_r;
			end

			state_mask_r[DATAN_R]: begin // data size depends on the cmd (read - 9 + ? / write - 9)
				next_state_r[CH2_R] = 1;
				if (cmd)
					t_byte = 9 + data_size_r_r;
				else
					t_byte = 9;
			end

			state_mask_r[CH2_R]: begin // constant byte
				if (check_mem_addr_r[0])
					next_state_r[CRC8_R] = 1;
				else
					next_state_r[CH2_R] = 1;
				t_byte = check_mem_r;
			end

			state_mask_r[CRC8_R]: begin // header CRC8
				next_state_r[SV1_R] = 1;
				t_byte = crc8_r;
			end

			state_mask_r[SV1_R]: begin // 7 bytes as in received message
				if (save_mem_addr_r == 7)
					next_state_r[ADDR_R] = 1;
				else
					next_state_r[SV1_R] = 1;
				t_byte = save_mem_r;
			end
			
			state_mask_r[ADDR_R]: begin // address as received
				next_state_r[CMD_R] = 1;
				t_byte = data_addr_s;
			end
			
			state_mask_r[CMD_R]: begin // cmd as received
				if (cmd)
					next_state_r[READ_R] = 1;
				else
					next_state_r[CRC16_R] = 1;
				t_byte = {cmd, 7'b0000000};
			end
			
			state_mask_r[READ_R]: begin // read mem34 if cmd is read
				if (data_size_r_r == 1)
					next_state_r[CRC16_R] = 1;
				else
					next_state_r[READ_R] = 1;
				t_byte = mem34_xout;
			end
			
			state_mask_r[CRC16_R]: begin // data CRC16
				if (crc16_b_r) begin
					next_state_r[IDLE_R] = 1;
					t_byte = crc16_r[15:8];
				end else begin
					next_state_r[CRC16_R] = 1;
					t_byte = crc16_r[7:0];
				end
			end
			
			state_mask_r[IDLE_R]: begin // IDLE up to last byte transmission
				next_state_r[IDLE_R] = 1;
			end
		endcase
	end
	
	timeout #(.TOCNTSIZE(TOCNTSIZE)) timeout_inst (
		.clk(clk),
		.received(received),
		.busy(),
		.timeout(timeout));

endmodule
