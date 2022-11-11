`timescale 1ns/1ps

/*
    Bits with no description are resserved

    Config0:
    [0] - CPHA - clock phase
    [1] - CPOL - clock polarity
    [3:2] - 0 - full duplex; 1 - simplex out; 2 - simplex in; 3 - half duplex
    [5:4] - Number of TX lines: 0 - 1 data line; 1 - 2 data lines; 2 - 4 data lines; 3 - 8 data lines (octal not supported))
                * only valid for half duplex configs
    [6] - reset master data value
    [7] - MSB first
    [9:8] - Number of RX lines: 0 - 1 data line; 1 - 2 data lines; 2 - 4 data lines; 3 - 8 data lines (octal not supported))
                *only valid for half duplex configs
    [10] - reset (Deadlock protection)
    [31:16] - Clock  divider. User must know external clock and compute clock period themselves.
              This ragister should be set to the half of an expected clock period
  
    Config1:
    [7:0] - one hot slave selection
    [15:8] - slave response delay in SPI clock cycles
    [23:16] - master request delay in SPI clock cycles
                    
    Config2: number of bytes in both directions after which communication should stop
    [15:0] - TX number
    [31:16] - RX number
    
    Absence of FIFOs in the synchronous part eliminates empty/full interrupts generation.
    In other words, communication on the DIN line means that TX is done (need some logic for the first char in the queue)

    No CRC check done at the moment.
    
    din_valid/din_ready handshake is used to to initiate communication in case of output byte number == 0
    
    NOTE:
        1. Config can be changed on the fly to switch between 1 line for command and 2-4-8 lines for data.
           Determinism is guaranteed by asynchronous communication which waits will handshake completion
           before mobing to the next statement.
        2. To run simplex_in or data_in while skipping data_out phase need to send a dummy din and initiate din_hs
        
    TODO:
        1. Test simplex modes
        2. Test soft reset
*/  

module spi_top
#(
     parameter SLAVE_NUM = 8
    ,parameter DATA_LINES = 4
    ,parameter CONFIG_WIDTH = 32
    ,parameter SPI_DATA_WIDTH = 8
    ,parameter SYNC_STAGE = 2
)
(
  //offchip ports
   input                            clock
  ,input                            reset
  
  ,output   [SLAVE_NUM      -1:0]   cs
  ,output                           spi_clk
  ,inout    [DATA_LINES     -1:0]   io
  //asynchronous interface
  ,input                            async_tx_d_req
  ,output                           async_tx_d_ack
  ,input    [SPI_DATA_WIDTH -1:0]   async_tx_d

  ,input                            async_rx_d_ack
  ,output                           async_rx_d_req
  ,output   [SPI_DATA_WIDTH -1:0]   async_rx_d
  
  ,input                            async_conf_0_req
  ,output                           async_conf_0_ack
  ,input    [CONFIG_WIDTH   -1:0]   async_conf_0
  
  ,input                            async_conf_1_req
  ,output                           async_conf_1_ack
  ,input    [CONFIG_WIDTH   -1:0]   async_conf_1
  
  ,input                            async_conf_2_req
  ,output                           async_conf_2_ack
  ,input    [CONFIG_WIDTH   -1:0]   async_conf_2
);

wire sync_tx_d_valid, sync_tx_d_ready;
wire sync_rx_d_valid, sync_rx_d_ready;
wire [SPI_DATA_WIDTH-1:0] sync_tx_d, sync_rx_d;

async_to_sync_ctrl #(
     .DATA_WIDTH    (SPI_DATA_WIDTH)
    ,.SYNC_STAGE    (SYNC_STAGE)
) async_to_sync_tx_d (
     .clock         (clock)
    ,.reset         (reset)
    ,.async_req     (async_tx_d_req)
    ,.async_ack     (async_tx_d_ack)
    ,.async_d       (async_tx_d)
    ,.sync_valid    (sync_tx_d_valid)
    ,.sync_ready    (sync_tx_d_ready)
    ,.sync_d        (sync_tx_d)
);

sync_to_async_ctrl #(
     .DATA_WIDTH    (SPI_DATA_WIDTH)
    ,.SYNC_STAGE    (SYNC_STAGE)
) sync_to_async_rx_d (
     .clock         (clock)
    ,.reset         (reset)
    ,.sync_valid    (sync_rx_d_valid)
    ,.sync_ready    (sync_rx_d_ready)
    ,.sync_d        (sync_rx_d)
    ,.async_req     (async_rx_d_req)
    ,.async_ack     (async_rx_d_ack)
    ,.async_d       (async_rx_d)
);

wire sync_conf_0_valid, sync_conf_1_valid, sync_conf_2_valid;
wire sync_conf_0_ready, sync_conf_1_ready, sync_conf_2_ready;
wire [CONFIG_WIDTH-1:0] sync_conf_0, sync_conf_1, sync_conf_2;

async_to_sync_ctrl #(
     .DATA_WIDTH    (CONFIG_WIDTH)
    ,.SYNC_STAGE    (SYNC_STAGE)
) async_to_sync_conf_0 (
     .clock         (clock)
    ,.reset         (reset)
    ,.async_req     (async_conf_0_req)
    ,.async_ack     (async_conf_0_ack)
    ,.async_d       (async_conf_0)
    ,.sync_valid    (sync_conf_0_valid)
    ,.sync_ready    (sync_conf_0_ready)
    ,.sync_d        (sync_conf_0)
);

async_to_sync_ctrl #(
     .DATA_WIDTH    (CONFIG_WIDTH)
    ,.SYNC_STAGE    (SYNC_STAGE)
) async_to_sync_conf_1 (
     .clock         (clock)
    ,.reset         (reset)
    ,.async_req     (async_conf_1_req)
    ,.async_ack     (async_conf_1_ack)
    ,.async_d       (async_conf_1)
    ,.sync_valid    (sync_conf_1_valid)
    ,.sync_ready    (sync_conf_1_ready)
    ,.sync_d        (sync_conf_1)
);

async_to_sync_ctrl #(
     .DATA_WIDTH    (CONFIG_WIDTH)
    ,.SYNC_STAGE    (SYNC_STAGE)
) async_to_sync_conf_2 (
     .clock         (clock)
    ,.reset         (reset)
    ,.async_req     (async_conf_2_req)
    ,.async_ack     (async_conf_2_ack)
    ,.async_d       (async_conf_2)
    ,.sync_valid    (sync_conf_2_valid)
    ,.sync_ready    (sync_conf_2_ready)
    ,.sync_d        (sync_conf_2)
);

wire    [CONFIG_WIDTH-1:0] conf_0, conf_1, conf_2;
wire    soft_reset;
spi_conf
#(
    .CONFIG_WIDTH   (CONFIG_WIDTH)
) spi_conf (
     .clock         (clock)
    ,.reset         (reset)
    
    ,.conf_0_valid  (sync_conf_0_valid)
    ,.conf_0_ready  (sync_conf_0_ready)
    ,.conf_0_in     (sync_conf_0)
    ,.conf_0_out    (conf_0)
    
    ,.conf_1_valid  (sync_conf_1_valid)
    ,.conf_1_ready  (sync_conf_1_ready)
    ,.conf_1_in     (sync_conf_1)
    ,.conf_1_out    (conf_1)
    
    ,.conf_2_valid  (sync_conf_2_valid)
    ,.conf_2_ready  (sync_conf_2_ready)
    ,.conf_2_in     (sync_conf_2)
    ,.conf_2_out    (conf_2)
    
    ,.soft_reset    (soft_reset)
);

spi
#(
     .DATA_LINES    (DATA_LINES)
    ,.CONFIG_WIDTH  (CONFIG_WIDTH)
    ,.DATA_WIDTH    (SPI_DATA_WIDTH)
    ,.SLAVE_NUM     (SLAVE_NUM)
) spi (
     .clock         (clock)
    ,.reset         (reset | soft_reset)

    ,.cs            (cs)
    ,.spi_clk       (spi_clk)
    ,.io            (io)

    ,.din_valid     (sync_tx_d_valid)
    ,.din_ready     (sync_tx_d_ready)
    ,.din           (sync_tx_d)

    ,.dout_valid    (sync_rx_d_valid)
    ,.dout_ready    (sync_rx_d_ready)
    ,.dout          (sync_rx_d)

    ,.conf_0        (conf_0)
    ,.conf_1        (conf_1)
    ,.conf_2        (conf_2)
);

endmodule
