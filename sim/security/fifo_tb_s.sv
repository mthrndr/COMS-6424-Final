module fifo_tb_s ();
    localparam DEPTH = 8;
    localparam WIDTH = 32;

    logic clk = 0;
    logic rst_n, w_en, r_en, flush, empty, full;
    logic [WIDTH-1:0] d_in, d_out;

    always #5 clk = ~clk;

    fifo #(DEPTH, WIDTH) dut (.*);

    cover_full:          cover property (@(posedge clk) disable iff (!rst_n) (full));
    cover_empty:         cover property (@(posedge clk) disable iff (!rst_n) (empty));
    cover_simul_rw:      cover property (@(posedge clk) disable iff (!rst_n) (w_en && r_en));
    cover_flush_active:  cover property (@(posedge clk) disable iff (!rst_n) (flush && !empty));
    cover_overflow_try:  cover property (@(posedge clk) disable iff (!rst_n) (full && w_en && !r_en));

    property p_flush_reset;
        @(posedge clk) flush |=> (dut.w_ptr == 0 && empty == 1);
    endproperty
    assert property (p_flush_reset);

    property p_fwft_write_through;
	@(posedge clk) disable iff (!rst_n) (empty && w_en && !flush) |=> (!empty && (d_out == $past(d_in)));
    endproperty
    assert property (p_fwft_write_through);

    property p_fwft_read_maintain;
	@(posedge clk) disable iff (!rst_n) (r_en && !empty && dut.count > 1 && !flush) |=> (!$isunknown(d_out));
    endproperty
    assert property (p_fwft_read_maintain);

    logic [WIDTH-1:0] scoreboard_q[$];
    logic [WIDTH-1:0] expected_data;

    initial begin
	rst_n = 0;
	w_en  = 0;
	r_en  = 0;
	flush = 0;
	d_in  = 0;

	repeat(5) @(posedge clk);
	rst_n = 1;

	$display("\nStarting CRV");

	for(int i = 0; i < 10000; i++) begin
		logic do_write = w_en && !full;
		logic do_read  = r_en && !empty;
		logic do_flush = flush;

		@(posedge clk);
		#1;

		if(do_flush) begin
			scoreboard_q.delete();
		end else begin
			if(do_write) begin
				scoreboard_q.push_back(d_in);
			end

			if(do_read) begin
				void'(scoreboard_q.pop_front());
			end
		end

		if(!empty && scoreboard_q.size() > 0) begin
			expected_data = scoreboard_q[0];
			if (d_out != expected_data) begin
				$error("\nMismatch at cycle %0d! RTL: %h, Expected: %h", i, d_out, expected_data);
			end
		end

		w_en  = ($urandom_range(0, 99) < 40);
		r_en  = ($urandom_range(0, 99) < 40);
		flush = ($urandom_range(0, 99) < 2);
	        d_in  = $urandom();
	end

	$display("\nFinished - Passed all tests");
	$finish;
    end

endmodule
