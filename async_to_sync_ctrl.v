`timescale 1ns/1ps

/*
    Randomly timed asynchronous protocol req/ack is converted
    into synchronously timed with clock ready/valid protocol
    
    Delay between req and ack determined by the number of synchronizer
    FFs + one FF on the output.
    
    clock   ''|,,|''|,,|''|,,|''|,,|''
    req     ,,,,|'''''''''''|,,,,,,,,,
    ack     ,,,,,,,,,,,|'''''''''''|,,
    valid   ,,,,,|'''''''''''|,,,,,,,,
    ready   ,,,,,,,,,,,|'''''|,,,,,,,,
*/

module async_to_sync_ctrl
#(
     parameter  DATA_WIDTH = 8
    ,parameter  SYNC_STAGE = 2
)(
     input  clock
    ,input  reset
    ,input                          async_req
    ,output reg                     async_ack
    ,input      [DATA_WIDTH-1:0]    async_d
    
    ,output reg                     sync_valid
    ,input                          sync_ready
    ,output reg [DATA_WIDTH-1:0]    sync_d
);

reg                     async_req_d [0:SYNC_STAGE-1];
reg [DATA_WIDTH-1:0]    async_d_d   [0:SYNC_STAGE-1];

integer i;
always @(posedge clock)
if (reset) begin
    for (i = 0; i < SYNC_STAGE; i = i + 1) begin
        async_req_d[i] <= 0;
        async_d_d[i] <= 0;
    end
end else begin
    for (i = 0; i < SYNC_STAGE; i = i + 1) begin
        if (i == 0) begin
            async_req_d[i] <= async_req;
            async_d_d[i] <= async_d;
        end else begin
            async_req_d[i] <= async_req_d[i-1];
            async_d_d[i] <= async_d_d[i-1];
        end
    end
end

reg async_req_dd;
always @(posedge clock)
if (reset) async_req_dd <= 0;
else
    if (SYNC_STAGE == 0)    async_req_dd <= async_req;
    else                    async_req_dd <= async_req_d[SYNC_STAGE-1];

wire async_req_posedge;
if (SYNC_STAGE == 0)
    assign async_req_posedge = ~async_req_dd & async_req;
else
    assign async_req_posedge = ~async_req_dd & async_req_d[SYNC_STAGE-1];

always @(posedge clock)
if (reset)                          async_ack <= 0;
else if (!async_req_dd)             async_ack <= 0;
else if (sync_valid & sync_ready)   async_ack <= 1;
else                                async_ack <= async_ack;

always @(posedge clock)
if (reset)  sync_d <= 0;
else
    if (SYNC_STAGE == 0)    sync_d <= async_d;
    else                    sync_d <= async_d_d[SYNC_STAGE-1];

always @(posedge clock)
if (reset)                          sync_valid <= 0;
else if (async_req_posedge)         sync_valid <= 1;
else if (sync_valid & sync_ready)   sync_valid <= 0;
else                                sync_valid <= sync_valid;

endmodule