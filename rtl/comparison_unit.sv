`define COMPARE_VAR(VAR_NAME) \
    if (VAR_NAME``_x !== VAR_NAME``_s) begin \
        $display("Mismatch at Signal '%s': x=%h, s=%h", `"VAR_NAME`", VAR_NAME``_x, VAR_NAME``_s); \
        raise_fault = 1; \
    end
        
module comparison_unit #(
	parameter BOOT_ADDR = 32'h00000080
)(
    // Standard control
	input logic clk,
    input logic rst_n,

    // Below are inputs to be compares, labeled _x and _s for the two cores
    // respectively. Note that many are labeled _o for output since they are
    // outputs from the actual cores, but we treat them as inputs.
    // There are lines that have no equivalents that are commented out

    // Instruction memory interface
    input logic        instr_req_o_x,
    input logic [31:0] instr_addr_o_x,
    input logic [1:0]  instr_memtype_o_x,
    input logic [2:0]  instr_prot_o_x,
    input logic        instr_dbg_o_x,

    input logic        instr_req_o_s,
    input logic [31:0] instr_addr_o_s,
    input logic [1:0]  instr_memtype_o_s,
    input logic [2:0]  instr_prot_o_s,
    input logic        instr_dbg_o_s,
    // input logic                          instr_reqpar_o_s,         // secure
    // input logic [12:0]                   instr_achk_o_s,           // secure

    // Data memory interface
    input logic        data_req_o_x,
    input logic        data_we_o_x,
    input logic [3:0]  data_be_o_x,
    input logic [31:0] data_addr_o_x,
    input logic [1:0]  data_memtype_o_x,
    input logic [2:0]  data_prot_o_x,
    input logic        data_dbg_o_x,
    // input logic [31:0] data_wdata_o_x,
    // input logic [5:0]  data_atop_o_x,

    input logic        data_req_o_s,
    input logic        data_we_o_s,
    input logic [3:0]  data_be_o_s,
    input logic [31:0] data_addr_o_s,
    input logic [1:0]  data_memtype_o_s,
    input logic [2:0]  data_prot_o_s,
    input logic        data_dbg_o_s,
    // input logic                          data_reqpar_o_s,          // secure
    // input logic [12:0]                   data_achk_o_s,            // secure

    // Cycle count
    input logic [63:0]                   mcycle_o_x,
    input logic [63:0]                   mcycle_o_s,

    // Some interrupt stuff that is only for the coprocessor on the x
    // input logic [11:0] clic_irq_id_o_x,
    // input logic        clic_irq_mode_o_x,
    // input logic        clic_irq_exit_o_x,

    // Fence.i flush handshake
    input logic                          fencei_flush_req_o_x,
    input logic                          fencei_flush_req_o_s,

    // Security Alerts
    // input logic                          alert_minor_o_s,          // secure

    // Debug interface
    input logic                          debug_havereset_o_x,
    input logic                          debug_running_o_x,
    input logic                          debug_halted_o_x,
  
    input logic                          debug_havereset_o_s,
    input logic                          debug_running_o_s,
    input logic                          debug_halted_o_s,
    // input logic                          debug_pc_valid_o_s,
    // input logic [31:0]                   debug_pc_o_s,
  
    // CPU control signals
    input logic                          core_sleep_o_x,
    input logic                          core_sleep_o_s,

    // Main untrust flag
    output logic fault_det
);

    // Two bits for now but we only really need 1
    logic raise_fault;
	localparam RUNNING      = 2'b00;
	localparam FAULT_DET    = 2'b01;

	reg [1:0] state;

	always @(posedge clk or negedge rst_n) begin
	    if(!rst_n) begin
            state <= RUNNING;
            fault_det <= 0;
        end else begin
			case(state)
                RUNNING: begin
                    if(raise_fault)begin
                        state <= FAULT_DET;
                        fault_det <= 1;
                    end
                        
                end
                FAULT_DET: begin
                    fault_det <= 1;
                    state <= FAULT_DET;
                    // There should be no way out of this save resetting!
                end
                // Not 100% sure about this or if there should be some startup
                // phase where output isn't yet "verified"?
				default: state <= RUNNING;
            endcase
        end
    end

    always_comb begin
        // Instruction memory interface
        `COMPARE_VAR(instr_req_o)
        `COMPARE_VAR(instr_addr_o)
        `COMPARE_VAR(instr_memtype_o)
        `COMPARE_VAR(instr_prot_o)
        `COMPARE_VAR(instr_dbg_o)

        // `COMPARE_VAR(instr_reqpar_o_s)         // secure
        // `COMPARE_VAR(instr_achk_o_s)           // secure

        // Data memory interface
        `COMPARE_VAR(data_req_o)
        `COMPARE_VAR(data_we_o)
        `COMPARE_VAR(data_be_o)
        `COMPARE_VAR(data_addr_o)
        `COMPARE_VAR(data_memtype_o)
        `COMPARE_VAR(data_prot_o)
        `COMPARE_VAR(data_dbg_o)
        // `COMPARE_VAR(data_wdata_o)
        // `COMPARE_VAR(data_atop_o)

        // `COMPARE_VAR(data_reqpar_o_s)          // secure
        // `COMPARE_VAR(data_achk_o_s)            // secure

        // Cycle count
        `COMPARE_VAR(mcycle_o)

        // Some interrupt stuff that is only for the coprocessor on the x
        // `COMPARE_VAR(clic_irq_id_o)
        // `COMPARE_VAR(clic_irq_mode_o)
        // `COMPARE_VAR(clic_irq_exit_o)

        // Fence.i flush handshake
        `COMPARE_VAR(fencei_flush_req_o)

        // Security Alerts
        // `COMPARE_VAR(alert_minor_o_s)          // secure

        // Debug interface
        `COMPARE_VAR(debug_havereset_o)
        `COMPARE_VAR(debug_running_o)
        `COMPARE_VAR(debug_halted_o)
  
        // `COMPARE_VAR(debug_pc_valid_o_s)
        // `COMPARE_VAR(debug_pc_o_s)
  
        // CPU control signals
        `COMPARE_VAR(core_sleep_o)
    end


endmodule
