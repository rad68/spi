`timescale 1ns / 1ps

module tb();

localparam FREQ = 100_000;
localparam DATA_LINES = 4;
localparam CONFIG_WIDTH = 32;
localparam DATA_WIDTH = 8;
localparam SLAVE_NUM = 8;

localparam CPHA = 1'b0;
localparam CPOL = 1'b0;
wire [1:0] pha_pol = {CPOL, CPHA};

wire [SLAVE_NUM-1:0]    cs;
wire                    spi_clk;
wire [DATA_LINES-1:0]   io;
reg                     din_valid;
reg                     din_ready_d;
wire                    din_ready;
reg [DATA_WIDTH -1:0]   din;
wire                    dout_valid;
reg                     dout_valid_d;
reg                     dout_ready;
wire [DATA_WIDTH -1:0]  dout;
reg                     conf_0_valid, conf_1_valid, conf_2_valid;
wire                    conf_0_ready, conf_1_ready, conf_2_ready;
reg [CONFIG_WIDTH-1:0]  conf_0, conf_1, conf_2;

reg [DATA_LINES-1:0] data;

reg clock;
initial clock = 0;
always clock = #10 ~clock;

task delay;
input   [15:0]  d;
begin
    repeat(d) @(posedge clock);
end
endtask

task set_conf;
input [CONFIG_WIDTH-1:0] c, sc, nc;
begin
    conf_0_valid = 1;
    conf_1_valid = 1;
    conf_2_valid = 1;
    conf_0 = c;
    conf_1 = sc;
    conf_2 = nc;
    while (!(conf_0_valid & conf_0_ready)) delay(1);
    delay(1);
    conf_0_valid = 0;
    conf_1_valid = 0;
    conf_2_valid = 0;
    delay(5);
end
endtask

task send_data;
input   [7:0]   i;
begin
    din_valid = 1;
    din_ready_d = 1;
    din = i;
    delay(1);
    while (!(din_valid & din_ready)) delay(1);
    delay(1);
    din_valid = 0;
    while (!(din_ready_d & !din_ready)) delay(1);
end
endtask

task recv_data;
begin
    dout_valid_d = 0;
    while (!(!dout_valid_d & dout_valid)) delay(1);
    dout_ready = 1;
    dout_valid_d = 1;
    delay(1);
    while (!(dout_valid & dout_ready)) delay(1);
    data = dout;
    while (!(dout_valid_d & !dout_valid)) delay(1);
    dout_ready = 0;
    delay(1);
end
endtask

reg reset;
task reset_task;
begin
    reset = 1;
    din_valid = 0;
    din = 0;
    dout_ready = 0;
    data = 0;
    conf_0_valid = 0;
    conf_1_valid = 0;
    conf_2_valid = 0;
    delay(10);
    reset = 1;
    delay(1000);
    reset = 0;
end
endtask

integer i;
initial begin
    reset_task();
    delay(100000);
    
    //Read status and config first
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();

    send_data(8'h35);
    recv_data();
    
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //Write status and config register
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd3});
    send_data(8'h01);
    send_data(8'h00);
    send_data(8'hC0);

    //Read status and config to check if they are updated
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    send_data(8'h35);
    recv_data();

    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Erase sector
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd5});
    send_data(8'h21);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    
    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //Read empty sector Some should be all Fs
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd40, 8'h1}, {16'd16, 16'd5});
    send_data(8'h13);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    for (i = 0; i < 16; i = i + 1) begin
        recv_data();
    end
    
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd1, 16'd1});
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Write Some
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd21});
    send_data(8'h12);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    for (i = 0; i < 16; i = i + 1) begin
        send_data($random);
    end
    
    //Check write status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Read what I wrote
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd40, 8'h1}, {16'd16, 16'd5});
    send_data(8'h13);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    for (i = 0; i < 16; i = i + 1) begin
        recv_data();
    end
    
    ///////////////////////////////////////
    //4 Quad Page Program and 4 Quad read//
    ///////////////////////////////////////
    
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Write status and config register
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd3});
    send_data(8'h01);
    send_data(8'h00);
    send_data(8'hC2);

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //Erase sector
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd5});
    send_data(8'h21);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
              
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //Write Some
    set_conf({16'h00FF, 6'h00, 2'b10, 1'b1, 1'b0, 2'b00, 2'b11, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd21});
    send_data(8'h34);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    set_conf({16'h00FF, 6'h00, 2'b10, 1'b1, 1'b0, 2'b10, 2'b11, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd21});
    for (i = 0; i < 16; i = i + 1) begin
        send_data($random);
    end

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Read Quad
    set_conf({16'h00FF, 6'h00, 2'b10, 1'b1, 1'b0, 2'b00, 2'b11, pha_pol}, {16'h0, 8'd40, 8'h1}, {16'd16, 16'd5});
    send_data(8'h6C);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    for (i = 0; i < 16; i = i + 1) begin
        recv_data();
    end
    
    //////////////////////////////////
    //4 Page Program and 4 Dual read//
    //////////////////////////////////
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Write status and config register
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd3});
    send_data(8'h01);
    send_data(8'h00);
    send_data(8'hC0);

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //Erase sector
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd5});
    send_data(8'h21);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Write Some
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd21});
    send_data(8'h12);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    for (i = 0; i < 16; i = i + 1) begin
        send_data($random);
    end

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //Read Dual
    set_conf({16'h00FF, 6'h00, 2'b01, 1'b1, 1'b0, 2'b00, 2'b11, pha_pol}, {16'h0, 8'd40, 8'h1}, {16'd16, 16'd5});
    send_data(8'h3C);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    for (i = 0; i < 16; i = i + 1) begin
        recv_data();
    end
    
    ///////////////////
    //4 Dual I/O read//
    ///////////////////
    //Read Dual I/O
    set_conf({16'h00FF, 6'h00, 2'b01, 1'b1, 1'b0, 2'b00, 2'b11, pha_pol}, {16'h0, 8'd28, 8'h1}, {16'd8, 16'd5});
    send_data(8'hBC);
    set_conf({16'h00FF, 6'h00, 2'b01, 1'b1, 1'b0, 2'b01, 2'b11, pha_pol}, {16'h0, 8'd28, 8'h1}, {16'd8, 16'd5});
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    for (i = 0; i < 8; i = i + 1) begin
        recv_data();
    end

    ///////////////////////////////////////
    //4 Quad Page Program and 4 Quad I/O Read//
    ///////////////////////////////////////
    
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Write status and config register
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd3});
    send_data(8'h01);
    send_data(8'h00);
    send_data(8'hC2);

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
    
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //Erase sector
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd5});
    send_data(8'h21);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end
              
    //Write Enable
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd1});
    send_data(8'h06);

    //Check write enable status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    while (!data[1]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //Write Some
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b11,pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd21});
    send_data(8'h34);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    set_conf({16'h00FF, 6'h00, 2'b10, 1'b1, 1'b0, 2'b10, 2'b11, pha_pol}, {16'h0, 8'd0, 8'h1}, {16'd0, 16'd21});
    for (i = 0; i < 16; i = i + 1) begin
        send_data($random);
    end

    //Check busy status
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b00, pha_pol}, {16'h0, 8'd8, 8'h1}, {16'd1, 16'd1});
    send_data(8'h05);
    recv_data();
    while (data[0]) begin
        send_data(8'h05);
        recv_data();
        delay(1000);
    end

    //////////////////////////////////////
    //4 Page Program and 4 Dual I/O read//
    //////////////////////////////////////
    //Read Dual I/O
    set_conf({16'h00FF, 6'h00, 2'b00, 1'b1, 1'b0, 2'b00, 2'b11, pha_pol}, {16'h0, 8'd19, 8'h1}, {16'd16, 16'd5});
    send_data(8'hEC);
    set_conf({16'h00FF, 6'h00, 2'b10, 1'b1, 1'b0, 2'b10, 2'b11, pha_pol}, {16'h0, 8'd19, 8'h1}, {16'd16, 16'd5});
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    send_data(8'h00);
    for (i = 0; i < 16; i = i + 1) begin
        recv_data();
    end

    $finish;
end

s25fl256s dut (
     .SI        (io[0])
    ,.SO        (io[1])
    ,.SCK       (spi_clk)
    ,.CSNeg     (cs[0])
    ,.RSTNeg    (~reset)
    ,.WPNeg     (io[2])
    ,.HOLDNeg   (io[3])
);

spi_top #(
   .DATA_LINES      (DATA_LINES )
  ,.CONFIG_WIDTH    (CONFIG_WIDTH)
  ,.SPI_DATA_WIDTH  (DATA_WIDTH)
  ,.SLAVE_NUM       (SLAVE_NUM)
) spi_top (
   .clock               (clock)
  ,.reset               (reset)

  ,.cs                  (cs)
  ,.spi_clk             (spi_clk)
  ,.io                  (io)

  ,.async_tx_d_req      (din_valid)
  ,.async_tx_d_ack      (din_ready)
  ,.async_tx_d          (din)

  ,.async_rx_d_ack      (dout_ready)
  ,.async_rx_d_req      (dout_valid)
  ,.async_rx_d          (dout)

  ,.async_conf_0_req    (conf_0_valid)
  ,.async_conf_0_ack    (conf_0_ready)
  ,.async_conf_0        (conf_0)

  ,.async_conf_1_req    (conf_2_valid)
  ,.async_conf_1_ack    (conf_1_ready)
  ,.async_conf_1        (conf_1)

  ,.async_conf_2_req    (conf_2_valid)
  ,.async_conf_2_ack    (conf_2_ready)
  ,.async_conf_2        (conf_2)
);

endmodule
