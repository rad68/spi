`timescale 1ns/1ps

/*
    Precisely times syncrhonous protocol ready/valid converted
    into randomly timed asyncronous req/ack protocol
    
    clock   ''|,,|''|,,|''|,,|''|,,|''|,,|''|,,,
    req     ,,,,,,,,,,,|''''''''''''''|,,,,,,,,,
    ack     ,,,,,,,,,,,,,,,,,,|''''''''''''|,,,,
    valid   ,,,,,|''''''''''''''''''''|,,,,,,,,,
    ready   ,,,,,,,,,,,,,,,,,,,,,,,|''|,,,,,,,,,
*/

module sync_to_async_ctrl
#(
     parameter  DATA_WIDTH = 8
    ,parameter  SYNC_STAGE = 2
)(
     input                          clock
    ,input                          reset
    ,input                          sync_valid
    ,output reg                     sync_ready
    ,input      [DATA_WIDTH-1:0]    sync_d
    
    ,output reg                     async_req
    ,input                          async_ack
    ,output reg [DATA_WIDTH-1:0]    async_d
);

reg async_ack_d[0:SYNC_STAGE-1];

integer i;
always @(posedge clock)
if (reset) begin
    for (i = 0; i < SYNC_STAGE; i = i + 1) begin
        async_ack_d[i] <= 0;
    end
end else begin
    for (i = 0; i < SYNC_STAGE; i = i + 1) begin
        if (i == 0) begin
            async_ack_d[i] <= async_ack;
        end else begin
            async_ack_d[i] <= async_ack_d[i-1];
        end
    end
end

reg async_ack_dd;
always @(posedge clock)
if (reset)  async_ack_dd <= 0;
else
    if (SYNC_STAGE == 0)    async_ack_dd <= async_ack;
    else                    async_ack_dd <= async_ack_d[SYNC_STAGE-1];
    
wire async_ack_posedge;
if (SYNC_STAGE == 0)
    assign async_ack_posedge = ~async_ack_dd & async_ack;
else
    assign async_ack_posedge = ~async_ack_dd & async_ack_d[SYNC_STAGE-1];
    
always @(posedge clock)
if (reset)                          async_req <= 0;
else if (sync_valid & sync_ready)   async_req <= 0;
else if (sync_valid)                async_req <= 1;
else                                async_req <= async_req;

always @(posedge clock)
if (reset)  async_d <= 0;
else        async_d <= sync_d;

always @(posedge clock)
if (reset)                                  sync_ready <= 0;
else if (sync_valid & sync_ready)           sync_ready <= 0;
else if (async_ack_posedge & sync_valid)    sync_ready <= 1;
else                                        sync_ready <= sync_ready;

endmodule