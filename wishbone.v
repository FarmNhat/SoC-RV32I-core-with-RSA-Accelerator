`include "top.v"

module wb_rsa #(
    parameter WIDTH = 32,
    parameter E_BITS = 32
)(
    input clk,
    input rst,

    // Wishbone
    // mấy port này sẽ kết nối thẳng với cpu để quản lý
    // khi có lệnh load và store sẽ tự động vận hành các tín hiệu này để chạy wishbone
    // module này chỉ mất 1 chu kì để truyền data vào mem nên dễ
    input [31:0] wb_adr_i,
    input [31:0] wb_dat_i,
    output reg [31:0] wb_dat_o,
    input wb_we_i,
    input wb_stb_i,
    input wb_cyc_i,
    output reg wb_ack_o
);

//////////////////////////
// Registers
//////////////////////////

reg start;
wire done;

reg [WIDTH-1:0] M;
reg [E_BITS-1:0] E;
reg [WIDTH-1:0] N;
reg [WIDTH-1:0] N_INV;
reg [WIDTH-1:0] R2_MOD_N;
wire [WIDTH-1:0] C;

//////////////////////////
// Wishbone handshake
//////////////////////////

always @(posedge clk) begin
    wb_ack_o <= 0;

    if(wb_stb_i && wb_cyc_i && !wb_ack_o) begin
        wb_ack_o <= 1;

        if(wb_we_i) begin   // này dùng khi gặp lệnh store, có thể đưa trực tiếp vào riscv datapath
            case(wb_adr_i[5:2]) // bỏ 2 bit đầu do là 1 byte 4 bit
                // điều khiển rsa theo từng addr 2,3,4,5,6
                0: start     <= wb_dat_i[0];
                2: M         <= wb_dat_i;
                3: E         <= wb_dat_i;
                4: N         <= wb_dat_i;
                5: N_INV     <= wb_dat_i;
                6: R2_MOD_N  <= wb_dat_i;

            endcase
        end
        else begin
            case(wb_adr_i[5:2]) // này dùng khi gặp lệnh load, có thể đưa trực tiếp vào riscv datapath

                1: wb_dat_o <= {31'b0, done};
                7: wb_dat_o <= C;

                default: wb_dat_o <= 32'h0;

            endcase
        end
    end
end

//////////////////////////
// Auto-clear start (QUAN TRỌNG)
//////////////////////////

always @(posedge clk) begin
    if(rst)
        start <= 0;
    else if(done)
        start <= 0;   // tránh retrigger
end

//////////////////////////
// Instantiate RSA
//////////////////////////

rsa #(
    .WIDTH(WIDTH),
    .E_BITS(E_BITS)
) rsa_core (

    .clk(clk),
    .rst(rst),
    .start(start),

    .M(M),
    .E(E),
    .N(N),
    .N_INV(N_INV),
    .R2_MOD_N(R2_MOD_N),

    .C(C),
    .done(done)
);

endmodule
