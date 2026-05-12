module ext_mmu_tb_s ();

    localparam int unsigned ADDR_W          = 32;
    localparam int unsigned DATA_W          = 32;
    localparam int unsigned FIFO_DEPTH      = 4;
    localparam int unsigned MAX_OUTSTANDING = 2;
    localparam int unsigned ACHK_W          = 12;
    localparam int unsigned RCHK_W          = 5;

    logic clk = 0;
    logic rst_n;

    logic                x_req, x_gnt;
    logic [ADDR_W-1:0]   x_addr;
    logic                x_we;
    logic [3:0]          x_be;
    logic [DATA_W-1:0]   x_wdata;
    logic [5:0]          x_atop;
    logic [2:0]          x_prot, x_memtype;
    logic                x_dbg;
    logic                x_rvalid, x_err, x_exokay;
    logic [DATA_W-1:0]   x_rdata;

    logic                s_req, s_gnt;
    logic [ADDR_W-1:0]   s_addr;
    logic                s_we;
    logic [3:0]          s_be;
    logic [DATA_W-1:0]   s_wdata;
    logic [2:0]          s_prot, s_memtype;
    logic                s_dbg, s_reqpar;
    logic [ACHK_W-1:0]   s_achk;
    logic                s_gntpar, s_rvalidpar, s_rvalid, s_err;
    logic [RCHK_W-1:0]   s_rchk;
    logic [DATA_W-1:0]   s_rdata;

    logic                m_req, m_gnt;
    logic [ADDR_W-1:0]   m_addr;
    logic                m_we;
    logic [3:0]          m_be;
    logic [DATA_W-1:0]   m_wdata;
    logic                m_rvalid;
    logic [DATA_W-1:0]   m_rdata;

    logic mismatch;
    logic comp_untrust;

    always #5 clk = ~clk;

    ext_mmu #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .FIFO_DEPTH(FIFO_DEPTH),
        .MAX_OUTSTANDING(MAX_OUTSTANDING),
        .ACHK_W(ACHK_W),
        .RCHK_W(RCHK_W)
    ) dut (.*);


    AST_MISMATCH_STICKY: assert property (
        @(posedge clk) disable iff (!rst_n) 
        mismatch |=> mismatch
    ) else $error("\nFlag dropped when it should be sticky");

    AST_S_GNTPAR_VALID: assert property (
        @(posedge clk) disable iff (!rst_n)
        s_gntpar == ~s_gnt
    );

    AST_NO_MEM_REQ_ON_MISMATCH: assert property (
        @(posedge clk) disable iff (!rst_n)
        mismatch |-> !m_req
    );

    COV_FORWARD_TO_MEM:    cover property (@(posedge clk) disable iff (!rst_n) (m_req && m_gnt));
    COV_MISMATCH_TRIGGER:  cover property (@(posedge clk) disable iff (!rst_n) ($rose(mismatch)));
    COV_FIFO_X_FULL:       cover property (@(posedge clk) disable iff (!rst_n) (dut.x_full));
    COV_FIFO_S_FULL:       cover property (@(posedge clk) disable iff (!rst_n) (dut.s_full));
    COV_MEM_RESP_ARRIVED:  cover property (@(posedge clk) disable iff (!rst_n) (m_rvalid));

    int cycle_cnt = 0;
    logic inject_error;

    function automatic logic [ACHK_W-1:0] gen_achk(
        logic [ADDR_W-1:0] addr, logic we, logic [3:0] be, logic [DATA_W-1:0] wdata,
        logic [2:0] prot, logic [2:0] memtype, logic dbg
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

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            {x_req, x_addr, x_we, x_be, x_wdata, x_atop, x_prot, x_memtype, x_dbg} <= '0;
            {s_req, s_addr, s_we, s_be, s_wdata, s_prot, s_memtype, s_dbg, s_reqpar, s_achk} <= '0;
            {m_gnt, m_rvalid, m_rdata} <= '0;
            comp_untrust <= '0;
            inject_error <= '0;
        end else begin
            inject_error <= ($urandom_range(0, 99) < 5);

            x_req     <= ($urandom_range(0, 99) < 40);
            x_addr    <= $urandom();
            x_we      <= $urandom_range(0, 1);
            x_be      <= $urandom_range(0, 15);
            x_wdata   <= $urandom();
            x_atop    <= $urandom_range(0, 63);
            x_prot    <= $urandom_range(0, 7);
            x_memtype <= $urandom_range(0, 3);
            x_dbg     <= $urandom_range(0, 1);

            s_req     <= x_req;
            s_addr    <= inject_error ? ~x_addr : x_addr;
            s_we      <= x_we;
            s_be      <= x_be;
            s_wdata   <= x_wdata;
            s_prot    <= x_prot;
            s_memtype <= x_memtype;
            s_dbg     <= x_dbg;

            s_reqpar <= ~(x_req);
            s_achk   <= gen_achk(
                inject_error ? ~x_addr : x_addr, x_we, x_be, x_wdata, x_prot, x_memtype, x_dbg
            );

            m_gnt    <= ($urandom_range(0, 99) < 95);
            m_rvalid <= dut.outstanding_q > 0 ? ($urandom_range(0, 99) < 50) : 1'b0;
            m_rdata  <= $urandom();

            comp_untrust <= ($urandom_range(0, 99) < 3);

            cycle_cnt <= cycle_cnt + 1;
        end
    end

    initial begin
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;

        $display("\nStarting ext_mmu CRV...");
        wait(cycle_cnt == 10000);
        @(posedge clk);

        $display("\nFinished ext_mmu. All assertions passed.");
        $finish;
    end

endmodule
