module reset_buffer_tb_s();

    localparam TEST_TIMER = 10;
    localparam TEST_BOOT  = 32'h00000080;

    logic clk = 0;
    logic rst_n;

    logic debug_havereset_o_x, debug_running_o_x, debug_pc_valid_o_x;
    logic debug_havereset_o_s, debug_running_o_s, debug_pc_valid_o_s;
    logic [31:0] debug_pc_o_x, debug_pc_o_s;
    logic instr_gnt_mem_x, data_gnt_mem_x;
    logic instr_gnt_mem_s, data_gnt_mem_s;

    logic rst_n_core_s, rst_n_core_x;
    logic [31:0] boot_addr_i_x, boot_addr_i_s;
    logic instr_gnt_i_x, data_gnt_i_x, fetch_enable_i_x;
    logic instr_gnt_i_s, data_gnt_i_s, fetch_enable_i_s;
    logic instr_gntpar_i_s, data_gntpar_i_s;

    always #5 clk = ~clk;

    reset_buffer #(
        .TIMER(TEST_TIMER),
        .BOOT_ADDR(TEST_BOOT)
    ) dut (.*);

    COV_STATE_RUNNING:   cover property (@(posedge clk) disable iff (!rst_n) (dut.state == 2'b00));
    COV_STATE_RESETTING: cover property (@(posedge clk) disable iff (!rst_n) (dut.state == 2'b01));
    COV_STATE_RESUMING:  cover property (@(posedge clk) disable iff (!rst_n) (dut.state == 2'b10));
    COV_TIMER_EXPIRED:   cover property (@(posedge clk) disable iff (!rst_n) (dut.counter == 0));

    AST_PARITY_INSTR: assert property (@(posedge clk) instr_gntpar_i_s == ~instr_gnt_i_s);
    AST_PARITY_DATA:  assert property (@(posedge clk) data_gntpar_i_s  == ~data_gnt_i_s);

    property p_reset_isolation;
        @(posedge clk) disable iff (!rst_n)
        (dut.state == 2'b01) |->
        (rst_n_core_x == 0 && rst_n_core_s == 0 && instr_gnt_i_x == 0 && data_gnt_i_s == 0);
    endproperty
    AST_RESET_ISOLATION: assert property (p_reset_isolation) else $error("Isolation failure during reset!");

    property p_pc_capture;
        @(posedge clk) disable iff (!rst_n)
        (dut.state == 2'b00 && dut.counter == 0 && debug_pc_valid_o_x && debug_pc_valid_o_s) |=>
        (dut.state == 2'b01 && boot_addr_i_x == $past(debug_pc_o_x) && boot_addr_i_s == $past(debug_pc_o_s));
    endproperty
    AST_PC_CAPTURE: assert property (p_pc_capture);

    property p_safe_resume;
        @(posedge clk) disable iff (!rst_n)
        (dut.state == 2'b10 && debug_running_o_x && debug_running_o_s) |=>
        (dut.state == 2'b00 && fetch_enable_i_x == 0 && dut.counter == TEST_TIMER);
    endproperty
    AST_SAFE_RESUME: assert property (p_safe_resume);

    int cycle_cnt = 0;

   
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            {debug_havereset_o_x, debug_running_o_x, debug_pc_valid_o_x} <= 0;
            {debug_havereset_o_s, debug_running_o_s, debug_pc_valid_o_s} <= 0;
            {debug_pc_o_x, debug_pc_o_s} <= 0;
            {instr_gnt_mem_x, data_gnt_mem_x, instr_gnt_mem_s, data_gnt_mem_s} <= 0;
        end else begin
            debug_pc_o_x    <= $urandom();
            debug_pc_o_s    <= $urandom();
            instr_gnt_mem_x <= $urandom_range(0, 1);
            data_gnt_mem_x  <= $urandom_range(0, 1);
            instr_gnt_mem_s <= $urandom_range(0, 1);
            data_gnt_mem_s  <= $urandom_range(0, 1);

            debug_havereset_o_x <= ($urandom_range(0, 99) < 30);
            debug_havereset_o_s <= ($urandom_range(0, 99) < 30);

            debug_running_o_x   <= ($urandom_range(0, 99) < 30);
            debug_running_o_s   <= ($urandom_range(0, 99) < 30);

            debug_pc_valid_o_x  <= ($urandom_range(0, 99) < 30);
            debug_pc_valid_o_s  <= ($urandom_range(0, 99) < 30);

            cycle_cnt <= cycle_cnt + 1;
        end
    end

    initial begin
        rst_n = 0;
       
        repeat(5) @(posedge clk);
        rst_n = 1;

        $display("\nStarting CRV...");

        wait(cycle_cnt == 10000);
        @(posedge clk); 

        $display("\nFinished. All tests passed");
        $finish;
    end

endmodule
