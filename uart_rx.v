`timescale 1ns/1ps

module uart_rx #(
    parameter integer CLK_FREQ = 50000000,
    parameter integer BAUD     = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg [7:0]  rx_data,
    output reg        rx_valid
);
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_START = 3'd1;
    localparam [2:0] S_DATA  = 3'd2;
    localparam [2:0] S_STOP  = 3'd3;
    localparam [2:0] S_DONE  = 3'd4;

    reg [2:0] state;
    reg [15:0] clk_cnt;
    reg [2:0] bit_idx;
    reg rx_meta, rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            rx_data  <= 8'h00;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_sync == 1'b0)
                        state <= S_START;
                end

                S_START: begin
                    if (clk_cnt == HALF_BIT[15:0]) begin
                        clk_cnt <= 16'd0;
                        if (rx_sync == 1'b0)
                            state <= S_DATA;
                        else
                            state <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 16'd0;
                        rx_data[bit_idx] <= rx_sync;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 16'd0;
                        state <= S_DONE;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_DONE: begin
                    rx_valid <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
