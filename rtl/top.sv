module top import cv32e40s_pkg::*;
#(
  parameter                             LIB                                     = 0,
  parameter rv32_e                      RV32                                    = RV32I,
  parameter b_ext_e                     B_EXT                                   = B_NONE,
  parameter m_ext_e                     M_EXT                                   = M,
  parameter bit                         DEBUG                                   = 1,
  parameter logic [31:0]                DM_REGION_START                         = 32'hF0000000,
  parameter logic [31:0]                DM_REGION_END                           = 32'hF0003FFF,
  parameter int                         DBG_NUM_TRIGGERS                        = 1,
  parameter int                         PMA_NUM_REGIONS                         = 0,
  parameter pma_cfg_t                   PMA_CFG[PMA_NUM_REGIONS-1:0]            = '{default:PMA_R_DEFAULT},
  parameter bit                         CLIC                                    = 0,
  parameter int unsigned                CLIC_ID_WIDTH                           = 5,
  parameter int unsigned                CLIC_INTTHRESHBITS                      = 8,
  parameter int unsigned                PMP_GRANULARITY                         = 0,
  parameter int                         PMP_NUM_REGIONS                         = 0,
  parameter pmpncfg_t                   PMP_PMPNCFG_RV[PMP_NUM_REGIONS-1:0]     = '{default:PMPNCFG_DEFAULT},
  parameter logic [31:0]                PMP_PMPADDR_RV[PMP_NUM_REGIONS-1:0]     = '{default:32'h0},
  parameter mseccfg_t                   PMP_MSECCFG_RV                          = MSECCFG_DEFAULT,
  parameter lfsr_cfg_t                  LFSR0_CFG                               = LFSR_CFG_DEFAULT, // Do not use default value for LFSR configuration
  parameter lfsr_cfg_t                  LFSR1_CFG                               = LFSR_CFG_DEFAULT, // Do not use default value for LFSR configuration
  parameter lfsr_cfg_t                  LFSR2_CFG                               = LFSR_CFG_DEFAULT  // Do not use default value for LFSR configuration
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
  input  logic [4:0]                    instr_rchk_i,           // secure

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
  input  logic [4:0]                    data_rchk_i,            // secure

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
  input  logic                          fetch_enable_i,
  output logic                          core_sleep_o
);

    // Instantiate the s-core core
    // TO-DO: update all values to be passed down
    cv32e40s_core #(
	    .PMA_NUM_REGIONS	(PMA_NUM_REGIONS),
        .PMA_CFG            (PMA_CFG),
	    .PMP_NUM_REGIONS	(PMP_NUM_REGIONS),
        .PMP_PMPNCFG_RV(PMP_PMPNCFG_RV),
        .PMP_PMPADDR_RV(PMP_PMPADDR_RV)
  	 )cv32e40s_core_i(
      .clk_i                  ( clk_i                 ),
	  .rst_ni                 ( rst_ni                ),
	  .scan_cg_en_i           ( '0                    ),

	  .boot_addr_i            ( BOOT_ADDR             ),
	  .dm_exception_addr_i    ( '0                    ),
	  .dm_halt_addr_i         ( DM_HALTADDRESS        ),
	  .mhartid_i              ( HART_ID               ),
	  .mimpid_patch_i         ( IMP_PATCH_ID          ),
	  .mtvec_addr_i           ( '0                    ),

	  .instr_req_o            ( instr_req             ),
	  .instr_gnt_i            ( instr_gnt             ),
	  .instr_rvalid_i         ( instr_rvalid          ),
	  .instr_addr_o           ( instr_addr            ),
	  .instr_memtype_o        (                       ),
	  .instr_prot_o           (                       ),
	  .instr_dbg_o            (                       ),
	  .instr_rdata_i          ( instr_rdata           ),
	  .instr_err_i            ( 1'b0                  ),
	  .instr_reqpar_o         (                       ),
	  .instr_gntpar_i         (~instr_gnt             ),
	  .instr_rvalidpar_i      (~instr_rvalid          ),
	  .instr_achk_o           (                       ),
	  .instr_rchk_i           (calc_obi_chk(instr_rdata)),

	  .data_req_o             ( data_req              ),
	  .data_gnt_i             ( data_gnt              ),
	  .data_rvalid_i          ( data_rvalid           ),
	  .data_addr_o            ( data_addr             ),
	  .data_be_o              ( data_be               ),
	  .data_we_o              ( data_we               ),
	  .data_wdata_o           ( data_wdata            ),
	  .data_memtype_o         (                       ),
	  .data_prot_o            (                       ),
	  .data_dbg_o             (                       ),
	  .data_rdata_i           ( data_rdata            ),
	  .data_err_i             ( 1'b0                  ),
	  .data_reqpar_o          (                       ),
	  .data_gntpar_i          (~data_gnt              ),
	  .data_rvalidpar_i       (~data_rvalid           ),
	  .data_achk_o            (                       ),
	  .data_rchk_i            (calc_obi_chk(data_rdata)),

	  .mcycle_o               (                       ),

	  .irq_i                  ( {32{1'b0}}            ),
	  .wu_wfe_i               ( 1'b0                  ),
	  .clic_irq_i             ( 1'b0                  ),
	  .clic_irq_id_i          ( '0                    ),
	  .clic_irq_level_i       ( '0                    ),
	  .clic_irq_priv_i        ( '0                    ),
	  .clic_irq_shv_i         ( 1'b0                  ),

	  .fencei_flush_req_o     (                       ),
	  .fencei_flush_ack_i     ( 1'b1                  ),

	  .alert_minor_o          (                       ),
	  .alert_major_o          (                       ),

	  .debug_req_i            ( debug_req             ),
	  .debug_havereset_o      (                       ),
	  .debug_running_o        (                       ),
	  .debug_halted_o         (                       ),

	  .fetch_enable_i         ( fetch_enable_i        ),
	  .core_sleep_o           ( core_sleep_o          )
    );

    // eXtension Interface
    if_xif #(
        .X_NUM_RS    ( 2  ),
        .X_MEM_WIDTH ( 32 ),
        .X_RFR_WIDTH ( 32 ),
        .X_RFW_WIDTH ( 32 ),
        .X_MISA      ( '0 )
    ) ext_if();

    // Instantiate the x core
    // TO-DO: update all values to be passed down
    cv32e40x_core #(
                .NUM_MHPMCOUNTERS (NUM_MHPMCOUNTERS)
    )cv32e40x_core_i(
        // Clock and Reset
        .clk_i                  ( clk_i                 ),
        .rst_ni                 ( rst_ni                ),

        .scan_cg_en_i           ( 1'b0                  ),

        // Static configuration
        .boot_addr_i            ( BOOT_ADDR             ),
        .dm_exception_addr_i    ( '0                    ),
        .dm_halt_addr_i         ( DM_HALTADDRESS        ),
        .mhartid_i              ( HART_ID               ),
        .mimpid_patch_i         ( IMP_PATCH_ID          ),
        .mtvec_addr_i           ( '0                    ), 
        
        // Instruction memory interface
        .instr_req_o            ( instr_req             ),
        .instr_gnt_i            ( instr_gnt             ),
        .instr_rvalid_i         ( instr_rvalid          ),
        .instr_addr_o           ( instr_addr            ),
        .instr_memtype_o        (                       ),
        .instr_prot_o           (                       ),
        .instr_dbg_o            (                       ),
        .instr_rdata_i          ( instr_rdata           ),
        .instr_err_i            ( 1'b0                  ),

        // Data memory interface
        .data_req_o             ( data_req              ),
        .data_gnt_i             ( data_gnt              ),
        .data_rvalid_i          ( data_rvalid           ),
        .data_addr_o            ( data_addr             ),
        .data_be_o              ( data_be               ),
        .data_we_o              ( data_we               ),
        .data_wdata_o           ( data_wdata            ),
        .data_memtype_o         (                       ), 
        .data_prot_o            (                       ),
        .data_dbg_o             (                       ),
        .data_err_i             ( 1'b0                  ),
        .data_atop_o            (                       ),
        .data_rdata_i           ( data_rdata            ),
        .data_exokay_i          ( 1'b1                  ),

        // Cycle Count
        .mcycle_o               (                       ),

        // Time input
        .time_i                 ( '0                   ),

        // eXtension interface
        .xif_compressed_if      ( ext_if                ),
        .xif_issue_if           ( ext_if                ),
        .xif_commit_if          ( ext_if                ),
        .xif_mem_if             ( ext_if                ),
        .xif_mem_result_if      ( ext_if                ),
        .xif_result_if          ( ext_if                ),

        // Basic interrupt architecture
        .irq_i                  ( {32{1'b0}}            ),

        // Event wakeup signals
        .wu_wfe_i               ( 1'b0                  ),

        .clic_irq_i             (  '0                   ),
        .clic_irq_id_i          (  '0                   ),
        .clic_irq_level_i       (  '0                   ),
        .clic_irq_priv_i        (  '0                   ),
        .clic_irq_shv_i         (  '0                   ),
        
        // Fencei flush handshake
        .fencei_flush_req_o     (                       ),
        .fencei_flush_ack_i     ( 1'b0                  ),

        // Debug interface
        .debug_req_i            ( 1'b0                  ),
        .debug_havereset_o      (                       ),
        .debug_running_o        (                       ),
        .debug_halted_o         (                       ),
        .debug_pc_valid_o       (                       ),
        .debug_pc_o             (                       ),

        // CPU Control Signals
        .fetch_enable_i         ( fetch_enable_i        ),
        .core_sleep_o           ( core_sleep_o          )
      );

    // TO-DO: update all values to be passed down
    comparison_unit #(
        parameter BOOT_ADDR = 32'h00000080
    )comparison_unit_i(
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

    // TO-DO: update all values to be passed down
    ext_mmu #(
      parameter int unsigned ADDR_W          = 32,
      parameter int unsigned DATA_W          = 32,
      parameter int unsigned FIFO_DEPTH      = 4, //Make this 64 for div heavy programs
      parameter int unsigned MAX_OUTSTANDING = 2,
      parameter bit          DATA_BUS        = 1'b1, // D-bus = 1, I-bus = 0 - I-bus on s-core will be weird because of dummy instructions
      parameter bit          A_EXT_X         = 1'b0, // 1 if cv32e40x has A extension
      parameter int unsigned ACHK_W          = 12,
      parameter int unsigned RCHK_W          = 5
    )ext_mmu_i(
      input  logic                clk,
      input  logic                rst_n,

      input  logic                x_req,
      output logic                x_gnt,
      input  logic [ADDR_W-1:0]   x_addr,
      input  logic                x_we,
      input  logic [3:0]          x_be,
      input  logic [DATA_W-1:0]   x_wdata,
      input  logic [5:0]          x_atop,
      input  logic [2:0]          x_prot,
      input  logic [2:0]          x_memtype,
      input  logic                x_dbg,
      output logic                x_rvalid,
      output logic [DATA_W-1:0]   x_rdata,
      output logic                x_err,
      output logic                x_exokay,

      input  logic                s_req,
      output logic                s_gnt,
      input  logic [ADDR_W-1:0]   s_addr,
      input  logic                s_we,
      input  logic [3:0]          s_be,
      input  logic [DATA_W-1:0]   s_wdata,
      input  logic [2:0]          s_prot,
      input  logic [2:0]          s_memtype,
      input  logic                s_dbg,
      input  logic                s_reqpar,
      input  logic [ACHK_W-1:0]   s_achk,
      output logic                s_gntpar,
      output logic                s_rvalidpar,
      output logic [RCHK_W-1:0]   s_rchk,
      output logic                s_rvalid,
      output logic [DATA_W-1:0]   s_rdata,
      output logic                s_err,

      output logic                m_req,
      input  logic                m_gnt,
      output logic [ADDR_W-1:0]   m_addr,
      output logic                m_we,
      output logic [3:0]          m_be,
      output logic [DATA_W-1:0]   m_wdata,
      input  logic                m_rvalid,
      input  logic [DATA_W-1:0]   m_rdata,

      output logic                mismatch,
      input  logic                comp_untrust
    );

    // TO-DO: update all values to be passed down
    reset_buffer #(
        parameter TIMER = 50000,
        parameter BOOT_ADDR = 32'h00000080
    )reset_buffer_i(
        input logic clk,
        input logic rst_n,
        
        input logic debug_havereset_o_x,
        input logic debug_running_o_x,
        input logic [31:0] debug_pc_o_x,
        input logic instr_gnt_mem_x,
        input logic data_gnt_mem_x,
        input logic debug_pc_valid_o_x,
        
        input logic debug_havereset_o_s,
        input logic debug_running_o_s,
        input logic [31:0] debug_pc_o_s,
        input logic instr_gnt_mem_s,
        input logic data_gnt_mem_s,
        input logic debug_pc_valid_o_s,

        output logic rst_n_core_s,
        output logic rst_n_core_x,

        output logic [31:0] boot_addr_i_x,
        output logic instr_gnt_i_x,
        output logic data_gnt_i_x,
        output logic fetch_enable_i_x,

        output logic [31:0] boot_addr_i_s,
        output logic instr_gnt_i_s,
        output logic data_gnt_i_s,
        output logic fetch_enable_i_s,
        output logic instr_gntpar_i_s,
        output logic data_gntpar_i_s
    );

endmodule // top
