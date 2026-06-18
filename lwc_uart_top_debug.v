`timescale 1ns/1ps

module lwc_uart_top_debug #(
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
    reg [5:0]  nibble_count;
    reg [4:0]  tx_index;
    reg        done_sticky;
    reg        error_sticky;

    localparam [3:0] ST_BANNER   = 4'd0;
    localparam [3:0] ST_WAIT_CMD = 4'd1;
    localparam [3:0] ST_RX_HEX   = 4'd2;
    localparam [3:0] ST_START    = 4'd3;
    localparam [3:0] ST_WAIT_CT  = 4'd4;
    localparam [3:0] ST_TX_RESP  = 4'd5;
    localparam [3:0] ST_TX_ERR   = 4'd6;
    reg [3:0] state;

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

    function is_hex_char;
        input [7:0] ch;
        begin
            is_hex_char = ((ch >= "0") && (ch <= "9")) ||
                          ((ch >= "A") && (ch <= "F")) ||
                          ((ch >= "a") && (ch <= "f"));
        end
    endfunction

    function is_ignored_char;
        input [7:0] ch;
        begin
            is_ignored_char = (ch == 8'h20) || (ch == 8'h09) || (ch == 8'h0D) || (ch == 8'h0A);
        end
    endfunction

    function [3:0] hex_value;
        input [7:0] ch;
        begin
            if ((ch >= "0") && (ch <= "9"))
                hex_value = ch - "0";
            else if ((ch >= "A") && (ch <= "F"))
                hex_value = ch - "A" + 4'd10;
            else if ((ch >= "a") && (ch <= "f"))
                hex_value = ch - "a" + 4'd10;
            else
                hex_value = 4'h0;
        end
    endfunction

    function [7:0] hex_ascii;
        input [3:0] nib;
        begin
            hex_ascii = (nib < 4'd10) ? (8'h30 + nib) : (8'h41 + (nib - 4'd10));
        end
    endfunction

    function [7:0] banner_byte;
        input [4:0] idx;
        begin
            case (idx)
                5'd0: banner_byte = "R";
                5'd1: banner_byte = "E";
                5'd2: banner_byte = "A";
                5'd3: banner_byte = "D";
                5'd4: banner_byte = "Y";
                5'd5: banner_byte = 8'h0D;
                5'd6: banner_byte = 8'h0A;
                default: banner_byte = 8'h00;
            endcase
        end
    endfunction

    function [7:0] err_byte;
        input [4:0] idx;
        begin
            case (idx)
                5'd0: err_byte = "E";
                5'd1: err_byte = "R";
                5'd2: err_byte = "R";
                5'd3: err_byte = 8'h0D;
                5'd4: err_byte = 8'h0A;
                default: err_byte = 8'h00;
            endcase
        end
    endfunction

    function [7:0] response_byte;
        input [4:0] idx;
        input [63:0] ct;
        reg [3:0] nib;
        begin
            case (idx)
                5'd0:  response_byte = "C";
                5'd1:  response_byte = "T";
                5'd2:  response_byte = "=";
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
            state         <= ST_BANNER;
            plaintext_reg <= 64'h0;
            key_reg       <= 80'h0;
            nibble_count  <= 6'd0;
            tx_index      <= 5'd0;
            tx_data       <= 8'h00;
            tx_start      <= 1'b0;
            core_start    <= 1'b0;
            done_sticky   <= 1'b0;
            error_sticky  <= 1'b0;
        end else begin
            tx_start   <= 1'b0;
            core_start <= 1'b0;

            case (state)
                ST_BANNER: begin
                    if (tx_ready && !tx_start) begin
                        if (tx_index <= 5'd6) begin
                            tx_data  <= banner_byte(tx_index);
                            tx_start <= 1'b1;
                            tx_index <= tx_index + 5'd1;
                        end else begin
                            tx_index <= 5'd0;
                            state    <= ST_WAIT_CMD;
                        end
                    end
                end

                ST_WAIT_CMD: begin
                    nibble_count <= 6'd0;
                    if (rx_valid) begin
                        if ((rx_data == "T") || (rx_data == "t")) begin
                            plaintext_reg <= 64'h0;
                            key_reg       <= 80'h0;
                            done_sticky   <= 1'b0;
                            error_sticky  <= 1'b0;
                            state         <= ST_START;
                        end else if ((rx_data == "E") || (rx_data == "e")) begin
                            plaintext_reg <= 64'h0;
                            key_reg       <= 80'h0;
                            done_sticky   <= 1'b0;
                            error_sticky  <= 1'b0;
                            state         <= ST_RX_HEX;
                        end
                    end
                end

                ST_RX_HEX: begin
                    if (rx_valid) begin
                        if (is_ignored_char(rx_data)) begin
                            state <= ST_RX_HEX;
                        end else if (is_hex_char(rx_data)) begin
                            if (nibble_count < 6'd16) begin
                                plaintext_reg <= {plaintext_reg[59:0], hex_value(rx_data)};
                            end else begin
                                key_reg <= {key_reg[75:0], hex_value(rx_data)};
                            end

                            if (nibble_count == 6'd35) begin
                                nibble_count <= 6'd0;
                                state <= ST_START;
                            end else begin
                                nibble_count <= nibble_count + 6'd1;
                            end
                        end else begin
                            error_sticky <= 1'b1;
                            tx_index <= 5'd0;
                            state <= ST_TX_ERR;
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
                            tx_data  <= response_byte(tx_index, ciphertext);
                            tx_start <= 1'b1;
                            tx_index <= tx_index + 5'd1;
                        end else begin
                            tx_index <= 5'd0;
                            state <= ST_WAIT_CMD;
                        end
                    end
                end

                ST_TX_ERR: begin
                    if (tx_ready && !tx_start) begin
                        if (tx_index <= 5'd4) begin
                            tx_data  <= err_byte(tx_index);
                            tx_start <= 1'b1;
                            tx_index <= tx_index + 5'd1;
                        end else begin
                            tx_index <= 5'd0;
                            state <= ST_WAIT_CMD;
                        end
                    end
                end

                default: state <= ST_BANNER;
            endcase
        end
    end

    assign led[0] = core_busy;
    assign led[1] = done_sticky;
    assign led[2] = rx_valid;
    assign led[3] = error_sticky;
endmodule
