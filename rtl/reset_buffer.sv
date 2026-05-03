module reset_buffer #(
	parameter TIMER = 50000,
	parameter BOOT_ADDR = 32'h00000080
)(
	input logic clk,
	input logic rst_n,
	
	input logic debug_havereset_o_x,
	input logic debug_running_o_x,
	input logic [31:0] debug_pc_o_x,
	input logic instr_gnt_mem_x,
	input logic data_gnt_mem_x,
	
	input logic debug_havereset_o_s,
	input logic debug_running_o_s,
	input logic [31:0] debug_pc_o_s,
	input logic instr_gnt_mem_s,
	input logic data_gnt_mem_s,

	output logic rst_n_core_s,
	output logic rst_n_core_x,

	output logic [31:0] boot_addr_i_x,
	output logic instr_gnt_i_x,
	output logic data_gnt_i_x,
	output logic fetch_enable_i_x,

	output logic [31:0] boot_addr_i_s,
	output logic instr_gnt_i_s,
	output logic data_gnt_i_s,
	output logic fetch_enable_i_s
);

	localparam RUNNING   = 2'b00;
	localparam RESETTING = 2'b01;
	localparam RESUMING  = 2'b10;

	reg [$clog2(TIMER+1)-1:0] counter;

	reg [31:0] saved_pc_x;
	reg [31:0] saved_pc_s;

	reg [1:0] state;

	always @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			state      <= RESETTING;
			counter    <= TIMER;

			saved_pc_x <= BOOT_ADDR;
			saved_pc_s <= BOOT_ADDR;

			rst_n_core_s <= 0;
			rst_n_core_x <= 0;
			
			instr_gnt_i_x <= 0; 
			instr_gnt_i_s <= 0;

			data_gnt_i_x  <= 0;
			data_gnt_i_s  <= 0;

			fetch_enable_i_x <= 0;
			fetch_enable_i_s <= 0;

			boot_addr_i_x <= BOOT_ADDR;
			boot_addr_i_s <= BOOT_ADDR;
		end else begin
			case(state)
				RUNNING: begin
					if(counter == 0) begin
						saved_pc_x <= debug_pc_o_x;
						saved_pc_s <= debug_pc_o_s;

						instr_gnt_i_x <= 0;
						instr_gnt_i_s <= 0;

						data_gnt_i_x  <= 0;
						data_gnt_i_s  <= 0;

						rst_n_core_s   <= 0;
						rst_n_core_x   <= 0;
						
						state <= RESETTING;
					end else begin
						counter <= counter - 1;
					
						instr_gnt_i_x <= instr_gnt_mem_x;
						instr_gnt_i_s <= instr_gnt_mem_s;

						data_gnt_i_x  <= data_gnt_mem_x;
						data_gnt_i_s  <= data_gnt_mem_s;

						fetch_enable_i_x <= 0;
						fetch_enable_i_s <= 0;
					end
				end

				RESETTING: begin	
					instr_gnt_i_x <= 0;
					instr_gnt_i_s <= 0;

					data_gnt_i_x  <= 0;
					data_gnt_i_s  <= 0;

					rst_n_core_s   <= 0;
					rst_n_core_x   <= 0;

					fetch_enable_i_x <= 0;
					fetch_enable_i_s <= 0;

					boot_addr_i_x <= saved_pc_x;
					boot_addr_i_s <= saved_pc_s;

					if(debug_havereset_o_x && debug_havereset_o_s) begin
						rst_n_core_x  <= 1;
						rst_n_core_s  <= 1;

						state <= RESUMING;
					end 

				end

				RESUMING: begin
					if(debug_running_o_x && debug_running_o_s) begin
						counter <= TIMER;
						
						instr_gnt_i_x <= instr_gnt_mem_x;
						instr_gnt_i_s <= instr_gnt_mem_s;

						data_gnt_i_x  <= data_gnt_mem_x;
						data_gnt_i_s  <= data_gnt_mem_s;

						fetch_enable_i_x <= 0;
						fetch_enable_i_s <= 0;

						state <= RUNNING;
					end else begin
						instr_gnt_i_x <= 0;
						instr_gnt_i_s <= 0;

						data_gnt_i_x  <= 0;
						data_gnt_i_s  <= 0;

						fetch_enable_i_x <= 1;
						fetch_enable_i_s <= 1;
					end
				end

				default: state <= RUNNING;
			endcase
		end
	end

endmodule
