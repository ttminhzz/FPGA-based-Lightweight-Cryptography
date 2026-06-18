`timescale 1ns/1ps
module tb_present80_encrypt;
    reg clk;
    reg rst_n;
    reg start;
    reg [63:0] plaintext;
    reg [79:0] key;
    wire [63:0] ciphertext;
    wire busy, done, ready;

    present80_encrypt dut (
        .clk(clk), .rst_n(rst_n), .start(start), .plaintext(plaintext), .key(key),
        .ciphertext(ciphertext), .busy(busy), .done(done), .ready(ready)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;  // 50 MHz

    initial begin
        rst_n = 1'b0;
        start = 1'b0;
        plaintext = 64'h0000000000000000;
        key = 80'h00000000000000000000;
        #100;
        rst_n = 1'b1;
        #40;
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(done == 1'b1);
        #1;
        if (ciphertext !== 64'h5579C1387B228445) begin
            $display("FAIL: ciphertext=%h expected=5579C1387B228445", ciphertext);
            $stop;
        end else begin
            $display("PASS: PRESENT-80 test vector matched. ciphertext=%h", ciphertext);
        end
        #100;
        $finish;
    end
endmodule
