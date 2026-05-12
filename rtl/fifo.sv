// Simple FIFO for use in the comparator

module fifo #(
	parameter DEPTH = 8,
    parameter WIDTH = 32
)(
    input   logic               rst_n,
    input   logic               clk,
    input   logic               w_en,
    input   logic               r_en,
    input   logic		flush,
    input   logic   [WIDTH-1:0] d_in,
    output  logic   [WIDTH-1:0] d_out,
    output  logic              	empty,
    output  logic               full
);

    reg [$clog2(DEPTH)-1:0] w_ptr, r_ptr;
    reg [WIDTH-1:0]         fifo[DEPTH];
    logic [WIDTH-1:0] count;

    logic   valid_w, valid_r;
    assign  valid_w = w_en & !full;
    assign  valid_r = r_en & !empty;

    assign  d_out = fifo[r_ptr];

    // assign full = ((w_ptr+1'b1) == r_ptr);
    // assign empty = (w_ptr == r_ptr);
    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    always@(posedge clk) begin
        if (!rst_n) begin
            w_ptr   <= 0;
            r_ptr   <= 0;
	    count   <= 0;
        end else begin
            // Write logic
           
            // We always
            if (valid_w) begin
                fifo[w_ptr] <= d_in;
            end
	    if (flush) begin
		w_ptr	    <= 0;
		r_ptr	    <= 0;
		count 	    <= 0;
	    end else if (valid_w && valid_r) begin
                w_ptr       <= w_ptr + 1;
                r_ptr       <= r_ptr + 1;
            end else if (valid_w) begin
                w_ptr       <= w_ptr + 1;
		count	    <= count + 1;
            end else if (valid_r) begin
                r_ptr       <= r_ptr + 1;
		count	    <= count - 1;
	    end
        end
    end

endmodule
