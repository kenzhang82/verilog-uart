/*

Copyright (c) 2014-2017 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * AXI4-Stream UART
 */
module uart_tx #
(
    parameter DATA_WIDTH = 8
)
(
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,

    /*
     * UART interface
     */
    output wire                   txd,

    /*
     * Status
     */
    output wire                   busy,

    /*
     * Configuration
     */
    input  wire [15:0]            prescale
);

    localparam [2:0] IDLE      = 2'b00,
                     START_BIT = 2'b01,
                     DATA_BITS = 2'b10,
                     STOP_BIT  = 2'b11;

    reg [1:0] state = IDLE;
    reg s_axis_tready_reg = 0;
    reg [DATA_WIDTH-1:0] s_axis_tdata_reg = 0;
    reg txd_reg = 1;
    reg [15:0] prescale_reg = 0;
    reg [3:0] bit_cnt = 0;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            s_axis_tready_reg <= 0;
            s_axis_tdata_reg <= 0;
            txd_reg <= 1;
            prescale_reg <= 0;
            bit_cnt <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if(prescale_reg < 1) begin
                        prescale_reg <= prescale_reg + 1;
                        s_axis_tready_reg <= 1;
                    end
                    else begin
                        prescale_reg <= 0;
                        s_axis_tready_reg <= 0;
                        if (s_axis_tvalid) begin
                            s_axis_tready_reg <= 0;
                            s_axis_tdata_reg <= s_axis_tdata;
                            state <= START_BIT;
                        end
                        else begin
                            state <= IDLE;
                        end
                    end
                end
                START_BIT: begin
                    // account for one more cycle for state transition
                    if (prescale_reg < (prescale << 3) - 1) begin
                        prescale_reg <= prescale_reg + 1;
                        txd_reg <= 0;
                    end
                    else begin
                        prescale_reg <= 0;
                        state <= DATA_BITS;
                    end
                end
                DATA_BITS: begin
                    if (bit_cnt < DATA_WIDTH) begin
                        if (prescale_reg < (prescale << 3) - 1) begin
                            prescale_reg <= prescale_reg + 1;
                            txd_reg <= s_axis_tdata_reg[bit_cnt];
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1;
                            prescale_reg <= 0;
                        end
                    end
                    else begin
                        bit_cnt <= 0;
                        state <= STOP_BIT;
                    end
                end
                STOP_BIT: begin
                    // account for one more cycle for state transition
                    if (prescale_reg < (prescale << 3) - 1) begin
                        prescale_reg <= prescale_reg + 1;
                        txd_reg <= 1;
                    end
                    else begin
                        prescale_reg <= 0;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    assign s_axis_tready = s_axis_tready_reg;
    assign txd = txd_reg;
    assign busy = (state != IDLE);

endmodule