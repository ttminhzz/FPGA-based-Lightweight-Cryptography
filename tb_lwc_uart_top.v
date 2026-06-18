`timescale 1ns/1ps
module tb_lwc_uart_top;
    localparam integer CLK_FREQ = 50000000;
    localparam integer BAUD     = 1000000;  // faster simulation than hardware setting
    localparam integer BIT_NS   = 1000000000 / BAUD;

    reg clk;
    reg rst_n;
    reg uart_rx;
    wire uart_tx;
    wire [3:0] led;

    integer i;
    reg [7:0] received [0:20];
    reg [8*21-1:0] received_string;

    lwc_uart_top #(.CLK_FREQ(CLK_FREQ), .BAUD(BAUD)) dut (
        .clk(clk), .rst_n(rst_n), .uart_rx(uart_rx), .uart_tx(uart_tx), .led(led)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;  // 50 MHz

    task uart_send_byte;
        input [7:0] b;
        integer k;
        begin
            uart_rx = 1'b0; #(BIT_NS);       // start bit
            for (k = 0; k < 8; k = k + 1) begin
                uart_rx = b[k]; #(BIT_NS);
            end
            uart_rx = 1'b1; #(BIT_NS);       // stop bit
            #(BIT_NS);
        end
    endtask

    task uart_recv_byte;
        output [7:0] b;
        integer k;
        begin
            wait(uart_tx == 1'b0);
            #(BIT_NS + BIT_NS/2);
            for (k = 0; k < 8; k = k + 1) begin
                b[k] = uart_tx;
                #(BIT_NS);
            end
            #(BIT_NS/2); // stop bit margin
        end
    endtask

    initial begin
        rst_n = 1'b0;
        uart_rx = 1'b1;
        #200;
        rst_n = 1'b1;
        #200;

        // Command: 'E' + 8 zero plaintext bytes + 10 zero key bytes
        uart_send_byte("E");
        for (i = 0; i < 8; i = i + 1) uart_send_byte(8'h00);
        for (i = 0; i < 10; i = i + 1) uart_send_byte(8'h00);

        for (i = 0; i < 21; i = i + 1) begin
            uart_recv_byte(received[i]);
        end

        received_string = {received[0], received[1], received[2], received[3], received[4],
                           received[5], received[6], received[7], received[8], received[9],
                           received[10], received[11], received[12], received[13], received[14],
                           received[15], received[16], received[17], received[18], received[19],
                           received[20]};

        $display("UART response: %s", received_string);
        if (received_string !== "CT=5579C1387B228445\r\n") begin
            $display("FAIL: bad UART response");
            $stop;
        end else begin
            $display("PASS: UART top-level test matched.");
        end
        #1000;
        $finish;
    end
endmodule
