module top_tb_wrapper
    #(parameter // Parameters used by TB
                INSTR_RDATA_WIDTH = 32,
                RAM_ADDR_WIDTH    = 20,
                BOOT_ADDR         = 'h80,
                DM_HALTADDRESS    = 32'h1A11_0800,
                HART_ID           = 32'h0000_0000,
                IMP_PATCH_ID      = 4'h0
    )
    (input logic         clk_i,
     input logic         rst_ni,

     input logic         fetch_enable_i,
     output logic        tests_passed_o,
     output logic        tests_failed_o,
     output logic [31:0] exit_value_o,
     output logic        exit_valid_o);

    // signals connecting core to memory
    logic                         instr_req;
    logic                         instr_gnt;
    logic                         instr_rvalid;
    logic [31:0]                  instr_addr;
    logic [INSTR_RDATA_WIDTH-1:0] instr_rdata;

    logic                         data_req;
    logic                         data_gnt;
    logic                         data_rvalid;
    logic [31:0]                  data_addr;
    logic                         data_we;
    logic [3:0]                   data_be;
    logic [31:0]                  data_rdata;
    logic [31:0]                  data_wdata;

    // signals to debug unit
    logic                         debug_req;

    // irq signals (not used)
    logic [0:31]                  irq;
    logic [0:4]                   irq_id_in;
    logic                         irq_ack;
    logic [0:4]                   irq_id_out;
    logic                         irq_sec;


    // interrupts (only timer for now)
    assign irq_sec     = '0;

    // Used for data and instr rchk
    function automatic logic [4:0] calc_obi_chk(logic [31:0] data);
        logic [4:0] chk;
        chk[0] = ^data[7:0];    // Parity Byte 0
        chk[1] = ^data[15:8];   // Parity Byte 1
        chk[2] = ^data[23:16];  // Parity Byte 2
        chk[3] = ^data[31:24];  // Parity Byte 3
        chk[4] = 1'b0;          // Set to 0
        return chk;
    endfunction

    localparam pma_cfg_t TB_PMA_CFG [1] = '{
        '{
            word_addr_low:  32'h0000_0000,
            word_addr_high: 32'hFFFF_FFFF,
            main:           1'b1,          // 1 = Executable RAM
            bufferable:     1'b1,
            cacheable:      1'b1,
            integrity:      1'b1           // 1 = Turn on OBI checkers
        }
    };

    localparam pmpncfg_t TB_PMP_CFG [1] = '{
        '{
            lock:  1'b0,
            zero0: 2'b00,
            mode:  PMP_MODE_TOR,    // TOR MODE
            exec:  1'b1,            // Grants Execute permission
            write: 1'b1,            // Grants Write permission
            read:  1'b1             // Grants Read permission
        }
    };

    localparam logic [31:0] TB_PMP_ADDR [1] = '{
        32'hFFFF_FFFF // NAPOT with all 1s covers the entire 32-bit address space
    };

    // Instantiate the core
    top #(
	    .PMA_NUM_REGIONS	(1),
        .PMA_CFG            (TB_PMA_CFG),
	    .PMP_NUM_REGIONS	(1),
        .PMP_PMPNCFG_RV(TB_PMP_CFG),
        .PMP_PMPADDR_RV(TB_PMP_ADDR)
  	 )
    top_i(
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
    //Debugging
    // Checking if verilator is accepting new PMA config
    initial begin
        $display("--- CORE PARAMETER CHECK ---");
        $display("PMA_NUM_REGIONS = %0d", top_i.cv32e40s_core_i.PMA_NUM_REGIONS);
        if (top_i.cv32e40s_core_i.PMA_NUM_REGIONS > 0) begin
            $display("PMA_CFG[0].main = %b", top_i.cv32e40s_core_i.PMA_CFG[0].main);
            $display("PMA_CFG[0].word_addr_high = %h", top_i.cv32e40s_core_i.PMA_CFG[0].word_addr_high);
        end
        $display("PMP_NUM_REGIONS = %0d", top_i.cv32e40s_core_i.PMP_NUM_REGIONS);
        if (top_i.cv32e40s_core_i.PMP_NUM_REGIONS > 0) begin
            $display("PMP_CFG[0].exec = %b", top_i.cv32e40s_core_i.PMP_PMPNCFG_RV[0].exec);
            $display("PMP_ADDR[0] = %h", top_i.cv32e40s_core_i.PMP_PMPADDR_RV[0]);
        end
        $display("----------------------------");
    end
    int unsigned dbg_cycles = 0;
    always_ff @(posedge clk_i) begin
        if(rst_ni) begin
            dbg_cycles <= dbg_cycles + 1;
            if(dbg_cycles < 100 || (dbg_cycles % 1000 == 0)) begin
                $display("[%0t] cyc=%0d pc=%h instr_req=%b  instr_gnt=%b data_req=%b we=%b daddr=%h slp=%b mcause=%h mepc=%h",
                        $time,
                        dbg_cycles,
                        instr_addr,
                        instr_req,
                        instr_gnt,
                        data_req,
                        data_we,
                        data_addr,
                        core_sleep_o,
                        top_i.cv32e40s_core_i.cs_registers_i.mcause_q,
                        top_i.cv32e40s_core_i.mepc
                    );
            end
            // Check Instruction Integrity Errors
            // Check Instruction Integrity Errors
            if (rst_ni && top_i.cv32e40s_core_i.instr_rvalid_i) begin
              // Path goes through if_stage_i -> instr_obi_i
              if (top_i.cv32e40s_core_i.if_stage_i.instruction_obi_i.rchk_err_resp) begin
                $display("[%0t] !!! INSTR INTEGRITY FAULT at PC: %h !!!", $time, top_i.cv32e40s_core_i.instr_addr_o);
                $display("Data Seen: %h | RCHK Sent: %h | RCHK Expected: %h", 
                         top_i.cv32e40s_core_i.instr_rdata_i, 
                         top_i.cv32e40s_core_i.instr_rchk_i,
                         top_i.cv32e40s_core_i.if_stage_i.instruction_obi_i.integrity_fifo_i.rchk_i.rchk_res);
              end
            end

            // Check Data Integrity Errors (LSU)
            if (rst_ni && top_i.cv32e40s_core_i.data_rvalid_i) begin
              // Path goes through load_store_unit_i -> data_obi_i
              if (top_i.cv32e40s_core_i.load_store_unit_i.data_obi_i.rchk_err_resp) begin
                $display("[%0t] !!! DATA INTEGRITY FAULT at Addr: %h !!!", $time, top_i.cv32e40s_core_i.data_addr_o);
                $display("Data Seen: %h | RCHK Sent: %h | RCHK Expected: %h", 
                         top_i.cv32e40s_core_i.data_rdata_i, 
                         top_i.cv32e40s_core_i.data_rchk_i,
                         top_i.cv32e40s_core_i.load_store_unit_i.data_obi_i.integrity_fifo_i.rchk_i.rchk_res);
              end
            end
            if (rst_ni && top_i.cv32e40s_core_i.if_stage_i.pc_if_o == 32'h00000080) begin
                // Check if the OBI bus checker is failing
                if (top_i.cv32e40s_core_i.if_stage_i.integrity_err_obi) begin
                    $display("[%0t] ERROR: OBI Integrity Check Failed at 0x80!", $time);
                end
                // Check if the PMA/PMP (Memory Map & Security Rules) are rejecting the address
                if (top_i.cv32e40s_core_i.if_stage_i.prefetch_inst_resp.mpu_status != 0) begin
                    $display("[%0t] ERROR: MPU (PMA/PMP) rejected execution at 0x80! mpu_status: %0d",
                             $time, top_i.cv32e40s_core_i.if_stage_i.prefetch_inst_resp.mpu_status);
                end
                if (top_i.cv32e40s_core_i.if_stage_i.mpu_i.mpu_err) begin
                    $display("[%0t] FATAL MPU ERROR AT 0x80: pma_err=%b, pmp_err=%b",
                    $time,
                    top_i.cv32e40s_core_i.if_stage_i.mpu_i.pma_err,
                    top_i.cv32e40s_core_i.if_stage_i.mpu_i.pmp_err);
                    $display("--- INTERNAL MPU STATE ---");
                    $display("pmp_err     = %b", top_i.cv32e40s_core_i.if_stage_i.mpu_i.pmp_err);
                    $display("priv_lvl    = %b", top_i.cv32e40s_core_i.if_stage_i.mpu_i.priv_lvl_i);
                    $display("cfg[0].mode = %b", top_i.cv32e40s_core_i.if_stage_i.mpu_i.csr_pmp_i.cfg[0].mode);
                    $display("addr[0]     = %h", top_i.cv32e40s_core_i.if_stage_i.mpu_i.csr_pmp_i.addr[0]);
                    $display("MSECCFG.MML = %b", top_i.cv32e40s_core_i.if_stage_i.mpu_i.csr_pmp_i.mseccfg.mml);
                    $display("MSECCFG.MMWP= %b", top_i.cv32e40s_core_i.if_stage_i.mpu_i.csr_pmp_i.mseccfg.mmwp);
                    $display("--------------------------");
                end
            end
        end
    end
    // this handles read to RAM and memory mapped pseudo peripherals
    mm_ram
        #(.RAM_ADDR_WIDTH (RAM_ADDR_WIDTH),
          .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH))
    ram_i
        (.clk_i          ( clk_i                                     ),
         .rst_ni         ( rst_ni                                    ),
         .dm_halt_addr_i ( DM_HALTADDRESS                            ),

         .instr_req_i    ( instr_req                                 ),
         .instr_addr_i   ( { {10{1'b0}},
                             instr_addr[RAM_ADDR_WIDTH-1:0]
                           }                                         ),
         .instr_rdata_o  ( instr_rdata                               ),
         .instr_rvalid_o ( instr_rvalid                              ),
         .instr_gnt_o    ( instr_gnt                                 ),

         .data_req_i     ( data_req                                  ),
         .data_addr_i    ( data_addr                                 ),
         .data_we_i      ( data_we                                   ),
         .data_be_i      ( data_be                                   ),
         .data_wdata_i   ( data_wdata                                ),
         .data_rdata_o   ( data_rdata                                ),
         .data_rvalid_o  ( data_rvalid                               ),
         .data_gnt_o     ( data_gnt                                  ),

         .irq_id_i       ( irq_id_out                                ),
         .irq_ack_i      ( irq_ack                                   ),
         .irq_o          ( irq                                       ),

         .debug_req_o    ( debug_req                                 ),

         .pc_core_id_i   ( top_i.cv32e40s_core_i.if_id_pipe.pc             ),

         .tests_passed_o ( tests_passed_o                            ),
         .tests_failed_o ( tests_failed_o                            ),
         .exit_valid_o   ( exit_valid_o                              ),
         .exit_value_o   ( exit_value_o                              ));

endmodule // cv32e40s_tb_wrapper
