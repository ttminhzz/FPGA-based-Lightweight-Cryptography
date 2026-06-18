`timescale 1ns/1ps

module present80_encrypt (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] plaintext,
    input  wire [79:0] key,
    output reg  [63:0] ciphertext,
    output reg         busy,
    output reg         done,
    output wire        ready
);
    reg [63:0] state_reg;
    reg [79:0] key_reg;
    reg [4:0]  round_ctr;

    assign ready = ~busy;

    function [3:0] sbox4;
        input [3:0] x;
        begin
            case (x)
                4'h0: sbox4 = 4'hC;
                4'h1: sbox4 = 4'h5;
                4'h2: sbox4 = 4'h6;
                4'h3: sbox4 = 4'hB;
                4'h4: sbox4 = 4'h9;
                4'h5: sbox4 = 4'h0;
                4'h6: sbox4 = 4'hA;
                4'h7: sbox4 = 4'hD;
                4'h8: sbox4 = 4'h3;
                4'h9: sbox4 = 4'hE;
                4'hA: sbox4 = 4'hF;
                4'hB: sbox4 = 4'h8;
                4'hC: sbox4 = 4'h4;
                4'hD: sbox4 = 4'h7;
                4'hE: sbox4 = 4'h1;
                4'hF: sbox4 = 4'h2;
            endcase
        end
    endfunction

    function [63:0] sbox_layer;
        input [63:0] x;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1)
                sbox_layer[4*i +: 4] = sbox4(x[4*i +: 4]);
        end
    endfunction

    function [63:0] p_layer;
        input [63:0] x;
        integer i;
        begin
            p_layer = 64'h0;
            for (i = 0; i < 63; i = i + 1)
                p_layer[(16*i) % 63] = x[i];
            p_layer[63] = x[63];
        end
    endfunction

    function [79:0] update_key;
        input [79:0] k;
        input [4:0]  round;
        reg   [79:0] r;
        begin
            // Rotate left by 61 bits
            r = {k[18:0], k[79:19]};
            // Apply S-box to the MS nibble
            r[79:76] = sbox4(r[79:76]);
            // XOR round counter into bits [19:15]
            r[19:15] = r[19:15] ^ round;
            update_key = r;
        end
    endfunction

    wire [63:0] round_state_next = p_layer(sbox_layer(state_reg ^ key_reg[79:16]));
    wire [79:0] round_key_next   = update_key(key_reg, round_ctr);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg  <= 64'h0;
            key_reg    <= 80'h0;
            round_ctr  <= 5'd0;
            ciphertext <= 64'h0;
            busy       <= 1'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                state_reg <= plaintext;
                key_reg   <= key;
                round_ctr <= 5'd1;
                busy      <= 1'b1;
            end else if (busy) begin
                if (round_ctr == 5'd31) begin
                    ciphertext <= round_state_next ^ round_key_next[79:16];
                    busy       <= 1'b0;
                    done       <= 1'b1;
                end else begin
                    state_reg <= round_state_next;
                    key_reg   <= round_key_next;
                    round_ctr <= round_ctr + 5'd1;
                end
            end
        end
    end
endmodule
