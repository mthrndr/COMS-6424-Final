`timescale 1ns/1ps

module reset_buffer_tb;

    logic clk = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;

    initial begin
        $display("[TB] starting simulation");
        rst_n = 1;
        repeat (4) @(posedge clk);
        rst_n = 0;
	repeat (10) @(posedge clk);
	rst_n = 1;
        $display("[TB] external reset deasserted at %0t", $time);
        repeat (5000) @(posedge clk);
        $display("[TB] simulation finished at %0t", $time);
        $finish;
    end

    logic        rst_n_core_x, rst_n_core_s;
    logic [31:0] boot_addr_i_x, boot_addr_i_s;
    logic        instr_gnt_i_x, data_gnt_i_x;
    logic        instr_gnt_i_s, data_gnt_i_s;
    logic        fetch_enable_i_x, fetch_enable_i_s;
    logic        instr_gntpar_i_s, data_gntpar_i_s;

    logic        debug_havereset_x, debug_running_x, debug_pc_valid_x;
    logic [31:0] debug_pc_x;
    logic        debug_havereset_s, debug_running_s, debug_pc_valid_s;
    logic [31:0] debug_pc_s;

    logic        instr_gnt_mem_x, data_gnt_mem_x;
    logic        instr_gnt_mem_s, data_gnt_mem_s;

    logic        instr_req_x, data_req_x;
    logic [31:0] instr_addr_x, data_addr_x, data_wdata_x;
    logic [3:0]  data_be_x;
    logic        data_we_x;
    logic        instr_rvalid_x, data_rvalid_x;
    logic [31:0] instr_rdata_x, data_rdata_x;

    logic        instr_req_s, data_req_s;
    logic [31:0] instr_addr_s, data_addr_s, data_wdata_s;
    logic [3:0]  data_be_s;
    logic        data_we_s;
    logic        instr_rvalid_s, data_rvalid_s;
    logic [31:0] instr_rdata_s, data_rdata_s;

    logic        instr_reqpar_s, data_reqpar_s;
    logic        instr_rvalidpar_s, data_rvalidpar_s;
    logic [11:0] instr_achk_s, data_achk_s;
    logic [4:0]  instr_rchk_s, data_rchk_s;

    reset_buffer #(
        .TIMER     (200),
        .BOOT_ADDR (32'h0000_0080)
    ) dut (
        .clk                  (clk),
        .rst_n                (rst_n),

        .debug_havereset_o_x  (debug_havereset_x),
        .debug_running_o_x    (debug_running_x),
        .debug_pc_o_x         (debug_pc_x),
        .debug_pc_valid_o_x   (debug_pc_valid_x),
        .instr_gnt_mem_x      (instr_gnt_mem_x),
        .data_gnt_mem_x       (data_gnt_mem_x),

        .debug_havereset_o_s  (debug_havereset_s),
        .debug_running_o_s    (debug_running_s),
        .debug_pc_o_s         (debug_pc_s),
        .debug_pc_valid_o_s   (debug_pc_valid_s),
        .instr_gnt_mem_s      (instr_gnt_mem_s),
        .data_gnt_mem_s       (data_gnt_mem_s),

        .rst_n_core_x         (rst_n_core_x),
        .boot_addr_i_x        (boot_addr_i_x),
        .instr_gnt_i_x        (instr_gnt_i_x),
        .data_gnt_i_x         (data_gnt_i_x),
        .fetch_enable_i_x     (fetch_enable_i_x),

        .rst_n_core_s         (rst_n_core_s),
        .boot_addr_i_s        (boot_addr_i_s),
        .instr_gnt_i_s        (instr_gnt_i_s),
        .data_gnt_i_s         (data_gnt_i_s),
        .fetch_enable_i_s     (fetch_enable_i_s),
        .instr_gntpar_i_s     (instr_gntpar_i_s),
        .data_gntpar_i_s      (data_gntpar_i_s)
    );

    if_xif #(
        .X_NUM_RS    (2),
        .X_ID_WIDTH  (4),
        .X_MEM_WIDTH (32),
        .X_RFR_WIDTH (32),
        .X_RFW_WIDTH (32),
        .X_MISA      (32'h0),
        .X_ECS_XS    (2'b0)
    ) ext_if ();

    cv32e40x_core u_cv32e40x (
        .clk_i               (clk),
        .rst_ni              (rst_n_core_x),
        .scan_cg_en_i        (1'b0),

        .boot_addr_i         (boot_addr_i_x),
        .mtvec_addr_i        (32'h0000_0000),
        .dm_halt_addr_i      (32'h1A11_0800),
        .dm_exception_addr_i (32'h1A11_0808),
        .mhartid_i           (32'h0000_0000),
        .mimpid_patch_i      (4'h0),

        .instr_req_o         (instr_req_x),
        .instr_gnt_i         (instr_gnt_i_x),
        .instr_addr_o        (instr_addr_x),
        .instr_memtype_o     (),
        .instr_prot_o        (),
        .instr_dbg_o         (),
        .instr_rvalid_i      (instr_rvalid_x),
        .instr_rdata_i       (instr_rdata_x),
        .instr_err_i         (1'b0),

        .data_req_o          (data_req_x),
        .data_gnt_i          (data_gnt_i_x),
        .data_addr_o         (data_addr_x),
        .data_atop_o         (),
        .data_be_o           (data_be_x),
        .data_memtype_o      (),
        .data_prot_o         (),
        .data_dbg_o          (),
        .data_wdata_o        (data_wdata_x),
        .data_we_o           (data_we_x),
        .data_rvalid_i       (data_rvalid_x),
        .data_rdata_i        (data_rdata_x),
        .data_err_i          (1'b0),
        .data_exokay_i       (1'b1),

        .mcycle_o            (),
        .time_i              (64'h0),

        .xif_compressed_if   (ext_if),
        .xif_issue_if        (ext_if),
        .xif_commit_if       (ext_if),
        .xif_mem_if          (ext_if),
        .xif_mem_result_if   (ext_if),
        .xif_result_if       (ext_if),

        .irq_i               (32'h0),

        .clic_irq_i          (1'b0),
        .clic_irq_id_i       (5'h0),
        .clic_irq_level_i    (8'h0),
        .clic_irq_priv_i     (2'h0),
        .clic_irq_shv_i      (1'b0),

        .fencei_flush_req_o  (),
        .fencei_flush_ack_i  (1'b1),

        .debug_req_i         (1'b0),
        .debug_havereset_o   (debug_havereset_x),
        .debug_running_o     (debug_running_x),
        .debug_halted_o      (),
        .debug_pc_valid_o    (debug_pc_valid_x),
        .debug_pc_o          (debug_pc_x),

        .fetch_enable_i      (fetch_enable_i_x),
        .core_sleep_o        (),
        .wu_wfe_i            (1'b0)
    );

    cv32e40s_core u_cv32e40s (
        .clk_i               (clk),
        .rst_ni              (rst_n_core_s),
        .scan_cg_en_i        (1'b0),

        .boot_addr_i         (boot_addr_i_s),
        .mtvec_addr_i        (32'h0000_0000),
        .dm_halt_addr_i      (32'h1A11_0800),
        .dm_exception_addr_i (32'h1A11_0808),
        .mhartid_i           (32'h0000_0000),
        .mimpid_patch_i      (4'h0),

        .instr_req_o         (instr_req_s),
        .instr_reqpar_o      (instr_reqpar_s),
        .instr_gnt_i         (instr_gnt_i_s),
        .instr_gntpar_i      (instr_gntpar_i_s),
        .instr_addr_o        (instr_addr_s),
        .instr_memtype_o     (),
        .instr_prot_o        (),
        .instr_achk_o        (instr_achk_s),
        .instr_dbg_o         (),
        .instr_rvalid_i      (instr_rvalid_s),
        .instr_rvalidpar_i   (instr_rvalidpar_s),
        .instr_rdata_i       (instr_rdata_s),
        .instr_err_i         (1'b0),
        .instr_rchk_i        (instr_rchk_s),

        .data_req_o          (data_req_s),
        .data_reqpar_o       (data_reqpar_s),
        .data_gnt_i          (data_gnt_i_s),
        .data_gntpar_i       (data_gntpar_i_s),
        .data_addr_o         (data_addr_s),
        .data_be_o           (data_be_s),
        .data_memtype_o      (),
        .data_prot_o         (),
        .data_dbg_o          (),
        .data_wdata_o        (data_wdata_s),
        .data_we_o           (data_we_s),
        .data_achk_o         (data_achk_s),
        .data_rvalid_i       (data_rvalid_s),
        .data_rvalidpar_i    (data_rvalidpar_s),
        .data_rdata_i        (data_rdata_s),
        .data_err_i          (1'b0),
        .data_rchk_i         (data_rchk_s),

        .mcycle_o            (),

        .irq_i               (32'h0),

        .clic_irq_i          (1'b0),
        .clic_irq_id_i       (6'h0),
        .clic_irq_level_i    (8'h0),
        .clic_irq_priv_i     (2'h0),
        .clic_irq_shv_i      (1'b0),

        .fencei_flush_req_o  (),
        .fencei_flush_ack_i  (1'b1),

        .debug_req_i         (1'b0),
        .debug_havereset_o   (debug_havereset_s),
        .debug_running_o     (debug_running_s),
        .debug_halted_o      (),
        .debug_pc_valid_o    (debug_pc_valid_s),
        .debug_pc_o          (debug_pc_s),

        .alert_major_o       (),
        .alert_minor_o       (),

        .fetch_enable_i      (fetch_enable_i_s),
        .core_sleep_o        (),
        .wu_wfe_i            (1'b0)
    );

    localparam logic [31:0] NOP = 32'h0000_0013;

    assign instr_gnt_mem_x = instr_req_x;
    assign data_gnt_mem_x  = data_req_x;
    assign instr_gnt_mem_s = instr_req_s;
    assign data_gnt_mem_s  = data_req_s;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_rvalid_x <= 1'b0;
            instr_rdata_x  <= 32'h0;
            data_rvalid_x  <= 1'b0;
            data_rdata_x   <= 32'h0;
        end else begin
            instr_rvalid_x <= instr_req_x && instr_gnt_i_x;
            instr_rdata_x  <= NOP;
            data_rvalid_x  <= data_req_s && data_gnt_i_x;
            data_rdata_x   <= 32'h0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_rvalid_s    <= 1'b0;
            instr_rvalidpar_s <= 1'b1;
            instr_rdata_s     <= 32'h0;
            instr_rchk_s      <= 5'h0;
            data_rvalid_s     <= 1'b0;
            data_rvalidpar_s  <= 1'b1;
            data_rdata_s      <= 32'h0;
            data_rchk_s       <= 5'h0;
        end else begin
            instr_rvalid_s    <= instr_req_s && instr_gnt_i_s;
            instr_rvalidpar_s <= ~(instr_req_s && instr_gnt_i_s);
            instr_rdata_s     <= NOP;
            instr_rchk_s      <= 5'h0;
            data_rvalid_s     <= data_req_s && data_gnt_i_s;
            data_rvalidpar_s  <= ~(data_req_s && data_gnt_i_s);
            data_rdata_s      <= 32'h0;
            data_rchk_s       <= 5'h0;
        end
    end

    logic [1:0] prev_state = 2'b11;

    always_ff @(posedge clk) begin
        if (rst_n && (dut.state !== prev_state)) begin
            case (dut.state)
                2'b00: $display("[%6t] reset_buffer -> RUNNING   (saved_pc_x=%h saved_pc_s=%h)",
                                $time, dut.saved_pc_x, dut.saved_pc_s);
                2'b01: $display("[%6t] reset_buffer -> RESETTING (saved_pc_x=%h saved_pc_s=%h)",
                                $time, dut.saved_pc_x, dut.saved_pc_s);
                2'b10: $display("[%6t] reset_buffer -> RESUMING",
                                $time);
                default: $display("[%6t] reset_buffer -> UNKNOWN", $time);
            endcase
            prev_state <= dut.state;
        end
    end

    always_ff @(posedge clk) begin
       if (rst_n) begin
          if (debug_havereset_x !== $past(debug_havereset_x)) begin
            $display("[%6t] debug_havereset_x = %b", $time, debug_havereset_x);
	  end
          if (debug_havereset_s !== $past(debug_havereset_s)) begin
            $display("[%6t] debug_havereset_s = %b", $time, debug_havereset_s);
	  end
       end
    end

    initial begin
        $dumpfile("reset_buffer_tb.vcd");
        $dumpvars(0, tb_reset_buffer);
    end

endmodule
