module ext_mmu #(
  parameter int unsigned ADDR_W          = 32,
  parameter int unsigned DATA_W          = 32,
  parameter int unsigned FIFO_DEPTH      = 4, //Make this 64 for div heavy programs
  parameter int unsigned MAX_OUTSTANDING = 2,
  parameter bit          DATA_BUS        = 1'b1, // D-bus = 1, I-bus = 0 - I-bus on s-core will be weird because of dummy instructions
  parameter bit          A_EXT_X         = 1'b0, // 1 if cv32e40x has A extension
  parameter int unsigned ACHK_W          = 12,
  parameter int unsigned RCHK_W          = 5
) (
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

  typedef struct packed {
    logic [ADDR_W-1:0] addr;
    logic              we;
    logic [3:0]        be;
    logic [DATA_W-1:0] wdata;
    logic [2:0]        prot;
    logic [2:0]        memtype;
    logic              dbg;
  } common_req_t;

  typedef struct packed {
    logic [5:0] atop;
  } x_extra_t;

  typedef struct packed {
    logic [ACHK_W-1:0] achk;
  } s_extra_t;           

  typedef struct packed {
    common_req_t common;
    x_extra_t    extra;
  } x_entry_t;

  typedef struct packed {
    common_req_t common;
    s_extra_t    extra;  
  } s_entry_t;

  common_req_t x_pkt, s_pkt;

  always_comb begin
    x_pkt.addr    = x_addr;
    x_pkt.we      = x_we;
    x_pkt.be      = x_be;
    x_pkt.wdata   = x_wdata;
    x_pkt.prot    = x_prot;
    x_pkt.memtype = x_memtype;
    x_pkt.dbg     = x_dbg;

    s_pkt.addr    = s_addr;
    s_pkt.we      = s_we;
    s_pkt.be      = s_be;
    s_pkt.wdata   = s_wdata;
    s_pkt.prot    = s_prot;
    s_pkt.memtype = s_memtype;
    s_pkt.dbg     = s_dbg;
  end

  x_entry_t x_entry_in;
  s_entry_t s_entry_in;
  assign x_entry_in.common     = x_pkt;
  assign x_entry_in.extra.atop = x_atop;
  assign s_entry_in.common     = s_pkt;
  assign s_entry_in.extra.achk = s_achk;

  logic              reqpar_ok;
  logic [ACHK_W-1:0] expected_achk;
  logic              achk_ok;
  logic              s_integrity_fail;

  assign reqpar_ok = (s_reqpar == ~s_req);

  assign expected_achk = compute_achk(
    s_addr, s_we, s_be, s_wdata,
    s_prot, s_memtype, s_dbg
  );
  assign achk_ok = (s_achk == expected_achk);

  assign s_integrity_fail = (s_req && (!reqpar_ok || !achk_ok)) || (!s_req && !reqpar_ok);

  logic mm_field_q, mm_integrity_q, mismatch_q;
  logic mm_field_set, mm_integrity_set;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mm_field_q     <= 1'b0;
      mm_integrity_q <= 1'b0;
      mismatch_q     <= 1'b0;
    end else begin
      if (mm_field_set) begin
	mm_field_q     <= 1'b1;
      end
      if (mm_integrity_set) begin
	mm_integrity_q <= 1'b1;
      end
      if (mm_field_set || mm_integrity_set || comp_untrust) begin
        mismatch_q <= 1'b1;
      end
    end
  end

  assign mismatch = mismatch_q || comp_untrust;
   
  logic     x_full, x_empty, x_push, x_pop;
  logic     s_full, s_empty, s_push, s_pop;
  x_entry_t x_dout;
  s_entry_t s_dout;

  logic safe;
  assign safe = !mismatch_q && !comp_untrust;

  assign x_push = x_req && !x_full && safe;
  assign s_push = s_req && !s_full && safe && !s_integrity_fail;

  assign x_gnt    = x_push;
  assign s_gnt    = s_push;
  assign s_gntpar = ~s_gnt;

  logic flush_fifos;
  assign flush_fifos = mismatch || mm_field_set || mm_integrity_set;

  fifo #(
    .DEPTH (FIFO_DEPTH),
    .WIDTH ($bits(x_entry_t))
  ) i_x_fifo (
    .clk   (clk),
    .rst_n (rst_n),
    .flush (flush_fifos),
    .w_en  (x_push),
    .r_en  (x_pop),
    .d_in  (x_entry_in),
    .d_out (x_dout),
    .full  (x_full),
    .empty (x_empty)
  );

  fifo #(
    .DEPTH (FIFO_DEPTH),
    .WIDTH ($bits(s_entry_t))
  ) i_s_fifo (
    .clk   (clk),
    .rst_n (rst_n),
    .flush (flush_fifos),
    .w_en  (s_push),
    .r_en  (s_pop),
    .d_in  (s_entry_in),
    .d_out (s_dout),
    .full  (s_full),
    .empty (s_empty)
  );

  logic both_head_valid;
  logic heads_match;

  assign both_head_valid = !x_empty && !s_empty;
  assign heads_match     = (x_dout.common == s_dout.common);

  assign mm_field_set     = both_head_valid && !heads_match;
  assign mm_integrity_set = s_integrity_fail;

  localparam int unsigned OUT_W = (MAX_OUTSTANDING <= 1) ? 1 : $clog2(MAX_OUTSTANDING + 1);

  logic [OUT_W-1:0] outstanding_q, outstanding_d;
  logic             mem_addr_hs;
  logic             mem_resp_hs;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) outstanding_q <= '0;
    else        outstanding_q <= outstanding_d;
  end

  always_comb begin
    outstanding_d = outstanding_q;
    case ({mem_addr_hs, mem_resp_hs})
      2'b10:   outstanding_d = outstanding_q + 1'b1;
      2'b01:   outstanding_d = outstanding_q - 1'b1;
      default: outstanding_d = outstanding_q;
    endcase
  end

  logic outstanding_room;
  assign outstanding_room = (outstanding_q < MAX_OUTSTANDING[OUT_W-1:0]);

  logic forward;
  assign forward = both_head_valid && heads_match
                && outstanding_room && !mismatch_q;

  assign m_req     = forward;
  assign m_addr    = x_dout.common.addr;
  assign m_we      = x_dout.common.we;
  assign m_be      = x_dout.common.be;
  assign m_wdata   = x_dout.common.wdata;

  assign mem_addr_hs = m_req && m_gnt;
  assign mem_resp_hs = m_rvalid;

  assign x_pop = mem_addr_hs;
  assign s_pop = mem_addr_hs;

  assign x_rvalid = m_rvalid;
  assign x_rdata  = m_rdata;
  assign x_err    = 1'b0;
  assign x_exokay = 1'b0;

  assign s_rvalid    = m_rvalid;
  assign s_rdata     = m_rdata;
  assign s_err       = 1'b0;
  assign s_rvalidpar = ~m_rvalid;
  assign s_rchk      = compute_rchk(m_rdata, 1'b0);

  function automatic logic [ACHK_W-1:0] compute_achk(
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

  function automatic logic [RCHK_W-1:0] compute_rchk(
    input logic [DATA_W-1:0] rdata,
    input logic              err
  );
    logic [RCHK_W-1:0] r;
    r[0] = ^rdata[ 7: 0]; 
    r[1] = ^rdata[15: 8];
    r[2] = ^rdata[23:16];
    r[3] = ^rdata[31:24];
    r[4] = ^{err, 1'b0};
    return r;
  endfunction

endmodule
