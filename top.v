module montgomery_reduce #( 
    parameter WIDTH = 32 
)( 
    input  wire                   clk, 
    input  wire                   rst, 
    input  wire                   start, 
 
    input  wire [2*WIDTH-1:0]     T,      // T < N*R 
    input  wire [WIDTH-1:0]       N,      // modulus (odd) 
    input  wire [WIDTH-1:0]       N_INV,  // -N^{-1} mod R 
 
    output reg  [WIDTH-1:0]       result, 
    output reg                    done 
); 
 
    reg [WIDTH-1:0]   m; 
    reg [WIDTH+1:0]   t_reg; 
    reg [1:0]         state; 
    localparam IDLE = 0, CALC_M = 1, CALC_T = 2; 
 
    always @(posedge clk) begin 
        if (rst) begin 
            state  <= IDLE; 
            done   <= 0; 
            result <= 0; 
        end else begin 
            done <= 0; 
 
            case (state) 
            IDLE: if (start) begin 
                state <= CALC_M; 
                m <= (T[WIDTH-1:0] * N_INV); 
            end 
            CALC_M: begin 
                state <= CALC_T; 
                // t = (T + m*N) >> WIDTH 
                t_reg <= ({1'b0, T} + (m * N)) >> WIDTH; 
            end 
            CALC_T: begin 
                state <= IDLE; 
                if (t_reg >= N) 
                    result <= t_reg - N; 
                else 
                    result <= t_reg; 
                done <= 1; 
            end 
            endcase 
        end 
    end 
endmodule 
 
 
 
module montgomery_mul #( 
    parameter WIDTH = 32 
)( 
    input  wire                   clk, 
    input  wire                   rst, 
    input  wire                   start, 
 
    input  wire [WIDTH-1:0]       A, 
    input  wire [WIDTH-1:0]       B, 
    input  wire [WIDTH-1:0]       N, 
    input  wire [WIDTH-1:0]       N_INV, 
 
    output wire [WIDTH-1:0]       result, 
    output wire                   done 
); 
 
    wire [2*WIDTH-1:0] T; 
    assign T = A * B; 
 
    montgomery_reduce #(.WIDTH(WIDTH)) u_red ( 
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .T(T), 
        .N(N), 
        .N_INV(N_INV), 
        .result(result), 
        .done(done) 
    ); 
endmodule 
 
 
/* 
 
Chuẩn bị ngoài module 
    k = WIDTH 
    R = 2^k 
    N_INV = -N^{-1} mod R 
    R2_MOD_N = R^2 mod N 
 
Với: 
    R = 2^k 
    N_INV = −N^(−1) mod R 
 
Module để tính: 
    C = M^E mod N 
 
** N phải có sẵn (cũng là tính chất của RSA) ** 
 
*/ 
 
module rsa #( 
    parameter WIDTH = 32, 
    parameter E_BITS = 32 
)( 
    input  wire                   clk, 
    input  wire                   rst, 
    input  wire                   start, 
 
    input  wire [WIDTH-1:0]       M, 
    input  wire [E_BITS-1:0]      E, 
    input  wire [WIDTH-1:0]       N, 
    input  wire [WIDTH-1:0]       N_INV, 
    input  wire [WIDTH-1:0]       R2_MOD_N, // R^2 mod N 
 
    output reg  [WIDTH-1:0]       C, 
    output reg                    done 
); 
 
    // FSM states 
    localparam IDLE         = 0, 
               CONV_M       = 1, 
               CONV_R       = 2, 
               LOOP_START   = 3, 
               SQUARE_WAIT  = 4, 
               MULT_WAIT    = 5, 
               REDUCE_START = 6, 
               REDUCE_WAIT  = 7; 
 
    reg [2:0] state; 
    reg [31:0] bit_idx; 
 
    reg [WIDTH-1:0] M_bar, res_bar; 
    reg [WIDTH-1:0] A_in, B_in; 
    reg mont_start; 
    wire mont_done; 
    wire [WIDTH-1:0] mont_out; 
 
    montgomery_mul #(.WIDTH(WIDTH)) u_mont ( 
        .clk(clk), 
        .rst(rst), 
        .start(mont_start), 
        .A(A_in), 
        .B(B_in), 
        .N(N), 
        .N_INV(N_INV), 
        .result(mont_out), 
        .done(mont_done) 
    ); 
 
    always @(posedge clk) begin 
        if (rst) begin 
            state <= IDLE; 
            done  <= 0; 
            bit_idx <= 0; 
            C <= 0; 
            mont_start <= 0; 
        end else begin 
            mont_start <= 0; 
            done <= 0; 
 
            case (state) 
            IDLE: if (start) begin 
                bit_idx <= E_BITS-1; 
                A_in <= M; 
                B_in <= R2_MOD_N; 
                mont_start <= 1; 
                state <= CONV_M; 
            end  
 
            CONV_M: if (mont_done) begin 
                M_bar <= mont_out; 
                A_in <= 1; 
                B_in <= R2_MOD_N; 
                mont_start <= 1; 
                state <= CONV_R; 
            end 
 
            CONV_R: if (mont_done) begin 
                res_bar <= mont_out; 
                state <= LOOP_START; 
            end 
 
            LOOP_START: begin 
                A_in <= res_bar; 
                B_in <= res_bar; 
                mont_start <= 1; 
                state <= SQUARE_WAIT; 
            end 
 
            SQUARE_WAIT: if (mont_done) begin 
                res_bar <= mont_out; 
                if (E[bit_idx]) begin 
                    A_in <= mont_out; 
                    B_in <= M_bar; 
                    mont_start <= 1; 
                    state <= MULT_WAIT; 
                end else begin 
                    if (bit_idx == 0) state <= REDUCE_START; 
                    else begin 
                        bit_idx <= bit_idx - 1; 
                        state <= LOOP_START; 
                    end 
                end 
            end 
 
            MULT_WAIT: if (mont_done) begin 
                res_bar <= mont_out; 
                if (bit_idx == 0) state <= REDUCE_START; 
                else begin 
                    bit_idx <= bit_idx - 1; 
                    state <= LOOP_START; 
                end 
            end 
 
            REDUCE_START: begin 
                A_in <= res_bar; 
                B_in <= 1; 
                mont_start <= 1; 
                state <= REDUCE_WAIT; 
            end 
 
            REDUCE_WAIT: if (mont_done) begin 
                C <= mont_out; 
                done <= 1; 
                state <= IDLE; 
            end 
            endcase 
        end 
    end 
endmodule 
