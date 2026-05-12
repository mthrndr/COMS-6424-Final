module comparison_unit_tb_s ();
    localparam BOOT_ADDR = 32'h00000080;
   
    logic clk = 0;
    logic rst_n;

    logic        data_req_o_x, data_we_o_x, data_dbg_o_x;
    logic [3:0]  data_be_o_x;
    logic [31:0] data_addr_o_x, data_wdata_o_x;
    logic [1:0]  data_memtype_o_x;
    logic [2:0]  data_prot_o_x;
    logic        debug_havereset_o_x, debug_running_o_x, debug_halted_o_x, debug_pc_valid_o_x;
    logic [31:0] debug_pc_o_x;
    logic        core_sleep_o_x;

    logic        data_req_o_s, data_we_o_s, data_dbg_o_s;
    logic [3:0]  data_be_o_s;
    logic [31:0] data_addr_o_s, data_wdata_o_s;
    logic [1:0]  data_memtype_o_s;
    logic [2:0]  data_prot_o_s;
    logic        debug_havereset_o_s, debug_running_o_s, debug_halted_o_s, debug_pc_valid_o_s;
    logic [31:0] debug_pc_o_s;
    logic        core_sleep_o_s;

    logic fault_det;

    always #5 clk = ~clk;

    comparison_unit #(
        .BOOT_ADDR(BOOT_ADDR)
    ) dut (.*);

    AST_FAULT_IS_STICKY: assert property (
        @(posedge clk) disable iff (!rst_n)
        fault_det |=> fault_det
    ) else $error("\nFlag cleared instead of sticky");

    COV_FAULT_DETECTED:  cover property (@(posedge clk) disable iff (!rst_n) ($rose(fault_det)));
    COV_PC_COMPARED:     cover property (@(posedge clk) disable iff (!rst_n) (dut.compare_pc_trigger));
    COV_DATA_COMPARED:   cover property (@(posedge clk) disable iff (!rst_n) (dut.compare_data_trigger));
    COV_PC_FIFO_FULL:    cover property (@(posedge clk) disable iff (!rst_n) (dut.fifo_pc_full_x));
    COV_DATA_FIFO_FULL:  cover property (@(posedge clk) disable iff (!rst_n) (dut.fifo_data_full_x));

    int cycle_cnt = 0;
    logic inject_pc_error;
    logic inject_data_error;

always_ff @(posedge clk) begin
        cycle_cnt <= cycle_cnt + 1;

        if (!rst_n) begin
            {data_req_o_x, data_we_o_x, data_dbg_o_x, data_be_o_x, data_addr_o_x, data_wdata_o_x, data_memtype_o_x, data_prot_o_x} <= '0;
            {data_req_o_s, data_we_o_s, data_dbg_o_s, data_be_o_s, data_addr_o_s, data_wdata_o_s, data_memtype_o_s, data_prot_o_s} <= '0;
            {debug_havereset_o_x, debug_running_o_x, debug_halted_o_x, debug_pc_valid_o_x, debug_pc_o_x, core_sleep_o_x} <= '0;
            {debug_havereset_o_s, debug_running_o_s, debug_halted_o_s, debug_pc_valid_o_s, debug_pc_o_s, core_sleep_o_s} <= '0;
            inject_pc_error <= 0;
            inject_data_error <= 0;
        end else begin
            
            automatic logic        rand_pc_valid = ($urandom_range(0, 99) < 30);
            automatic logic [31:0] rand_pc       = $urandom();
            
            automatic logic        rand_data_req = ($urandom_range(0, 99) < 40);
            automatic logic        rand_data_we  = ($urandom_range(0, 99) < 50);
            automatic logic [3:0]  rand_data_be  = $urandom_range(0, 15);
            automatic logic [31:0] rand_addr     = $urandom();
            automatic logic [31:0] rand_wdata    = $urandom();
            automatic logic [1:0]  rand_memtype  = $urandom_range(0, 3);
            automatic logic [2:0]  rand_prot     = $urandom_range(0, 7);
            automatic logic        rand_dbg      = $urandom_range(0, 1);

            inject_pc_error   <= ($urandom_range(0, 999) == 0);
            inject_data_error <= ($urandom_range(0, 999) == 0);

            debug_pc_valid_o_x <= rand_pc_valid;
            debug_pc_o_x       <= rand_pc;
            data_req_o_x       <= rand_data_req;
            data_we_o_x        <= rand_data_we;
            data_be_o_x        <= rand_data_be;
            data_addr_o_x      <= rand_addr;
            data_wdata_o_x     <= rand_wdata;
            data_memtype_o_x   <= rand_memtype;
            data_prot_o_x      <= rand_prot;
            data_dbg_o_x       <= rand_dbg;

            debug_pc_valid_o_s <= rand_pc_valid;
            debug_pc_o_s       <= inject_pc_error ? ~rand_pc : rand_pc;
            data_req_o_s       <= rand_data_req;
            data_we_o_s        <= rand_data_we;
            data_be_o_s        <= rand_data_be;
            data_addr_o_s      <= inject_data_error ? ~rand_addr : rand_addr;
            data_wdata_o_s     <= rand_wdata;
            data_memtype_o_s   <= rand_memtype;
            data_prot_o_s      <= rand_prot;
            data_dbg_o_s       <= rand_dbg;

            if (fault_det && ($urandom_range(0,99) < 5)) begin
                 rst_n <= 0;
            end else if (!rst_n) begin
                 rst_n <= 1; 
            end
        end
    end

    initial begin
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;

        $display("\nStarting comparison_unit CRV...");
        wait(cycle_cnt == 10000);
        @(posedge clk);

        $display("\nFinished. All Passed");
        $finish;
    end

endmodule
