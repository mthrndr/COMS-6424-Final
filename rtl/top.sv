module top import cv32e40s_pkg::*;
#(
    parameter                             LIB                                     = 0,
    parameter cv32e40s_pkg::rv32_e                      RV32                                    = RV32I,
    parameter cv32e40s_pkg::b_ext_e                     B_EXT                                   = B_NONE,
    parameter cv32e40s_pkg::m_ext_e                     M_EXT                                   = M,
    parameter bit                         DEBUG                                   = 1,
    parameter logic [31:0]                DM_REGION_START                         = 32'hF0000000,
    parameter logic [31:0]                DM_REGION_END                           = 32'hF0003FFF,
    parameter int                         DBG_NUM_TRIGGERS                        = 1,
    parameter int                         PMA_NUM_REGIONS                         = 0,
    parameter cv32e40s_pkg::pma_cfg_t                   PMA_CFG[PMA_NUM_REGIONS-1:0]            = '{default:PMA_R_DEFAULT},
    parameter bit                         CLIC                                    = 0,
    parameter int unsigned                CLIC_ID_WIDTH                           = 5,
    parameter int unsigned                CLIC_INTTHRESHBITS                      = 8,
    parameter int unsigned                PMP_GRANULARITY                         = 0,
    parameter int                         PMP_NUM_REGIONS                         = 0,
    parameter cv32e40s_pkg::pmpncfg_t                   PMP_PMPNCFG_RV[PMP_NUM_REGIONS-1:0]     = '{default:PMPNCFG_DEFAULT},
    parameter logic [31:0]                PMP_PMPADDR_RV[PMP_NUM_REGIONS-1:0]     = '{default:32'h0},
    parameter cv32e40s_pkg::mseccfg_t                   PMP_MSECCFG_RV                          = MSECCFG_DEFAULT,
    parameter cv32e40s_pkg::lfsr_cfg_t                  LFSR0_CFG                               = LFSR_CFG_DEFAULT, // Do not use default value for LFSR configuration
    parameter cv32e40s_pkg::lfsr_cfg_t                  LFSR1_CFG                               = LFSR_CFG_DEFAULT, // Do not use default value for LFSR configuration
    parameter cv32e40s_pkg::lfsr_cfg_t                  LFSR2_CFG                               = LFSR_CFG_DEFAULT,  // Do not use default value for LFSR configuration
	parameter BOOT_ADDR = 32'h00000080,
    parameter NUM_MHPMCOUNTERS  = 1

)
(
    // Clock and reset
    input  logic                          clk_i,
    input  logic                          rst_ni,
    input  logic                          scan_cg_en_i,   // Enable all clock gates for testing

    // Static configuration
    input  logic [31:0]                   boot_addr_i,
    input  logic [31:0]                   dm_exception_addr_i,
    input  logic [31:0]                   dm_halt_addr_i,
    input  logic [31:0]                   mhartid_i,
    input  logic  [3:0]                   mimpid_patch_i,
    input  logic [31:0]                   mtvec_addr_i,

    // Instruction memory interface
    output logic                          instr_req_o,
    input  logic                          instr_gnt_i,
    input  logic                          instr_rvalid_i,
    output logic [31:0]                   instr_addr_o,
    output logic [1:0]                    instr_memtype_o,
    output logic [2:0]                    instr_prot_o,
    output logic                          instr_dbg_o,
    input  logic [31:0]                   instr_rdata_i,
    input  logic                          instr_err_i,

    output logic                          instr_reqpar_o,         // secure
    input  logic                          instr_gntpar_i,         // secure
    input  logic                          instr_rvalidpar_i,      // secure
    output logic [11:0]                   instr_achk_o,           // secure
    // Handled by MMU
    // input  logic [4:0]                    instr_rchk_i,           // secure

    // Data memory interface
    output logic                          data_req_o,
    input  logic                          data_gnt_i,
    input  logic                          data_rvalid_i,
    output logic [31:0]                   data_addr_o,
    output logic [3:0]                    data_be_o,
    output logic                          data_we_o,
    output logic [31:0]                   data_wdata_o,
    output logic [1:0]                    data_memtype_o,
    output logic [2:0]                    data_prot_o,
    output logic                          data_dbg_o,
    input  logic [31:0]                   data_rdata_i,
    input  logic                          data_err_i,

    output logic                          data_reqpar_o,          // secure
    input  logic                          data_gntpar_i,          // secure
    input  logic                          data_rvalidpar_i,       // secure
    output logic [11:0]                   data_achk_o,            // secure
    // Handled by mmu
    // input  logic [4:0]                    data_rchk_i,            // secure

    // Cycle count
    output logic [63:0]                   mcycle_o,

    // Basic interrupt architecture
    input  logic [31:0]                   irq_i,

    // Event wakeup signals
    input  logic                          wu_wfe_i,   // Wait-for-event wakeup

    // CLIC interrupt architecture
    input  logic                          clic_irq_i,
    input  logic [CLIC_ID_WIDTH-1:0]      clic_irq_id_i,
    input  logic [ 7:0]                   clic_irq_level_i,
    input  logic [ 1:0]                   clic_irq_priv_i,
    input  logic                          clic_irq_shv_i,

    // Fence.i flush handshake
    output logic                          fencei_flush_req_o,
    input  logic                          fencei_flush_ack_i,

      // Security Alerts
    output logic                          alert_minor_o,          // secure
    output logic                          alert_major_o,          // secure

    // Debug interface
    input  logic                          debug_req_i,
    output logic                          debug_havereset_o,
    output logic                          debug_running_o,
    output logic                          debug_halted_o,
    output logic                          debug_pc_valid_o,
    output logic [31:0]                   debug_pc_o,

    // CPU control signals
    // Handled by reset buffer
    input  logic                          fetch_enable_i,
    output logic                          core_sleep_o
);

    logic [31:0] boot_addr_i_s;
    logic [31:0] boot_addr_i_x;
    logic [5:0] data_atop_o_x;
    logic data_err_i_s;
    logic data_err_i_x;
    logic data_exokay_i_x;
    logic [4:0] data_rchk_i_s;
    logic [31:0] data_rdata_i_s;
    logic [31:0] data_rdata_i_x;
    logic data_rdata_reqpar_o_s;
    logic data_reqpar_o_s;
    logic data_rvalid_i_s;
    logic data_rvalid_i_x;
    logic data_rvalidpar_i_s;
    logic fetch_enable_i_s;
    logic fetch_enable_i_x;
    logic [31:0] instr_addr_o_s;
    logic [31:0] instr_addr_o_x;
    logic instr_be_o;
    logic instr_dbg_o_s;
    logic instr_dbg_o_x;
    logic instr_err_i_s;
    logic instr_err_i_x;
    logic [1:0] instr_memtype_o_s;
    logic [1:0] instr_memtype_o_x;
    logic [2:0] instr_prot_o_s;
    logic [2:0] instr_prot_o_x;
    logic [4:0] instr_rchk_i_s;
    logic [31:0] instr_rdata_i_s;
    logic [31:0] instr_rdata_i_x;
    logic instr_req_o_s;
    logic instr_req_o_x;
    logic instr_reqpar_o_s;
    logic instr_rvalid_i_s;
    logic instr_rvalid_i_x;
    logic mmu_mismatch_o;
    logic rst_n_core_s;
    logic rst_n_core_x;
    logic fault_det_comp_o;
    logic core_sleep_o_x;
    logic core_sleep_o_s;
    logic [31:0] debug_pc_o_s;
    logic [31:0] debug_pc_o_x;
    logic debug_pc_valid_o_x;
    logic debug_pc_valid_o_s;
    logic debug_halted_o_s;
    logic debug_halted_o_x;
    logic debug_running_o_x;
    logic debug_running_o_s;
    logic debug_havereset_o_s;
    logic debug_havereset_o_x;
    logic [31:0] data_wdata_o_x;
    logic [31:0] data_wdata_o_s;
    logic data_dbg_o_s;
    logic data_dbg_o_x;
    logic [2:0] data_prot_o_s;
    logic [2:0] data_prot_o_x;
    logic [1:0] data_memtype_o_s;
    logic [1:0] data_memtype_o_x;
    logic [31:0] data_addr_o_x;
    logic [31:0] data_addr_o_s;
    logic [3:0] data_be_o_s;
    logic data_we_o_s;
    logic [3:0] data_be_o_x;
    logic data_we_o_x;
    logic data_req_o_x;
    logic data_req_o_s;
    logic instr_gntpar_i_s;
    logic instr_gntpar_i_s_mmu;
    logic instr_gntpar_i_s_rst;
    logic instr_gnt_i_x;
    logic instr_gnt_i_s;
    logic instr_gnt_i_x_rst;
    logic instr_gnt_i_x_mmu;
    logic instr_gnt_i_s_rst;
    logic instr_gnt_i_s_mmu;
    logic data_gnt_i_x;
    logic data_gnt_i_s;
    logic data_gnt_i_s_mmu;
    logic data_gnt_i_s_rst;
    logic data_gnt_i_x_mmu;
    logic data_gnt_i_x_rst;
    logic data_gntpar_i_s;
    logic data_gntpar_i_s_mmu;
    logic data_gntpar_i_s_rst;

    assign instr_memtype_o = instr_memtype_o_s; // Not sure
    assign data_prot_o = data_prot_o_s; // Not sure



    assign core_sleep_o = core_sleep_o_x | core_sleep_o_s;

    assign data_gnt_i_s     = data_gnt_i_s_mmu | data_gnt_i_s_rst;
    assign data_gntpar_i_s  = data_gntpar_i_s_mmu | data_gntpar_i_s_rst;
    assign instr_gnt_i_s    = instr_gnt_i_s_mmu | instr_gnt_i_s_rst;
    assign instr_gntpar_i_s = instr_gntpar_i_s_mmu | instr_gntpar_i_s_rst;

    // Instantiate the s-core core
    // TO-DO: update all values to be passed down
    cv32e40s_core #(
	    .PMA_NUM_REGIONS	    (PMA_NUM_REGIONS),
        .PMA_CFG                (PMA_CFG),
	    .PMP_NUM_REGIONS	    (PMP_NUM_REGIONS),
        .PMP_PMPNCFG_RV         (PMP_PMPNCFG_RV),
        .PMP_PMPADDR_RV         (PMP_PMPADDR_RV)
  	 )cv32e40s_core_i(
        .clk_i                  ( clk_i                     ),
  	    .rst_ni                 ( rst_n_core_s              ),
  	    .scan_cg_en_i           ( scan_cg_en_i              ),
  
  	    .boot_addr_i            ( boot_addr_i_s             ),
  	    .dm_exception_addr_i    ( dm_exception_addr_i       ),
  	    .dm_halt_addr_i         ( dm_halt_addr_i            ),
  	    .mhartid_i              ( mhartid_i                 ),
  	    .mimpid_patch_i         ( mimpid_patch_i            ),
  	    .mtvec_addr_i           ( mtvec_addr_i              ),
  
  	    .instr_req_o            ( instr_req_o_s             ),
  	    .instr_gnt_i            ( instr_gnt_i_s             ),
  	    .instr_rvalid_i         ( instr_rvalid_i_s          ),
  	    .instr_addr_o           ( instr_addr_o_s            ),
  	    .instr_memtype_o        ( instr_memtype_o_s         ),
	    .instr_prot_o           ( instr_prot_o_s            ),
	    .instr_dbg_o            ( instr_dbg_o_s             ),
	    .instr_rdata_i          ( instr_rdata_i_s           ),
	    .instr_err_i            ( instr_err_i_s             ),
	    .instr_reqpar_o         ( instr_reqpar_o_s          ),
	    .instr_gntpar_i         ( instr_gntpar_i_s          ),
	    .instr_rvalidpar_i      ( instr_rvalidpar_i_s       ),
	    .instr_achk_o           (                           ), // Handled by MMU
	    .instr_rchk_i           ( instr_rchk_i_s           ),

	    .data_req_o             ( data_req_o_s              ),
	    .data_gnt_i             ( data_gnt_i_s              ),
	    .data_rvalid_i          ( data_rvalid_i_s           ),
	    .data_addr_o            ( data_addr_o_s             ),
	    .data_be_o              ( data_be_o_s               ),
    	.data_we_o              ( data_we_o_s               ),
	    .data_wdata_o           ( data_wdata_o_s            ),
	    .data_memtype_o         ( data_memtype_o_s          ),
	    .data_prot_o            ( data_prot_o_s             ),
	    .data_dbg_o             ( data_dbg_o_s              ),
	    .data_rdata_i           ( data_rdata_i_s            ),
	    .data_err_i             ( data_err_i_s              ),
	    .data_reqpar_o          ( data_reqpar_o_s           ),
	    .data_gntpar_i          ( data_gntpar_i_s           ),
	    .data_rvalidpar_i       ( data_rvalidpar_i_s        ),
	    .data_achk_o            (                           ), // Handled by MMU
	    .data_rchk_i            ( data_rchk_i_s            ),

	    .mcycle_o               (                           ),

	    .irq_i                  ( irq_i                     ),
	    .wu_wfe_i               ( wu_wfe_i                  ),
	    .clic_irq_i             ( clic_irq_i                ),
	    .clic_irq_id_i          ( clic_irq_id_i             ),
	    .clic_irq_level_i       ( clic_irq_level_i          ),
	    .clic_irq_priv_i        ( clic_irq_priv_i           ),
	    .clic_irq_shv_i         ( clic_irq_shv_i            ),

	    .fencei_flush_req_o     (                           ),
	    .fencei_flush_ack_i     ( fencei_flush_ack_i        ),

	    .alert_minor_o          (                           ),
	    .alert_major_o          (                           ),

	    .debug_req_i            ( debug_req_i               ),
	    .debug_havereset_o      ( debug_havereset_o_s       ),
	    .debug_running_o        ( debug_running_o_s         ),
	    .debug_halted_o         ( debug_halted_o_s          ),
        .debug_pc_valid_o       ( debug_pc_valid_o_s        ),
        .debug_pc_o             ( debug_pc_o_s              ),

	    .fetch_enable_i         ( fetch_enable_i_s && fetch_enable_i ),
	    .core_sleep_o           ( core_sleep_o_s            )
    );

    // eXtension Interface
    if_xif #(
        .X_NUM_RS    ( 2  ),
        .X_MEM_WIDTH ( 32 ),
        .X_RFR_WIDTH ( 32 ),
        .X_RFW_WIDTH ( 32 ),
        .X_MISA      ( '0 )
    ) ext_if ();

    assign data_gnt_i_x     = data_gnt_i_x_mmu | data_gnt_i_x_rst;
    assign instr_gnt_i_x    = instr_gnt_i_x_mmu | instr_gnt_i_x_rst;

    // Instantiate the x core
    // TO-DO: update all values to be passed down
    cv32e40x_core #(
                .NUM_MHPMCOUNTERS (NUM_MHPMCOUNTERS)
    )cv32e40x_core_i(
        // Clock and Reset
        .clk_i                  ( clk_i                     ),
        .rst_ni                 ( rst_n_core_x              ),

        .scan_cg_en_i           ( scan_cg_en_i              ),

        // Static configuration
        .boot_addr_i            ( boot_addr_i_x             ),
        .dm_exception_addr_i    ( dm_exception_addr_i       ),
        .dm_halt_addr_i         ( dm_halt_addr_i            ),
        .mhartid_i              ( mhartid_i                 ),
        .mimpid_patch_i         ( mimpid_patch_i            ),
        .mtvec_addr_i           ( mtvec_addr_i              ), 
        
        // Instruction memory interface
        .instr_req_o            ( instr_req_o_x             ),
        .instr_gnt_i            ( instr_gnt_i_x             ),
        .instr_rvalid_i         ( instr_rvalid_i_x          ),
        .instr_addr_o           ( instr_addr_o_x            ),
        .instr_memtype_o        ( instr_memtype_o_x         ),
        .instr_prot_o           ( instr_prot_o_x            ),
        .instr_dbg_o            ( instr_dbg_o_x             ),
        .instr_rdata_i          ( instr_rdata_i_x           ),
        .instr_err_i            ( instr_err_i_x             ),

        // Data memory interface
        .data_req_o             ( data_req_o_x              ),
        .data_gnt_i             ( data_gnt_i_x              ),
        .data_rvalid_i          ( data_rvalid_i_x           ),
        .data_addr_o            ( data_addr_o_x             ),
        .data_be_o              ( data_be_o_x               ),
        .data_we_o              ( data_we_o_x               ),
        .data_wdata_o           ( data_wdata_o_x            ),
        .data_memtype_o         ( data_memtype_o_x          ), 
        .data_prot_o            ( data_prot_o_x             ),
        .data_dbg_o             ( data_dbg_o_x              ),
        .data_err_i             ( data_err_i_x              ),
        .data_atop_o            ( data_atop_o_x             ),
        .data_rdata_i           ( data_rdata_i_x            ),
        .data_exokay_i          ( data_exokay_i_x           ),

        // Cycle Count
        .mcycle_o               (                           ),

        // Time input
        .time_i                 ( '0                        ),

        // eXtension interface
        .xif_compressed_if      ( ext_if                    ),
        .xif_issue_if           ( ext_if                    ),
        .xif_commit_if          ( ext_if                    ),
        .xif_mem_if             ( ext_if                    ),
        .xif_mem_result_if      ( ext_if                    ),
        .xif_result_if          ( ext_if                    ),

        // Basic interrupt architecture
        .irq_i                  ( irq_i                     ),

        // Event wakeup signals
        .wu_wfe_i               ( wu_wfe_i                  ),

        .clic_irq_i             ( clic_irq_i                ),
        .clic_irq_id_i          ( clic_irq_id_i             ),
        .clic_irq_level_i       ( clic_irq_level_i          ),
        .clic_irq_priv_i        ( clic_irq_priv_i           ),
        .clic_irq_shv_i         ( clic_irq_shv_i            ),
        
        // Fencei flush handshake
        .fencei_flush_req_o     (                           ),
        .fencei_flush_ack_i     ( fencei_flush_ack_i        ),

        // Debug interface
        .debug_req_i            ( debug_req_i               ),
        .debug_havereset_o      ( debug_havereset_o_x       ),
        .debug_running_o        ( debug_running_o_x         ),
        .debug_halted_o         ( debug_halted_o_x          ),
        .debug_pc_valid_o       ( debug_pc_valid_o_x        ),
        .debug_pc_o             ( debug_pc_o_x              ),

        // CPU Control Signals
        .fetch_enable_i         ( fetch_enable_i_x && fetch_enable_i ),
        .core_sleep_o           ( core_sleep_o_x            )
      );

    // TO-DO: update all values to be passed down
    comparison_unit #(
        .BOOT_ADDR(BOOT_ADDR) // Should be switched to boot_addr_i
    )comparison_unit_i(
        // Standard control
        .clk    (clk_i),
        .rst_n  (rst_ni),

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
        .data_req_o_x       (data_req_o_x),        // Request
        .data_we_o_x        (data_we_o_x),         // Write enable
        .data_be_o_x        (data_be_o_x),         // Byte Enable
        .data_addr_o_x      (data_addr_o_x),       // Data address being accessed
        .data_memtype_o_x   (data_memtype_o_x),    
        .data_prot_o_x      (data_prot_o_x),
        .data_dbg_o_x       (data_dbg_o_x),        // Debug signal that goes high when external debugger is acting
        .data_wdata_o_x     (data_wdata_o_x),
        // input logic [5:0]  data_atop_o_x,

        .data_req_o_s       (data_req_o_s),
        .data_we_o_s        (data_we_o_s),
        .data_be_o_s        (data_be_o_s),
        .data_addr_o_s      (data_addr_o_s),
        .data_memtype_o_s   (data_memtype_o_s),
        .data_prot_o_s      (data_prot_o_s),
        .data_dbg_o_s       (data_dbg_o_s),
        .data_wdata_o_s     (data_wdata_o_s),
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
        .debug_havereset_o_x    (debug_havereset_o_x),
        .debug_running_o_x      (debug_running_o_x),
        .debug_halted_o_x       (debug_halted_o_x),
        .debug_pc_valid_o_x     (debug_pc_valid_o_x), // PC Valid
        .debug_pc_o_x           (debug_pc_o_x), // PC Out
      
        .debug_havereset_o_s    (debug_havereset_o_s),
        .debug_running_o_s      (debug_running_o_s),
        .debug_halted_o_s       (debug_halted_o_s),
        .debug_pc_valid_o_s     (debug_pc_valid_o_s),
        .debug_pc_o_s           (debug_pc_o_s),
      
        // CPU control signals
        .core_sleep_o_x         (core_sleep_o_x),
        .core_sleep_o_s         (core_sleep_o_s),

        // Main untrust flag
        .fault_det              (fault_det_comp_o)
    );

    // TO-DO: update all values to be passed down
    ext_mmu #(
        .ADDR_W             (32),
        .DATA_W             (32),
        .FIFO_DEPTH         (8), //Make this 64 for div heavy programs
        .MAX_OUTSTANDING    (4),
        .DATA_BUS           (1'b0), // D-bus = 1, I-bus = 0 - I-bus on s-core will be weird because of dummy instructions
        .A_EXT_X            (1'b0), // 1 if cv32e40x has A extension
        .ACHK_W             (12),
        .RCHK_W             (5)
    )ext_mmu_instr(
        .clk            (clk_i),
        .rst_n          (rst_ni),

        .x_req          (instr_req_o_x),
        .x_gnt          (instr_gnt_i_x_mmu), // Out
        .x_addr         (instr_addr_o_x),
        .x_we           (), // Does not exist
        .x_be           (), // Does not exist
        .x_wdata        (), // Wdata does not exist for instr
        .x_atop         (), // Does not exist
        .x_prot         (instr_prot_o_x),
        .x_memtype      (instr_memtype_o_x),
        .x_dbg          (instr_dbg_o_x),
        // Output
        .x_rvalid       (instr_rvalid_i_x),
        .x_rdata        (instr_rdata_i_x),
        .x_err          (instr_err_i_x),
        .x_exokay       (), // Does not exist

        .s_req          (instr_req_o_s),
        .s_gnt          (instr_gnt_i_s_mmu), // Out
        .s_addr         (instr_addr_o_s),
        .s_we           (), // Does not exist
        .s_be           (), // Does not exist
        .s_wdata        (), // Does not exist
        .s_prot         (instr_prot_o_s),
        .s_memtype      (instr_memtype_o_s),
        .s_dbg          (instr_dbg_o_s),
        .s_reqpar       (instr_reqpar_o_s),
        .s_achk         (instr_achk_o), // handles it globally
        // Output
        .s_gntpar       (instr_gntpar_i_s_mmu),
        .s_rvalidpar    (instr_rvalidpar_i_s),
        .s_rchk         (instr_rchk_i_s),
        .s_rvalid       (instr_rvalid_i_s),
        .s_rdata        (instr_rdata_i_s),
        .s_err          (instr_err_i_s),

        // All to actual memory
        .m_req          (instr_req_o), // Out
        .m_gnt          (instr_gnt_i), // In
        .m_addr         (instr_addr_o), // Out
        .m_we           (), // Out
        .m_be           (), // Out
        .m_wdata        (), // Does not exist
        .m_rvalid       (instr_rvalid_i), // In
        .m_rdata        (instr_rdata_i), // In

        .mismatch       (), // Out
        .comp_untrust   (fault_det_comp_o) // In
    );

    ext_mmu #(
        .ADDR_W             (32),
        .DATA_W             (32),
        .FIFO_DEPTH         (8), //Make this 64 for div heavy programs
        .MAX_OUTSTANDING    (4),
        .DATA_BUS           (1'b1), // D-bus = 1, I-bus = 0 - I-bus on s-core will be weird because of dummy instructions
        .A_EXT_X            (1'b0), // 1 if cv32e40x has A extension
        .ACHK_W             (12),
        .RCHK_W             (5)
    )ext_mmu_data(
        .clk            (clk_i),
        .rst_n          (rst_ni),

        .x_req          (data_req_o_x),
        .x_gnt          (data_gnt_i_x_mmu), // Out
        .x_addr         (data_addr_o_x),
        .x_we           (data_we_o_x),
        .x_be           (data_be_o_x),
        .x_wdata        (data_wdata_o_x),
        .x_atop         (data_atop_o_x),
        .x_prot         (data_prot_o_x),
        .x_memtype      (data_memtype_o_x),
        .x_dbg          (data_dbg_o_x),
        // Output
        .x_rvalid       (data_rvalid_i_x),
        .x_rdata        (data_rdata_i_x),
        .x_err          (data_err_i_x),
        .x_exokay       (data_exokay_i_x),

        .s_req          (data_req_o_s),
        .s_gnt          (data_gnt_i_s_mmu), // Out
        .s_addr         (data_addr_o_s),
        .s_we           (data_we_o_s),
        .s_be           (data_be_o_s),
        .s_wdata        (data_wdata_o_s),
        .s_prot         (data_prot_o_s),
        .s_memtype      (data_memtype_o_s),
        .s_dbg          (data_dbg_o_s),
        .s_reqpar       (data_reqpar_o_s),
        .s_achk         (data_achk_o), // Handles it globally
        // Output
        .s_gntpar       (data_gntpar_i_s_mmu),
        .s_rvalidpar    (data_rvalidpar_i_s),
        .s_rchk         (data_rchk_i_s),
        .s_rvalid       (data_rvalid_i_s),
        .s_rdata        (data_rdata_i_s),
        .s_err          (data_err_i_s),

        // All to actual memory
        .m_req          (data_req_o), // Out
        .m_gnt          (data_gnt_i), // In
        .m_addr         (data_addr_o), // Out
        .m_we           (data_we_o), // Out
        .m_be           (data_be_o), // Out
        .m_wdata        (data_wdata_o), // Out
        .m_rvalid       (data_rvalid_i), // In
        .m_rdata        (data_rdata_i), // In

        .mismatch       (mmu_mismatch_o), // Out
        .comp_untrust   (fault_det_comp_o) // In
    );

    // TO-DO: update all values to be passed down
    reset_buffer #(
        .TIMER                  (50000),
        .BOOT_ADDR              (BOOT_ADDR) // Should be switched to boot_addr_i
    )reset_buffer_i(
        .clk                    (clk_i),
        .rst_n                  (rst_ni),
        
        //INPUT
        .debug_havereset_o_x    (debug_havereset_o_x),
        .debug_running_o_x      (debug_running_o_x),
        .debug_pc_o_x           (debug_pc_o_x),
        .instr_gnt_mem_x        (instr_gnt_i_x),
        .data_gnt_mem_x         (data_gnt_i_x),
        .debug_pc_valid_o_x     (debug_pc_valid_o_x),
        
        .debug_havereset_o_s    (debug_havereset_o_s),
        .debug_running_o_s      (debug_running_o_s),
        .debug_pc_o_s           (debug_pc_o_s),
        .instr_gnt_mem_s        (instr_gnt_i),
        .data_gnt_mem_s         (data_gnt_i),
        .debug_pc_valid_o_s     (debug_pc_valid_o_s),

        // OUTPUT
        .rst_n_core_s           (rst_n_core_s),
        .rst_n_core_x           (rst_n_core_x),

        .boot_addr_i_x          (boot_addr_i_x),
        .instr_gnt_i_x          (instr_gnt_i_x_rst),
        .data_gnt_i_x           (data_gnt_i_x_rst),
        .fetch_enable_i_x       (fetch_enable_i_x),

        .boot_addr_i_s          (boot_addr_i_s),
        .instr_gnt_i_s          (instr_gnt_i_s_rst),
        .data_gnt_i_s           (data_gnt_i_s_rst),
        .fetch_enable_i_s       (fetch_enable_i_s),
        .instr_gntpar_i_s       (instr_gntpar_i_s_rst),
        .data_gntpar_i_s        (data_gntpar_i_s_rst)
    );

    always_ff @(posedge clk_i) begin
        if (mmu_mismatch_o) begin
            $error("LOCKSTEP MISMATCH DETECTED AT CYCLE %0d!", mcycle_o);
            $finish;
        end
    end

endmodule // top
