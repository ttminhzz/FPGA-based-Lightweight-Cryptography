`timescale 1ns/1ps
module lwc_uart_top #(
    parameter integer CLK_FREQ = 50000000,
    parameter integer BAUD     = 115200
)(
    input  wire       clk,      
    input  wire       rst_n,    
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [3:0] led
);
    wire [7:0] rx_data;
    wire       rx_valid;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_ready;
    wire       tx_busy;

    reg        core_start;
    wire       core_busy;
    wire       core_done;
    wire       core_ready;
    wire [63:0] ciphertext;

    reg [63:0] plaintext_reg;
    reg [79:0] key_reg;
    reg [4:0]  byte_count;
    reg [4:0]  tx_index;
    reg        done_sticky;

    localparam [2:0] ST_WAIT_CMD = 3'd0;
    localparam [2:0] ST_RX_PT    = 3'd1;
    localparam [2:0] ST_RX_KEY   = 3'd2;
    localparam [2:0] ST_START    = 3'd3;
    localparam [2:0] ST_WAIT_CT  = 3'd4;
    localparam [2:0] ST_TX_RESP  = 3'd5;
    reg [2:0] state;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_uart_rx (
        .clk(clk), .rst_n(rst_n), .rx(uart_rx), .rx_data(rx_data), .rx_valid(rx_valid)
    );

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) u_uart_tx (
        .clk(clk), .rst_n(rst_n), .tx_data(tx_data), .tx_start(tx_start),
        .tx(uart_tx), .tx_ready(tx_ready), .tx_busy(tx_busy)
    );

    present80_encrypt u_present80 (
        .clk(clk), .rst_n(rst_n), .start(core_start),
        .plaintext(plaintext_reg), .key(key_reg), .ciphertext(ciphertext),
        .busy(core_busy), .done(core_done), .ready(core_ready)
    );

    function [7:0] hex_ascii;
        input [3:0] nib;
        begin
            hex_ascii = (nib < 4'd10) ? (8'h30 + nib) : (8'h41 + (nib - 4'd10));
        end
    endfunction

    function [7:0] response_byte;
        input [4:0] idx;
        input [63:0] ct;
        reg [3:0] nib;
        begin
            case (idx)
                5'd0: response_byte = "C";
                5'd1: response_byte = "T";
                5'd2: response_byte = "=";
                5'd19: response_byte = 8'h0D;
                5'd20: response_byte = 8'h0A;
                default: begin
                    nib = ct[63 - 4*(idx-5'd3) -: 4];
                    response_byte = hex_ascii(nib);
                end
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_WAIT_CMD;
            plaintext_reg <= 64'h0;
            key_reg       <= 80'h0;
            byte_count    <= 5'd0;
            tx_index      <= 5'd0;
            tx_data       <= 8'h00;
            tx_start      <= 1'b0;
            core_start    <= 1'b0;
            done_sticky   <= 1'b0;
        end else begin
            tx_start   <= 1'b0;
            core_start <= 1'b0;

            case (state)
                ST_WAIT_CMD: begin
                    byte_count <= 5'd0;
                    if (rx_valid && (rx_data == "E" || rx_data == "e")) begin
                        plaintext_reg <= 64'h0;
                        key_reg <= 80'h0;
                        done_sticky <= 1'b0;
                        state <= ST_RX_PT;
                    end
                end

                ST_RX_PT: begin
                    if (rx_valid) begin
                        plaintext_reg <= {plaintext_reg[55:0], rx_data};
                        if (byte_count == 5'd7) begin
                            byte_count <= 5'd0;
                            state <= ST_RX_KEY;
                        end else begin
                            byte_count <= byte_count + 5'd1;
                        end
                    end
                end

                ST_RX_KEY: begin
                    if (rx_valid) begin
                        key_reg <= {key_reg[71:0], rx_data};
                        if (byte_count == 5'd9) begin
                            byte_count <= 5'd0;
                            state <= ST_START;
                        end else begin
                            byte_count <= byte_count + 5'd1;
                        end
                    end
                end

                ST_START: begin
                    if (core_ready) begin
                        core_start <= 1'b1;
                        state <= ST_WAIT_CT;
                    end
                end

                ST_WAIT_CT: begin
                    if (core_done) begin
                        done_sticky <= 1'b1;
                        tx_index <= 5'd0;
                        state <= ST_TX_RESP;
                    end
                end

                ST_TX_RESP: begin
                    if (tx_ready && !tx_start) begin
                        if (tx_index <= 5'd20) begin
                            tx_data <= response_byte(tx_index, ciphertext);
                            tx_start <= 1'b1;
                            tx_index <= tx_index + 5'd1;
                        end else begin
                            state <= ST_WAIT_CMD;
                        end
                    end
                end

                default: state <= ST_WAIT_CMD;
            endcase
        end
    end


    assign led[0] = core_busy;
    assign led[1] = done_sticky;
    assign led[2] = rx_valid;
    assign led[3] = tx_busy;
endmodule
