module rsa_axi4lite_wrapper (
    input  wire         clk,
    input  wire         resetn,

    // AXI4-Lite
    input  wire [31:0]  s_axi_awaddr,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,

    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,

    output wire [1:0]   s_axi_bresp,
    output wire         s_axi_bvalid,
    input  wire         s_axi_bready,

    input  wire [31:0]  s_axi_araddr,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,

    output wire [31:0]  s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready
);

    /* RW registers */
    wire [31:0] ctrl;
    wire [31:0] M;
    wire [31:0] E;
    wire [31:0] N;
    wire [31:0] N_INV;
    wire [31:0] R2_MOD_N;

    /* RO registers */
    wire [31:0] C;
    wire [31:0] status;

    /* AXI SLAVE */
    axi4lite_slave_8rw_2ro u_axi (
        .clk(clk),
        .resetn(resetn),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .rw_reg0(ctrl),
        .rw_reg1(M),
        .rw_reg2(E),
        .rw_reg3(N),
        .rw_reg4(N_INV),
        .rw_reg5(R2_MOD_N),
        .rw_reg6(),
        .rw_reg7(),

        .ro_reg0(C),
        .ro_reg1(status)
    );

    /* Control decode */
    wire rsa_start = ctrl[0];
    wire rsa_rst   = ctrl[1];

    /* RSA CORE */
    rsa #(
        .WIDTH(32),
        .E_BITS(32)
    ) u_rsa (
        .clk(clk),
        .rst(rsa_rst),
        .start(rsa_start),

        .M(M),
        .E(E),
        .N(N),
        .N_INV(N_INV),
        .R2_MOD_N(R2_MOD_N),

        .C(C),
        .done(status[0])
    );

    assign status[31:1] = 0;

endmodule













module axi4lite_slave_8rw_2ro (
    input  wire         clk,
    input  wire         resetn,

    // AXI4-Lite
    input  wire [31:0]  s_axi_awaddr,
    input  wire         s_axi_awvalid,
    output reg          s_axi_awready,

    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output reg          s_axi_wready,

    output wire [1:0]   s_axi_bresp,
    output reg          s_axi_bvalid,
    input  wire         s_axi_bready,

    input  wire [31:0]  s_axi_araddr,
    input  wire         s_axi_arvalid,
    output reg          s_axi_arready,

    output reg [31:0]   s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output reg          s_axi_rvalid,
    input  wire         s_axi_rready,

    // Registers
    output reg [31:0]   rw_reg0,
    output reg [31:0]   rw_reg1,
    output reg [31:0]   rw_reg2,
    output reg [31:0]   rw_reg3,
    output reg [31:0]   rw_reg4,
    output reg [31:0]   rw_reg5,
    output reg [31:0]   rw_reg6,
    output reg [31:0]   rw_reg7,

    input  wire [31:0]  ro_reg0,
    input  wire [31:0]  ro_reg1
);

    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    /* WRITE ADDRESS */
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            s_axi_awready <= 1'b0;
        else
            s_axi_awready <= s_axi_awvalid & ~s_axi_awready;
    end

    /* WRITE DATA */
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_wready <= 0;
            s_axi_bvalid <= 0;

            rw_reg0 <= 0; rw_reg1 <= 0; rw_reg2 <= 0; rw_reg3 <= 0;
            rw_reg4 <= 0; rw_reg5 <= 0; rw_reg6 <= 0; rw_reg7 <= 0;

        end else begin
            s_axi_wready <= 0;

            if (s_axi_wvalid && !s_axi_wready) begin
                s_axi_wready <= 1;

                case (s_axi_awaddr[6:2])
                    0: rw_reg0 <= s_axi_wdata;
                    1: rw_reg1 <= s_axi_wdata;
                    2: rw_reg2 <= s_axi_wdata;
                    3: rw_reg3 <= s_axi_wdata;
                    4: rw_reg4 <= s_axi_wdata;
                    5: rw_reg5 <= s_axi_wdata;
                    6: rw_reg6 <= s_axi_wdata;
                    7: rw_reg7 <= s_axi_wdata;
                endcase

                s_axi_bvalid <= 1;
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 0;
            end
        end
    end

    /* READ */
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            s_axi_rdata   <= 0;
        end else begin
            s_axi_arready <= 0;

            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_arready <= 1;

                case (s_axi_araddr[6:2])
                    0: s_axi_rdata <= rw_reg0;
                    1: s_axi_rdata <= rw_reg1;
                    2: s_axi_rdata <= rw_reg2;
                    3: s_axi_rdata <= rw_reg3;
                    4: s_axi_rdata <= rw_reg4;
                    5: s_axi_rdata <= rw_reg5;
                    6: s_axi_rdata <= rw_reg6;
                    7: s_axi_rdata <= rw_reg7;
                    8: s_axi_rdata <= ro_reg0;
                    9: s_axi_rdata <= ro_reg1;
                    default: s_axi_rdata <= 32'h0;
                endcase

                s_axi_rvalid <= 1;
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 0;
            end
        end
    end

endmodule





