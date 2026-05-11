`timescale 1ns/1ps

module comparison_unit_tb();

    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;

    logic        data_req_o_x;
    logic        data_we_o_x;
    logic [3:0]  data_be_o_x;
    logic [31:0] data_addr_o_x;
    logic [1:0]  data_memtype_o_x;
    logic [2:0]  data_prot_o_x;
    logic        data_dbg_o_x;
    logic [31:0] data_wdata_o_x;

    logic        data_req_o_s;
    logic        data_we_o_s;
    logic [3:0]  data_be_o_s;
    logic [31:0] data_addr_o_s;
    logic [1:0]  data_memtype_o_s;
    logic [2:0]  data_prot_o_s;
    logic        data_dbg_o_s;
    logic [31:0] data_wdata_o_s;

    logic        debug_havereset_o_x;
    logic        debug_running_o_x;
    logic        debug_halted_o_x;
    logic        debug_pc_valid_o_x;
    logic [31:0] debug_pc_o_x;

    logic        debug_havereset_o_s;
    logic        debug_running_o_s;
    logic        debug_halted_o_s;
    logic        debug_pc_valid_o_s;
    logic [31:0] debug_pc_o_s;

    logic        core_sleep_o_x;
    logic        core_sleep_o_s;

    logic        fault_det;

    comparison_unit dut (.*);

    int errors = 0;
    `define CHECK(cond) \
        if (!(cond)) begin \
            $display("Failed"); \
            errors++; \
        end else \
            $display("Passed");

    task automatic zero_all;
        {data_req_o_x, data_we_o_x, data_be_o_x, data_addr_o_x, data_memtype_o_x,
	       	data_prot_o_x, data_dbg_o_x, data_wdata_o_x} = '0;
        {data_req_o_s, data_we_o_s, data_be_o_s, data_addr_o_s, data_memtype_o_s,
	       	data_prot_o_s, data_dbg_o_s, data_wdata_o_s} = '0;
        {debug_havereset_o_x, debug_running_o_x, debug_halted_o_x, debug_pc_valid_o_x, debug_pc_o_x} = '0;
        {debug_havereset_o_s, debug_running_o_s, debug_halted_o_s, debug_pc_valid_o_s, debug_pc_o_s} = '0;
        {core_sleep_o_x, core_sleep_o_s} = '0;
    endtask

    task automatic apply_reset;
        zero_all();
        rst_n = 0;
        repeat (4) @(posedge clk);
        @(negedge clk) rst_n = 1;
        @(posedge clk);
    endtask

   task automatic drive_pc(input logic [31:0] pc_x, input logic [31:0] pc_s, input bit valid_x = 1, input bit valid_s = 1);
        @(negedge clk);
        debug_pc_o_x       = pc_x;
        debug_pc_o_s       = pc_s;
        debug_pc_valid_o_x = valid_x;
        debug_pc_valid_o_s = valid_s;
        @(posedge clk);
        @(negedge clk);
        debug_pc_valid_o_x = 0;
        debug_pc_valid_o_s = 0;
    endtask

    task automatic drive_write_x(input logic [31:0] addr, input logic [31:0] wdata, input logic [3:0] be = 4'hF);
        @(negedge clk);
        data_req_o_x   = 1;
        data_we_o_x    = 1;
        data_addr_o_x  = addr;
        data_wdata_o_x = wdata;
        data_be_o_x    = be;
        @(posedge clk);
        @(negedge clk);
        data_req_o_x   = 0;
        data_we_o_x    = 0;
    endtask

    task automatic drive_write_s(input logic [31:0] addr, input logic [31:0] wdata, input logic [3:0]  be = 4'hF);
        @(negedge clk);
        data_req_o_s   = 1;
        data_we_o_s    = 1;
        data_addr_o_s  = addr;
        data_wdata_o_s = wdata;
        data_be_o_s    = be;
        @(posedge clk);
        @(negedge clk);
        data_req_o_s   = 0;
        data_we_o_s    = 0;
    endtask

    initial begin
        apply_reset();

        $display("\nTesting matching PCs:");
        drive_pc(32'h0000_0080, 32'h0000_0080);
        drive_pc(32'h0000_0084, 32'h0000_0084);
        drive_pc(32'h0000_0088, 32'h0000_0088);
        repeat (6) @(posedge clk);
        `CHECK(fault_det === 1'b0);

        $display("\nTesting matching data writes:");
        drive_write_x(32'h0000_1000, 32'hDEAD_BEEF);
        drive_write_s(32'h0000_1000, 32'hDEAD_BEEF);
        repeat (6) @(posedge clk);
        `CHECK(fault_det === 1'b0);

        $display("\nTesting skewed but matching PCs:");
        drive_pc(32'h0000_0100, 32'h0, .valid_s(0));
        repeat (3) @(posedge clk);
        drive_pc(32'h0, 32'h0000_0100, .valid_x(0));
        repeat (6) @(posedge clk);
        `CHECK(fault_det === 1'b0);

        $display("\nTesting mismatched PCs:");
        drive_pc(32'h0000_0200, 32'h0000_0208);
        repeat (4) @(posedge clk);
        `CHECK(fault_det === 1'b1);

        $display("\nTesting sticky after fault:");
        drive_pc(32'h0000_0300, 32'h0000_0300);
        repeat (10) @(posedge clk);
        `CHECK(fault_det === 1'b1);

        $display("\nTesting reset:");
        apply_reset();
        `CHECK(fault_det === 1'b0);

        $display("\nTesting mismatched writes:");
        drive_write_x(32'h0000_2000, 32'hAAAA_AAAA);
        drive_write_s(32'h0000_2000, 32'hBBBB_BBBB);
        repeat (4) @(posedge clk);
        `CHECK(fault_det === 1'b1);

        if (errors == 0)
            $display("\nAll tests passed");
        else
            $display("\n%0d Test(s) failed", errors);
        $finish;
    end

endmodule
