`timescale 1ps/1ps
`include "top.v"

module tb_rsa_mod_exp;

    parameter WIDTH  = 64;
    parameter E_BITS = 64;

    reg clk;
    reg rst;
    reg start;

    reg  [WIDTH-1:0]  M;
    reg  [E_BITS-1:0] E;
    reg  [WIDTH-1:0]  N;
    reg  [WIDTH-1:0]  N_INV;
    reg  [WIDTH-1:0]  R2_MOD_N;

    wire [WIDTH-1:0]  C;
    wire              done;

    // DUT
    rsa #(
        .WIDTH(WIDTH),
        .E_BITS(E_BITS)
    ) dut (
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

    // Clock 100 MHz
    always #5 clk = ~clk;

    initial begin
        // init
        clk = 0;
        rst = 1;
        start = 0;

        // Test vector
        M         = "nhatnhat";
        E         = 64'd4;
        N         = 64'd11;
        N_INV     = 64'd15092790605762360413; // -17^{-1} mod 2^32
        R2_MOD_N  = 64'd3;         // R^2 mod 17

        // reset
        #20;
        rst = 0;

        // start RSA
        #10;
        start = 1;
        #10;
        start = 0;

        // wait result
        wait(done);

        $display("=================================");
        $display("RSA RESULT");
        $display("M = %0d", M);
        $display("E = %0d", E);
        $display("N = %0d", N);
        $display("C = %0d", C);
        //$display("EXPECTED = 6");
        $display("=================================");

        #20;
        $finish;
    end

endmodule
