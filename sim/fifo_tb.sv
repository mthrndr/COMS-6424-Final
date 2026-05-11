`timescale 1ns/1ps

module tb_fifo();

    parameter DEPTH     = 8;
    parameter WIDTH     = 32;
    parameter ERR_VAL   = 999;

    logic               clk;
    logic               rst_n;
    logic               w_en;
    logic               r_en;
    logic               flush;
    logic [WIDTH-1:0]   d_in;
    logic [WIDTH-1:0]   d_out;
    logic               empty;
    logic               full;

    fifo #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .w_en(w_en),
        .r_en(r_en),
        .flush(flush),
        .d_in(d_in),
        .d_out(d_out),
        .empty(empty),
        .full(full)
    );

    always #5 clk = ~clk;

    task reset();
        begin
            rst_n = 0;
            w_en  = 0;
            r_en  = 0;
            flush = 0;
            d_in  = 0;
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            $display("FIFO Reset. Empty: %b, Full: %b", empty, full);
        end
    endtask

    task write_data(input [WIDTH-1:0] data);
        begin
            w_en = 1;
            d_in = data;
            @(posedge clk);
            w_en = 0;
        end
    endtask

    task read_data();
        begin
            r_en = 1;
            @(posedge clk);
            r_en = 0;
        end
    endtask

    initial begin
        clk = 0;
        
        $display("---------------------------------");
        $display("Starting FIFO Testbench");
        $display("---------------------------------");
        
        reset();

        $display("---------------------------------");
        $display("Test 1: Fill");
        $display("---------------------------------");
        for (int i = 0; i < DEPTH; i++) begin
            write_data(i);
            $display("Write %0d | Empty: %b | Full: %b", i, empty, full);
        end
       
        // Try to write while full, should do nothing, and 999 should not
        // appear in Test 2
        $display("Attempting to write while full...");
        write_data(ERR_VAL);

        $display("---------------------------------");
        $display("Test 2: Empty");
        $display("---------------------------------");
        for (int i = 0; i < DEPTH; i++) begin
            $display("Read  %0d | Empty: %b | Full: %b", d_out, empty, full);
            if (d_out == ERR_VAL) begin
                $fatal("Error: value was written after being full");
            end
            read_data();
        end

        // Clear for wrap around test
        reset();

        $display("Reading empty fifo");
        read_data();

        $display("---------------------------------");
        $display("Test 3: Pointer Wrap-around Test");
        $display("---------------------------------");
        for (int i = 0; i < DEPTH; i++) begin
            write_data(i);
            $display("Write %0d | Empty: %b | Full: %b", i, empty, full);
        end
        for (int i = 0; i < (DEPTH/2); i++) begin
            read_data();
            $display("Read  %0d | Empty: %b | Full: %b", i, empty, full);
        end
        for (int i = 0; i < (DEPTH/2); i++) begin
            write_data (i + DEPTH);
            $display("Write %0d | Empty: %b | Full: %b", (i + DEPTH), empty, full);
        end
        $display("After Wrap-around write | Empty: %b | Full: %b", empty, full);

        $display("---------------------------------");
        $display("Test 4: Simultaneous Read and Write");
        $display("---------------------------------");
        w_en = 1; r_en = 1; d_in = 9;
        @(posedge clk);
        w_en = 0; r_en = 0;
        $display("Simultaneous Read and Write complete | Empty: %b | Full: %b", empty, full);


        $display("---------------------------------");
        $display("FIFO Tests Completed");
        $display("---------------------------------");
        $finish;
    end

endmodule
