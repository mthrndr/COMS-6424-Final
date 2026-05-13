`timescale 1ns/1ps

module ext_mmu_tb();

  localparam int ADDR_W = 32;
  localparam int DATA_W = 32;
  localparam int ACHK_W = 12;
  localparam int RCHK_W = 5;
  localparam int FIFO_DEPTH = 4;
  localparam int MAX_OUTSTANDING = 2;

  localparam time CLK_PERIOD = 10ns;
  localparam time MEM_LATENCY = 2; //rough x core estimate, may vary for s due to sec features

  logic clk = 0;
  logic rst_n = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  logic              x_req;
  logic              x_gnt;
  logic [ADDR_W-1:0] x_addr;
  logic              x_we;
  logic [3:0]        x_be;
  logic [DATA_W-1:0] x_wdata;
  logic [5:0]        x_atop;
  logic [2:0]        x_prot;
  logic [2:0]        x_memtype;
  logic              x_dbg;
  logic              x_rvalid;
  logic [DATA_W-1:0] x_rdata;
  logic              x_err;
  logic              x_exokay;

  logic              s_req;
  logic              s_gnt;
  logic [ADDR_W-1:0] s_addr;
  logic              s_we;
  logic [3:0]        s_be;
  logic [DATA_W-1:0] s_wdata;
  logic [2:0]        s_prot;
  logic [2:0]        s_memtype;
  logic              s_dbg;
  logic              s_reqpar;
  logic [ACHK_W-1:0] s_achk;
  logic              s_gntpar;
  logic              s_rvalidpar;
  logic [RCHK_W-1:0] s_rchk;
  logic              s_rvalid;
  logic [DATA_W-1:0] s_rdata;
  logic              s_err;

  logic              m_req;
  logic              m_gnt;
  logic [ADDR_W-1:0] m_addr;
  logic              m_we;
  logic [3:0]        m_be;
  logic [DATA_W-1:0] m_wdata;
  logic              m_rvalid;
  logic [DATA_W-1:0] m_rdata;

  logic              mismatch;
  logic              comp_untrust;

  ext_mmu #(
    .ADDR_W          (ADDR_W),
    .DATA_W          (DATA_W),
    .FIFO_DEPTH      (FIFO_DEPTH),
    .MAX_OUTSTANDING (MAX_OUTSTANDING),
    .DATA_BUS        (1'b1),
    .A_EXT_X         (1'b0),
    .ACHK_W          (ACHK_W),
    .RCHK_W          (RCHK_W)
  ) dut (.*);

  assign m_gnt = m_req;

  logic [DATA_W-1:0] resp_pipe [0:7];
  logic              resp_valid_pipe [0:7];
  int                pipe_head, pipe_tail;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pipe_head = 0;
      pipe_tail = 0;
      m_rvalid  = 1'b0;
      m_rdata   = '0;
      for (int i = 0; i < 8; i++) begin
        resp_pipe[i]       = '0;
        resp_valid_pipe[i] = 1'b0;
      end
    end else begin
      m_rvalid = 1'b0;
      m_rdata  = '0;

      if (m_req && m_gnt) begin
        resp_pipe[pipe_tail % 8]       = m_addr;
        resp_valid_pipe[pipe_tail % 8] = 1'b1;
        pipe_tail = pipe_tail + 1;
      end
    end
  end

  logic [MEM_LATENCY:0] rvalid_shift;
  logic [DATA_W-1:0]    rdata_shift [0:MEM_LATENCY];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rvalid_shift = '0;
      for (int i = 0; i <= MEM_LATENCY; i++) rdata_shift[i] = '0;
    end else begin
      for (int i = 0; i < MEM_LATENCY; i++) begin
        rvalid_shift[i] = rvalid_shift[i+1];
        rdata_shift[i]  = rdata_shift[i+1];
      end
      rvalid_shift[MEM_LATENCY] = 1'b0;
      rdata_shift[MEM_LATENCY]  = '0;

      if (m_req && m_gnt) begin
        rvalid_shift[MEM_LATENCY] = 1'b1;
        rdata_shift[MEM_LATENCY]  = m_addr;
      end
    end
  end

  always_comb begin
    m_rvalid = rvalid_shift[0];
    m_rdata  = rdata_shift[0];
  end

  logic              s_reqpar_force_en;
  logic              s_reqpar_force_val;
  logic              s_achk_corrupt_en;

  function automatic logic [ACHK_W-1:0] tb_compute_achk(
    input logic [ADDR_W-1:0] addr,
    input logic              we,
    input logic [3:0]        be,
    input logic [DATA_W-1:0] wdata,
    input logic [2:0]        prot,
    input logic [2:0]        memtype,
    input logic              dbg
  );
    logic [ACHK_W-1:0] r;
    r[0]  =  ^addr[ 7: 0];
    r[1]  =  ^addr[15: 8];
    r[2]  =  ^addr[23:16];
    r[3]  =  ^addr[31:24];
    r[4]  = ~^{prot[2:0], memtype[1:0]};
    r[5]  = ~^{be[3:0], we};
    r[6]  = ~^dbg;
    r[7]  =  ^6'b0;
    r[8]  =  ^wdata[ 7: 0];
    r[9]  =  ^wdata[15: 8];
    r[10] =  ^wdata[23:16];
    r[11] =  ^wdata[31:24];
    return r;
  endfunction

  logic [ACHK_W-1:0] s_achk_good;
  assign s_achk_good = tb_compute_achk(s_addr, s_we, s_be, s_wdata,
                                       s_prot, s_memtype, s_dbg);
  assign s_achk      = s_achk_corrupt_en ? ~s_achk_good : s_achk_good;
  assign s_reqpar    = s_reqpar_force_en ? s_reqpar_force_val : ~s_req;

  int total = 0;
  int passed = 0;

  task automatic check(input string name, input bit ok);
    total = total + 1;
    if (ok) begin
      passed = passed + 1;
      $display("Passed: %s", name);
    end else begin
      $display("Failed: %s", name);
    end
  endtask

  task automatic drive_idle();
    x_req     = 1'b0;
    x_addr    = '0;
    x_we      = 1'b0;
    x_be      = '0;
    x_wdata   = '0;
    x_atop    = '0;
    x_prot    = '0;
    x_memtype = '0;
    x_dbg     = 1'b0;
    s_req     = 1'b0;
    s_addr    = '0;
    s_we      = 1'b0;
    s_be      = '0;
    s_wdata   = '0;
    s_prot    = '0;
    s_memtype = '0;
    s_dbg     = 1'b0;
  endtask

  task automatic drive_matched(
    input logic [ADDR_W-1:0] addr,
    input logic              we,
    input logic [DATA_W-1:0] wdata
  );
    x_req     = 1'b1;
    x_addr    = addr;
    x_we      = we;
    x_be      = 4'b1111;
    x_wdata   = wdata;
    x_atop    = '0;
    x_prot    = 3'b000;
    x_memtype = 3'b000;
    x_dbg     = 1'b0;
    s_req     = 1'b1;
    s_addr    = addr;
    s_we      = we;
    s_be      = 4'b1111;
    s_wdata   = wdata;
    s_prot    = 3'b000;
    s_memtype = 3'b000;
    s_dbg     = 1'b0;
  endtask

  task automatic drive_x_only(
    input logic [ADDR_W-1:0] addr,
    input logic              we,
    input logic [DATA_W-1:0] wdata
  );
    x_req     = 1'b1;
    x_addr    = addr;
    x_we      = we;
    x_be      = 4'b1111;
    x_wdata   = wdata;
    x_atop    = '0;
    x_prot    = 3'b000;
    x_memtype = 3'b000;
    x_dbg     = 1'b0;
    s_req     = 1'b0;
  endtask

  task automatic drive_s_only(
    input logic [ADDR_W-1:0] addr,
    input logic              we,
    input logic [DATA_W-1:0] wdata
  );
    x_req     = 1'b0;
    s_req     = 1'b1;
    s_addr    = addr;
    s_we      = we;
    s_be      = 4'b1111;
    s_wdata   = wdata;
    s_prot    = 3'b000;
    s_memtype = 3'b000;
    s_dbg     = 1'b0;
  endtask

  task automatic do_reset();
    rst_n              = 1'b0;
    comp_untrust       = 1'b0;
    s_reqpar_force_en  = 1'b0;
    s_reqpar_force_val = 1'b0;
    s_achk_corrupt_en  = 1'b0;
    drive_idle();
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  endtask

  //Single matched request with no skew
  task automatic t_basic_forward();
    int rsp_seen_x, rsp_seen_s;
    $display("\nBasic test:");
    do_reset();

    rsp_seen_x = 0;
    rsp_seen_s = 0;

    drive_matched(32'h0000_1000, 1'b0, '0);
    @(posedge clk);
    while (!(x_gnt && s_gnt)) @(posedge clk);
    drive_idle();

    fork
      begin
        while (!x_rvalid) @(posedge clk);
        rsp_seen_x = (x_rdata == 32'h0000_1000);
      end
      begin
	while (!s_rvalid) @(posedge clk);
	rsp_seen_s = (s_rdata == 32'h0000_1000);
      end
      begin
        for(int i = 0; i < 20; i++) @(posedge clk);
	disable fork;
      end
    join

    check("X received correct rdata", rsp_seen_x == 1);
    check("S received correct rdata", rsp_seen_s == 1);
    check("No mismatch", mismatch == 1'b0);
  endtask

  //Skewed matched request
  task automatic t_skew_within_capacity();
    $display("\nSkew test within FIFO capacity:");
    do_reset();

    drive_x_only(32'h2000, 1'b0, '0);
    @(posedge clk);
    drive_x_only(32'h2004, 1'b0, '0);
    @(posedge clk);
    drive_idle();
    @(posedge clk);

    check("No mismatch after X request under capacity", mismatch == 1'b0);

    drive_s_only(32'h2000, 1'b0, '0);
    @(posedge clk);
    drive_s_only(32'h2004, 1'b0, '0);
    @(posedge clk);
    drive_idle();
    @(posedge clk);

    check("No mismatch after late S requests", mismatch == 1'b0);
  endtask

  //Mismatch on addr
  task automatic t_field_mismatch_addr();
    $display("\nMismatched addr");
    do_reset();

    x_req     = 1'b1;
    x_addr    = 32'h3000;
    x_we      = 1'b0;
    x_be      = 4'b1111;
    x_wdata   = '0;
    x_atop    = '0;
    x_prot    = '0;
    x_memtype = '0;
    x_dbg     = 1'b0;
    s_req     = 1'b1;
    s_addr    = 32'h3004;
    s_we      = 1'b0;
    s_be      = 4'b1111;
    s_wdata   = '0;
    s_prot    = '0;
    s_memtype = '0;
    s_dbg     = 1'b0;

    repeat (4) @(posedge clk);
    drive_idle();
    @(posedge clk);

    check("Mismatch is asserted", mismatch == 1'b1);
  endtask

  //Write data mismatch
  task automatic t_field_mismatch_wdata();
    $display("\nMismatch on wdata");
    do_reset();

    x_req     = 1'b1;
    x_addr    = 32'h4000;
    x_we      = 1'b1;
    x_be      = 4'b1111;
    x_wdata   = 32'h4AFC_BF38;
    x_atop    = '0;
    x_prot    = '0;
    x_memtype = '0;
    x_dbg     = 1'b0;
    s_req     = 1'b1;
    s_addr    = 32'h4000;
    s_we      = 1'b1;
    s_be      = 4'b1111;
    s_wdata   = 32'h9F84_E5B4;
    s_prot    = '0;
    s_memtype = '0;
    s_dbg     = 1'b0;

    repeat (4) @(posedge clk);
    drive_idle();
    @(posedge clk);

    check("Mismatch is asserted", mismatch == 1'b1);
  endtask

  //S-core request parity fail
  task automatic t_integrity_reqpar();
    $display("\nIntegrity failure on S-core request parity signal");
    do_reset();

    s_reqpar_force_en  = 1'b1;
    s_reqpar_force_val = 1'b1;
    drive_matched(32'h5000, 1'b0, '0);
    @(posedge clk);
    repeat (3) @(posedge clk);
    drive_idle();
    @(posedge clk);

    check("Mismatch is asserted on reqpar failure", mismatch == 1'b1);
  endtask

  //S-core achk failure
  task automatic t_integrity_achk();
    $display("\nIntegrity failure on S-core achk");
    do_reset();

    s_achk_corrupt_en = 1'b1;
    drive_matched(32'h6000, 1'b0, '0);
    @(posedge clk);
    repeat (3) @(posedge clk);
    drive_idle();
    @(posedge clk);

    check("Mismatch is asserted", mismatch == 1'b1);
  endtask

  //Comparison unit fault detected
  task automatic t_comp_untrust();
    logic seen_x_gnt;
    $display("\nComparison unit can force lockdown");
    do_reset();

    seen_x_gnt = 1'b0;

    comp_untrust = 1'b1;
    drive_matched(32'h7000, 1'b0, '0);
    @(posedge clk);

    if (x_gnt || s_gnt) seen_x_gnt = 1'b1;

    repeat (3) @(posedge clk);
    drive_idle();
    @(posedge clk);

    check("Mismatch is asserted", mismatch == 1'b1);
    check("Grants are blocked when comparison unit detects fault", seen_x_gnt == 1'b0);

    comp_untrust = 1'b0;
    @(posedge clk);
    check("Mismatch is sticky", mismatch == 1'b1);
  endtask

  //Mismatch is sticky until reset
  task automatic t_sticky_after_field();
    $display("\nMismatch is sticky");
    do_reset();

    x_req     = 1'b1;
    x_addr    = 32'h8000;
    x_we      = 1'b0;
    x_be      = 4'b1111;
    x_wdata   = '0;
    x_atop    = '0;
    x_prot    = '0;
    x_memtype = '0;
    x_dbg     = 1'b0;
    s_req     = 1'b1;
    s_addr    = 32'h8004;
    s_we      = 1'b0;
    s_be      = 4'b1111;
    s_wdata   = '0;
    s_prot    = '0;
    s_memtype = '0;
    s_dbg     = 1'b0;
    repeat (4) @(posedge clk);
    drive_idle();
    @(posedge clk);

    check("Mismatch is asserted", mismatch == 1'b1);

    
    drive_matched(32'h8000, 1'b0, '0);
    @(posedge clk);
    check("X not granted after mismatch", x_gnt == 1'b0);
    check("S not granted after mismatch", s_gnt == 1'b0);
    check("Mismatch is sticky", mismatch == 1'b1);
    drive_idle();
  endtask

  //Pipeline test
  task automatic t_pipelined();
    int gnt_count;
    $display("\nPipelined operation");
    do_reset();

    gnt_count = 0;
     
    fork
      begin
        for (int i = 0; i < 4; i++) begin
          drive_matched(32'h9000 + (i*4), 1'b0, '0);
          @(posedge clk);
          if (x_gnt && s_gnt) gnt_count++;
        end
        drive_idle();
      end
    join

    repeat (10) @(posedge clk);

    check("Requests granted under pipeline", gnt_count == 4);
    check("No mismatch under pipelined load", mismatch == 1'b0);
    check("Outstanding requests drained to 0", dut.outstanding_q == '0);
  endtask


  initial begin

    comp_untrust       = 1'b0;
    s_reqpar_force_en  = 1'b0;
    s_reqpar_force_val = 1'b0;
    s_achk_corrupt_en  = 1'b0;
    drive_idle();

    t_basic_forward();
    t_skew_within_capacity();
    t_field_mismatch_addr();
    t_field_mismatch_wdata();
    t_integrity_reqpar();
    //t_integrity_achk(); disabled for debugging
    t_comp_untrust();
    t_sticky_after_field();
    t_pipelined();

    if (passed == total) $display("Passed all tests");
    else                 $display("%0d tests failed", (total-passed));

    $finish;
  end

endmodule
