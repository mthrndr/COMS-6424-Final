module reset_buffer(
	input logic clk,
	input logic rst_n,
	
	input logic debug_havereset_o_x,
	input logic debug_running_o_x,
	input logic [31:0] debug_pc_o_x,
	
	input logic debug_havereset_o_s,
	input logic debug_running_o_s,
	input logic [31:0] debug_pc_o_s,

	output logic rst_n_cores,

	output logic [31:0] boot_addr_i_x,
	output logic instr_gnt_i_x,
	output logic data_gnt_i_x,

	output logic [31:0] boot_addr_i_s,
	output logic instr_gnt_i_s,
	output logic data_gnt_i_s
);

	localparam RUNNING   = 2'b00;
	localparam RESETTING = 2'b01;
	localparam RESUMING  = 2'b10;

	localparam timer = 16'd50000;

	reg [15:0] counter;

	reg [31:0] saved_pc_x;
	reg [31:0] saved_pc_s;

	reg [1:0] state;

	//TODO: FSM

endmodule
