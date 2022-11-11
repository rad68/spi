`timescale 1ns / 1ps

module spi_conf
#(
    parameter   CONFIG_WIDTH = 32
)(
     input                          clock
    ,input                          reset
    
    ,input                          conf_0_valid
    ,output reg                     conf_0_ready
    ,input      [CONFIG_WIDTH-1:0]  conf_0_in
    ,output reg [CONFIG_WIDTH-1:0]  conf_0_out
    
    ,input                          conf_1_valid
    ,output reg                     conf_1_ready
    ,input      [CONFIG_WIDTH-1:0]  conf_1_in
    ,output reg [CONFIG_WIDTH-1:0]  conf_1_out
    
    ,input                          conf_2_valid
    ,output reg                     conf_2_ready
    ,input      [CONFIG_WIDTH-1:0]  conf_2_in
    ,output reg [CONFIG_WIDTH-1:0]  conf_2_out
    
    ,output reg                     soft_reset
);

always @(posedge clock)
if (reset)                              conf_0_ready <= 0;
else if (conf_0_valid & conf_0_ready)   conf_0_ready <= 0;
else if (conf_0_valid)                  conf_0_ready <= 1;
else                                    conf_0_ready <= conf_0_ready;

always @(posedge clock)
if (reset)                              conf_0_out <= {16'hFFFF, 6'h00, 2'b00, 1'b0, 1'b0, 2'b00, 2'b00, 2'b00};
else if (conf_0_valid & conf_0_ready)   conf_0_out <= {conf_0_in[31:11],1'b0,conf_0_in[9:0]};
else                                    conf_0_out <= conf_0_out;

always @(posedge clock)
if (reset)                              conf_1_ready <= 0;
else if (conf_1_valid & conf_1_ready)   conf_1_ready <= 0;
else if (conf_1_valid)                  conf_1_ready <= 1;
else                                    conf_1_ready <= conf_1_ready;

always @(posedge clock)
if (reset)                              conf_1_out <= {16'h0, 8'd0, 8'h0};
else if (conf_1_valid & conf_1_ready)   conf_1_out <= conf_1_in;
else                                    conf_1_out <= conf_1_out;

always @(posedge clock)
if (reset)                              conf_2_ready <= 0;
else if (conf_2_valid & conf_2_ready)   conf_2_ready <= 0;
else if (conf_2_valid)                  conf_2_ready <= 1;
else                                    conf_2_ready <= conf_2_ready;

always @(posedge clock)
if (reset)                              conf_2_out <= {16'd0, 16'd0};
else if (conf_2_valid & conf_2_ready)   conf_2_out <= conf_2_in;
else                                    conf_2_out <= conf_2_out;

reg [15:0] reset_cnt;
always @(posedge clock)
if (reset)                                              reset_cnt <= 0;
else if (reset_cnt != 0)                                reset_cnt <= reset_cnt + 1;
else if (conf_0_valid & conf_0_ready & conf_0_in[10])   reset_cnt <= 1;
else                                                    reset_cnt <= reset_cnt;

always @(posedge clock)
if (reset)                                              soft_reset <= 0;
else if (reset_cnt == 16'hFFFF)                         soft_reset <= 0;
else if (conf_0_valid & conf_0_ready & conf_0_in[10])   soft_reset <= 1;
else                                                    soft_reset <= soft_reset;

endmodule
