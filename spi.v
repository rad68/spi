`timescale 1ns/1ps

module spi #(
   parameter DATA_LINES = 4
  ,parameter CONFIG_WIDTH = 32
  ,parameter DATA_WIDTH = 8
  ,parameter SLAVE_NUM = 8
)(
  //offchip ports
   input    clock
  ,input    reset
  
  ,output   reg [SLAVE_NUM-1:0]     cs
  ,output   reg                     spi_clk
  ,inout        [DATA_LINES-1:0]    io

  ,input                            din_valid
  ,output   reg                     din_ready
  ,input        [DATA_WIDTH -1:0]   din

  ,output   reg                     dout_valid
  ,input                            dout_ready
  ,output   reg [DATA_WIDTH -1:0]   dout

  ,input        [CONFIG_WIDTH-1:0]  conf_0
  ,input        [CONFIG_WIDTH-1:0]  conf_1
  ,input        [CONFIG_WIDTH-1:0]  conf_2
);

wire FULL_DUPLEX, SIMPLEX_IN, SIMPLEX_OUT, HALF_DUPLEX;
wire TX_SINGLE, TX_DUAL, TX_QUAD, TX_OCTAL;
wire RX_SINGLE, RX_DUAL, RX_QUAD, RX_OCTAL;

reg [CONFIG_WIDTH-1:0] conf_0_d, conf_1_d, conf_2_d;

reg [DATA_LINES-1:0] io_ctrl;   //1 - input, 0 output
reg [DATA_LINES-1:0] line_enable;

reg [DATA_WIDTH-1:0] din_buf;

reg [15:0]  resp_delay;
wire resp_delay_done;
assign resp_delay_done = resp_delay == conf_1_d[15:8];

reg [15:0] req_delay;
wire req_delay_done;
assign req_delay_done = req_delay == conf_1_d[23:16];

reg [15:0]  clk_div;
wire half_clk;
reg wait_half;
assign half_clk = clk_div == conf_0_d[31:16];

reg [15:0]  rx_byte_cnt;
reg [15:0]  tx_byte_cnt;

reg [2:0]   bit_inc;
reg         bit_half;
reg [2:0]   tx_bit_cnt, rx_bit_cnt;
wire        bit_shift, bit_sample;
wire        rx_bit_shift, rx_bit_sample;
wire        tx_bit_shift, tx_bit_sample;
wire        tx_bit_last, rx_bit_last;
wire        tx_byte, rx_byte;
assign tx_bit_last = ((tx_bit_cnt == 0 & conf_0_d[5:4] == 3) | 
                      (tx_bit_cnt == 4 & conf_0_d[5:4] == 2) | 
                      (tx_bit_cnt == 6 & conf_0_d[5:4] == 1) | 
                      (tx_bit_cnt == 7 & conf_0_d[5:4] == 0));
                                    
assign rx_bit_last = ((rx_bit_cnt == 0 & conf_0_d[9:8] == 3) | 
                      (rx_bit_cnt == 4 & conf_0_d[9:8] == 2) | 
                      (rx_bit_cnt == 6 & conf_0_d[9:8] == 1) | 
                      (rx_bit_cnt == 7 & conf_0_d[9:8] == 0));

assign tx_byte = tx_bit_last & bit_half & half_clk;
assign rx_byte = rx_bit_last & bit_half & half_clk;

wire tx_done, rx_done;
assign tx_done = tx_byte_cnt == conf_2_d[15:0];
assign rx_done = rx_byte_cnt == conf_2_d[31:16]; 

wire din_hs, dout_hs;
assign din_hs = din_valid & din_ready;
assign dout_hs = dout_valid & dout_ready;

reg rx_first;
reg skip_edge;

/*
    Main state machine
*/
reg [2:0] state;
wire [2:0] next_state;

localparam  IDLE        =   0,  //disable, i.e. cs high
            DATA_IN     =   1,  //receiving data in a half duplex/simplex in mode
            DATA_OUT    =   2,  //sending data in a half dumplex/simplex out mode
            DATA        =   3,  //full duplex communication
            WAIT        =   4;  //wait for data to be send/received to/from CPU. 
                                //Use to stop spi_clock while keeping cs low 

wire IDLE_state, DATA_IN_state, DATA_OUT_state, DATA_state, WAIT_state;
assign IDLE_state       = ~state[2] & ~state[1] & ~state[0];
assign DATA_IN_state    = ~state[2] & ~state[1] &  state[0];
assign DATA_OUT_state   = ~state[2] &  state[1] & ~state[0];
assign DATA_state       = ~state[2] &  state[1] &  state[0];
assign WAIT_state       =  state[2] & ~state[1] & ~state[0];

wire IDLE_next_state, DATA_IN_next_state, DATA_OUT_next_state, DATA_next_state, WAIT_next_state;
assign IDLE_next_state       = ~next_state[2] & ~next_state[1] & ~next_state[0];
assign DATA_IN_next_state    = ~next_state[2] & ~next_state[1] &  next_state[0];
assign DATA_OUT_next_state   = ~next_state[2] &  next_state[1] & ~next_state[0];
assign DATA_next_state       = ~next_state[2] &  next_state[1] &  next_state[0];
assign WAIT_next_state       =  next_state[2] & ~next_state[1] & ~next_state[0];

wire IDLE_DATA_OUT, IDLE_DATA_IN, IDLE_DATA, WAIT_DATA_OUT, WAIT_DATA_IN, WAIT_DATA, WAIT_IDLE, DATA_WAIT, DATA_OUT_WAIT, DATA_IN_WAIT;
assign IDLE_DATA_OUT    = IDLE_state & (SIMPLEX_OUT | HALF_DUPLEX) & din_hs;
assign IDLE_DATA_IN     = IDLE_state & SIMPLEX_IN & din_hs;
assign IDLE_DATA        = IDLE_state & FULL_DUPLEX & din_hs;

assign WAIT_DATA_OUT    = WAIT_state & (SIMPLEX_OUT | HALF_DUPLEX) & din_hs & !tx_done;
assign WAIT_DATA_IN     = WAIT_state & (SIMPLEX_IN  | HALF_DUPLEX) & !rx_done & (dout_hs | !rx_first & tx_done);
assign WAIT_DATA        = WAIT_state & (FULL_DUPLEX) & (din_hs & !tx_done | dout_hs & !rx_done | !rx_first & !rx_done);
assign WAIT_IDLE        = WAIT_state & rx_done & tx_done;

assign DATA_WAIT        = DATA_state & (rx_byte | tx_byte);
assign DATA_OUT_WAIT    = DATA_OUT_state & tx_byte;
assign DATA_IN_WAIT     = DATA_IN_state & rx_byte;

assign next_state = IDLE_DATA_OUT ? DATA_OUT:
                    IDLE_DATA_IN  ? DATA_IN :
                    IDLE_DATA     ? DATA    :

                    WAIT_IDLE     ? IDLE    :
                    WAIT_DATA_OUT ? DATA_OUT:
                    WAIT_DATA_IN  ? DATA_IN :
                    WAIT_DATA     ? DATA    :

                    DATA_WAIT     ? WAIT    :
                    DATA_OUT_WAIT ? WAIT    : 
                    DATA_IN_WAIT  ? WAIT    :   state;

always @(posedge clock)
if (reset)  state <= IDLE;
else        state <= next_state;

always @(posedge clock)
if (reset)                  cs <= {SLAVE_NUM{1'b1}};
else if (din_hs)            cs <= ~conf_1_d[7:0];
else if (tx_done & rx_done) cs <= {SLAVE_NUM{1'b1}}; 
else                        cs <= cs;

always @(posedge clock)
if (reset)                      clk_div <= 0;
else if (IDLE_state | half_clk) clk_div <= 0;
else if (WAIT_state)            clk_div <= clk_div;
else                            clk_div <= clk_div + 1;

always @(posedge clock)
if (reset)              spi_clk <= conf_0_d[1];
else if (IDLE_state)    spi_clk <= conf_0_d[1]; //Need this for the case when config is changed after reset
else if (WAIT_state)    spi_clk <=  spi_clk;
else if (half_clk)      spi_clk <= ~spi_clk;
else                    spi_clk <=  spi_clk; 

always @(posedge clock)
if (reset)                          skip_edge <= 0;
else if (IDLE_state)                skip_edge <= conf_0_d[0];
else if (!IDLE_state & half_clk)    skip_edge <= 0;
else                                skip_edge <= skip_edge;

wire conf_00, conf_01, conf_10, conf_11;
assign conf_00 = ~conf_0_d[1] & ~conf_0_d[0];   //idle: low; sample: raising; shift: falling 
assign conf_01 = ~conf_0_d[1] &  conf_0_d[0];   //idle: low; sample: falling; shift: rising
assign conf_10 =  conf_0_d[1] & ~conf_0_d[0];   //idle: high; sample: falling; shift: rising
assign conf_11 =  conf_0_d[1] &  conf_0_d[0];   //idle: high; sample: rising; shift: falling

always @(posedge clock)
if (reset)                      bit_half <= 0;//conf_0_d[1] & conf_0_d[0];
else if (half_clk & !skip_edge) bit_half <= ~bit_half;
else                            bit_half <=  bit_half;

always @(posedge clock)
if (reset)                                      rx_first <= 0;
else if (tx_done & DATA_state | DATA_IN_state)  rx_first <= 1;
else if (IDLE_state)                            rx_first <= 0;
else                                            rx_first <= rx_first;

assign bit_shift  =  bit_half & half_clk & ~skip_edge;
assign bit_sample = ~bit_half & half_clk & ~skip_edge;

assign rx_bit_shift  = bit_shift  & (DATA_state | DATA_IN_state);
assign rx_bit_sample = bit_sample & (DATA_state | DATA_IN_state);

assign tx_bit_shift  = bit_shift  & (DATA_state | DATA_OUT_state);
assign tx_bit_sample = bit_sample & (DATA_state | DATA_OUT_state);

always @(posedge clock)
if (reset)                          tx_bit_cnt <= 0;
else if (!req_delay_done)           tx_bit_cnt <= 0;
else if (tx_bit_shift & !tx_done)   tx_bit_cnt <= tx_bit_cnt + bit_inc;
else                                tx_bit_cnt <= tx_bit_cnt;

always @(posedge clock)
if (reset)                          rx_bit_cnt <= 0;
else if (!resp_delay_done)          rx_bit_cnt <= 0;
else if (rx_bit_shift & !rx_done)   rx_bit_cnt <= rx_bit_cnt + bit_inc;
else                                rx_bit_cnt <= rx_bit_cnt;

always @(posedge clock)
if (reset)                      tx_byte_cnt <= 0;
else if (rx_done & tx_done)     tx_byte_cnt <= 0;
else if (tx_byte & !tx_done)    tx_byte_cnt <= tx_byte_cnt + 1;
else                            tx_byte_cnt <= tx_byte_cnt;

always @(posedge clock)
if (reset)                      rx_byte_cnt <= 0;
else if (rx_done & tx_done)     rx_byte_cnt <= 0;
else if (rx_byte & !rx_done)    rx_byte_cnt <= rx_byte_cnt + 1;
else                            rx_byte_cnt <= rx_byte_cnt;      

always @(posedge clock)
if (reset)                                                  din_buf <= {8{conf_0_d[6]}};
else if (!req_delay_done)                                   din_buf <= {8{conf_0_d[6]}};
else if (tx_bit_shift)                                      din_buf <= din_buf >> bit_inc;
else if (din_hs & !conf_0_d[7])                             din_buf <= {din[7],din[6],din[5],din[4],din[3],din[2],din[1],din[0]};
else if (din_hs & (conf_0_d[7] & 
                  (SIMPLEX_OUT | FULL_DUPLEX | 
                  (HALF_DUPLEX & TX_SINGLE))))              din_buf <= {din[0],din[1],din[2],din[3],din[4],din[5],din[6],din[7]};

else if (din_hs &  conf_0_d[7] & (HALF_DUPLEX & TX_DUAL))   din_buf <= {din[1],din[0],din[3],din[2],din[5],din[4],din[7],din[6]};
else if (din_hs &  conf_0_d[7] & (HALF_DUPLEX & TX_QUAD))   din_buf <= {din[3],din[2],din[1],din[0],din[7],din[6],din[5],din[4]};

else if (din_hs & !conf_0_d[7] & (HALF_DUPLEX & TX_DUAL))   din_buf <= {din[5],din[7],din[4],din[5],din[2],din[3],din[0],din[1]};
else if (din_hs & !conf_0_d[7] & (HALF_DUPLEX & TX_QUAD))   din_buf <= {din[4],din[5],din[6],din[7],din[0],din[1],din[2],din[3]};
else                                                        din_buf <= din_buf;

always @(posedge clock)
if (reset)                                      din_ready <= 1;
else if (din_hs)                                din_ready <= 0;
else if (IDLE_state | (WAIT_state & !tx_done))  din_ready <= 1;
else                                            din_ready <= din_ready;

always @(posedge clock)
if (reset)                                              dout <= 0;
else if (dout_hs)                                       dout <= 0;
else if (!FULL_DUPLEX & rx_bit_sample & ~conf_0_d[7])   dout <= (dout >> bit_inc) | (io & line_enable);
else if (!FULL_DUPLEX & rx_bit_sample &  conf_0_d[7])   dout <= (dout << bit_inc) | (io & line_enable);
else if ( FULL_DUPLEX & rx_bit_sample & ~conf_0_d[7])   dout <= (dout >> 1) | {io[1], 7'b0};
else if ( FULL_DUPLEX & rx_bit_sample &  conf_0_d[7])   dout <= (dout << 1) | io[1];
else                                                    dout <= dout;

always @(posedge clock)
if (reset)          dout_valid <= 0;
else if (dout_hs)   dout_valid <= 0;
else if (rx_byte)   dout_valid <= 1;
else                dout_valid <= dout_valid; 

always @(posedge clock)
if (reset)                              resp_delay <= 0;
else if (IDLE_state)                    resp_delay <= 0;
else if (bit_shift & !resp_delay_done)  resp_delay <= resp_delay + 1;
else if (bit_shift & !resp_delay_done)  resp_delay <= resp_delay + 1;
else                                    resp_delay <= resp_delay;

always @(posedge clock)
if (reset)                              req_delay <= 0;
else if (IDLE_state)                    req_delay <= 0;
else if (bit_shift & !req_delay_done)   req_delay <= req_delay + 1;
else if (bit_shift & !req_delay_done)   req_delay <= req_delay + 1;
else                                    req_delay <= req_delay;

/*
    Configuration registers
*/
always @(posedge clock)
if (reset | IDLE_state)                     bit_inc <= 1;
else if (DATA_OUT_next_state & TX_SINGLE)   bit_inc <= 1;
else if (DATA_OUT_next_state & TX_DUAL)     bit_inc <= 2;
else if (DATA_OUT_next_state & TX_QUAD)     bit_inc <= 4;
else if (DATA_IN_next_state & RX_SINGLE)    bit_inc <= 1;
else if (DATA_IN_next_state & RX_DUAL)      bit_inc <= 2;
else if (DATA_IN_next_state & RX_QUAD)      bit_inc <= 4;
else                                        bit_inc <= bit_inc;

always @(posedge clock)
if (reset) line_enable <= 0;
else if (FULL_DUPLEX)                                   line_enable <= 4'h3;    //[0] - output; [1] - input
else if ((SIMPLEX_IN | SIMPLEX_OUT))                    line_enable <= 4'h1;
else if (HALF_DUPLEX & DATA_OUT_next_state & TX_SINGLE) line_enable <= 4'h1;
else if (HALF_DUPLEX & DATA_OUT_next_state & TX_DUAL  ) line_enable <= 4'h3;
else if (HALF_DUPLEX & DATA_OUT_next_state & TX_QUAD  ) line_enable <= 4'hF;
else if (HALF_DUPLEX & DATA_IN_next_state & RX_SINGLE)  line_enable <= 4'h1;
else if (HALF_DUPLEX & DATA_IN_next_state & RX_DUAL  )  line_enable <= 4'h3;
else if (HALF_DUPLEX & DATA_IN_next_state & RX_QUAD  )  line_enable <= 4'hF;
else                                                    line_enable <= line_enable;

always @(posedge clock)
if (reset) begin
    conf_0_d <= conf_0;
    conf_1_d <= conf_1;
    conf_2_d <= conf_2;
end else if (IDLE_state | WAIT_state) begin
    conf_0_d <= conf_0;
    conf_1_d <= conf_1;
    conf_2_d <= conf_2;
end else begin
    conf_0_d <= conf_0_d;
    conf_1_d <= conf_1_d;
    conf_2_d <= conf_2_d;
end

always @(posedge clock)
if (reset)                                                  io_ctrl <= {DATA_LINES{1'b0}};
else if (DATA_next_state)                                   io_ctrl <= 4'b1110;
else if (DATA_IN_next_state)                                io_ctrl <= 4'b1111;
else if (DATA_OUT_next_state & (SIMPLEX_OUT))               io_ctrl <= 4'b1110;
else if (DATA_OUT_next_state & (HALF_DUPLEX & TX_SINGLE))   io_ctrl <= 4'b1110;
else if (DATA_OUT_next_state & (HALF_DUPLEX & TX_DUAL))     io_ctrl <= 4'b1100;
else if (DATA_OUT_next_state & (HALF_DUPLEX & TX_QUAD))     io_ctrl <= 4'b0000;
else                                                        io_ctrl <= io_ctrl;

assign io[0] = io_ctrl[0] ? 1'bz : din_buf[0] & line_enable[0];
assign io[1] = io_ctrl[1] ? 1'bz : din_buf[1] & line_enable[1];
assign io[2] = io_ctrl[2] ? 1'bz : din_buf[2] & line_enable[2];
assign io[3] = io_ctrl[3] ? 1'bz : din_buf[3] & line_enable[3];

/*
    Static Assignments
*/
assign FULL_DUPLEX = ~conf_0_d[3] & ~conf_0_d[2];
assign SIMPLEX_IN  = ~conf_0_d[3] &  conf_0_d[2];
assign SIMPLEX_OUT =  conf_0_d[3] & ~conf_0_d[2];
assign HALF_DUPLEX =  conf_0_d[3] &  conf_0_d[2];

assign TX_SINGLE = ~conf_0_d[5] & ~conf_0_d[4];
assign TX_DUAL   = ~conf_0_d[5] &  conf_0_d[4];
assign TX_QUAD   =  conf_0_d[5] & ~conf_0_d[4];
assign TX_OCTAL  =  conf_0_d[5] &  conf_0_d[4];

assign RX_SINGLE = ~conf_0_d[9] & ~conf_0_d[8];
assign RX_DUAL   = ~conf_0_d[9] &  conf_0_d[8];
assign RX_QUAD   =  conf_0_d[9] & ~conf_0_d[8];
assign RX_OCTAL  =  conf_0_d[9] &  conf_0_d[8];

endmodule
