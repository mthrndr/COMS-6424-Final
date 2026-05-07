// Simple caprison between variables that end in _x and _s
`define COMPARE_VAR(VAR_NAME) \
    if (VAR_NAME``_x !== VAR_NAME``_s) begin \
        $display("Mismatch at Signal '%s': x=%h, s=%h", `"VAR_NAME`", VAR_NAME``_x, VAR_NAME``_s); \
        raise_fault = 1; \
    end

`define COMPARE_STRUCT_VAR(STRUCT_NAME, VAR_NAME) \
    if (STRUCT_NAME``_x.VAR_NAME !== STRUCT_NAME``_s.VAR_NAME) begin \
        $display("Mismatch at Signal '%s': x=%h, s=%h", `"VAR_NAME`", STRUCT_NAME``_x.VAR_NAME, STRUCT_NAME``_s.VAR_NAME); \
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
    // Instruction fetching is also speculative, and will not line up the same
    // way output does.
    // input logic        instr_req_o_x,
    // input logic [31:0] instr_addr_o_x,
    // input logic [1:0]  instr_memtype_o_x,
    // input logic [2:0]  instr_prot_o_x,
    // input logic        instr_dbg_o_x,

    // input logic        instr_req_o_s,
    // input logic [31:0] instr_addr_o_s,
    // input logic [1:0]  instr_memtype_o_s,
    // input logic [2:0]  instr_prot_o_s,
    // input logic        instr_dbg_o_s,
    // input logic                          instr_reqpar_o_s,         // secure
    // input logic [12:0]                   instr_achk_o_s,           // secure

    // Data memory interface
    input logic        data_req_o_x,        // Request
    input logic        data_we_o_x,         // Write enable
    input logic [3:0]  data_be_o_x,         // Byte Enable
    input logic [31:0] data_addr_o_x,       // Data address being accessed
    input logic [1:0]  data_memtype_o_x,    
    input logic [2:0]  data_prot_o_x,
    input logic        data_dbg_o_x,        // Debug signal that goes high when external debugger is acting
    input logic [31:0] data_wdata_o_x,
    // input logic [5:0]  data_atop_o_x,

    input logic        data_req_o_s,
    input logic        data_we_o_s,
    input logic [3:0]  data_be_o_s,
    input logic [31:0] data_addr_o_s,
    input logic [1:0]  data_memtype_o_s,
    input logic [2:0]  data_prot_o_s,
    input logic        data_dbg_o_s,
    input logic [31:0] data_wdata_o_s,
    // input logic                          data_reqpar_o_s,          // secure
    // input logic [12:0]                   data_achk_o_s,            // secure

    // Cycle count
    // S core will likely have a higher cycle count, ignore
    // input logic [63:0]                   mcycle_o_x,
    // input logic [63:0]                   mcycle_o_s,

    // Some interrupt stuff that is only for the coprocessor on the x
    // input logic [11:0] clic_irq_id_o_x,
    // input logic        clic_irq_mode_o_x,
    // input logic        clic_irq_exit_o_x,

    // Fence.i flush handshake
    // Again due to different depths these may have different timings
    // Could add an additional fifo but not sure how...
    // input logic                          fencei_flush_req_o_x,
    // input logic                          fencei_flush_req_o_s,

    // Security Alerts
    // input logic                          alert_minor_o_s,          // secure

    // Debug interface
    input logic                          debug_havereset_o_x,
    input logic                          debug_running_o_x,
    input logic                          debug_halted_o_x,
    input logic                          debug_pc_valid_o_x, // PC Valid
    input logic [31:0]                   debug_pc_o_x, // PC Out
  
    input logic                          debug_havereset_o_s,
    input logic                          debug_running_o_s,
    input logic                          debug_halted_o_s,
    input logic                          debug_pc_valid_o_s,
    input logic [31:0]                   debug_pc_o_s,
  
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

    // Struct for data FIFOs, width of 69
    typedef struct packed {
        logic [2:0]     prot;
        logic [1:0]     memtype;
        logic [3:0]     be;
        logic [31:0]    addr;
        logic [31:0]    wdata;
        logic           dbg;
    } fifo_data_t;

    // Various wires
    // Not currently using full
    logic fifo_pc_full_x;
    logic fifo_pc_full_s;
    logic fifo_pc_empty_x;
    logic fifo_pc_empty_s;
    logic [31:0] fifo_pc_out_x;
    logic [31:0] fifo_pc_out_s;
    logic fifo_data_full_x;
    logic fifo_data_full_s;
    logic fifo_data_empty_x;
    logic fifo_data_empty_s;
    fifo_data_t fifo_data_out_x; 
    fifo_data_t fifo_data_out_s; 

    logic compare_pc_trigger;
    logic compare_data_trigger;

    fifo #(.WIDTH(32), .DEPTH(16)) fifo_pc_x (
        .clk(clk),
        .rst_n(rst_n),
        .w_en(debug_pc_valid_o_x),  // Write to the PC fifo when a valid PC is sent
        .r_en(compare_pc_trigger),
        .d_in(debug_pc_o_x),
        .d_out(fifo_pc_out_x),
        .empty(fifo_pc_empty_x),
        .full(fifo_pc_full_x)
    );

    fifo #(.WIDTH(74), .DEPTH(16)) fifo_data_x (
        .clk(clk),
        .rst_n(rst_n),
        .w_en(data_req_o_x && data_we_o_x), // Write to the data fifo when a write data request is sent
        .r_en(compare_data_trigger),
        .d_in(fifo_data_t'{
            prot:       data_prot_o_x,
            memtype:    data_memtype_o_x,
            be:         data_be_o_x,
            addr:       data_addr_o_x,
            wdata:      data_wdata_o_x,
            dbg:        data_dbg_o_x
        }),
        .d_out(fifo_data_out_x),
        .empty(fifo_data_empty_x),
        .full(fifo_data_full_x)
    );

    fifo #(.WIDTH(32), .DEPTH(16)) fifo_pc_s (
        .clk(clk),
        .rst_n(rst_n),
        .w_en(debug_pc_valid_o_s),  // Write to the PC fifo when a valid PC is sent
        .r_en(compare_pc_trigger),
        .d_in(debug_pc_o_s),
        .d_out(fifo_pc_out_s),
        .empty(fifo_pc_empty_s),
        .full(fifo_pc_full_s)
    );

    fifo #(.WIDTH(74), .DEPTH(16)) fifo_data_s (
        .clk(clk),
        .rst_n(rst_n),
        .w_en(data_req_o_s && data_we_o_s), // Write to the data fifo when a write data request is sent
        .r_en(compare_data_trigger),
        .d_in(fifo_data_t'{
            prot:       data_prot_o_s,
            memtype:    data_memtype_o_s,
            be:         data_be_o_s,
            addr:       data_addr_o_s,
            wdata:      data_wdata_o_s,
            dbg:        data_dbg_o_s
        }),
        .d_out(fifo_data_out_s),
        .empty(fifo_data_empty_s),
        .full(fifo_data_full_s)
    );

    // Trigger compares when neither fifo of a type is empty
    assign compare_pc_trigger   = ~fifo_pc_empty_x & ~fifo_pc_empty_s;
    assign compare_data_trigger = ~fifo_data_empty_x & ~fifo_data_empty_s;

	always @(posedge clk or negedge rst_n) begin
	    if(!rst_n) begin
            state       <= RUNNING;
            fault_det   <= 0;
        end else begin
			case(state)
                RUNNING: begin
                    if(raise_fault)begin
                        state       <= FAULT_DET;
                        fault_det   <= 1;
                    end
                        
                end
                FAULT_DET: begin
                    fault_det   <= 1;
                    state       <= FAULT_DET;
                    // There should be no way out of this save resetting!
                end
                // Not 100% sure about this or if there should be some startup
                // phase where output isn't yet "verified"?
				default: state <= RUNNING;
            endcase
        end
    end

    always_comb begin
        if(!rst_n) begin
            raise_fault = 0;
        end else begin
            raise_fault = 0;

            if (compare_pc_trigger) begin
                `COMPARE_VAR(fifo_pc_out)
            end

            if (compare_data_trigger) begin
                `COMPARE_STRUCT_VAR(fifo_data_out, addr)
                `COMPARE_STRUCT_VAR(fifo_data_out, wdata)
                `COMPARE_STRUCT_VAR(fifo_data_out, be)
                `COMPARE_STRUCT_VAR(fifo_data_out, prot)
                `COMPARE_STRUCT_VAR(fifo_data_out, memtype)
                `COMPARE_STRUCT_VAR(fifo_data_out, dbg)
            end
        end
    end


endmodule
