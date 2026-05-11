//`include "sprite_buf_EX1.sv"
`include "sprite_buf_EX2.sv"

module top (
    /** Input Ports */
    input CLK,
    input SPI_SCK,
    input SPI_MOSI,
    input SPI_CS,

    /** Output Ports */
    output LCD_CLK,
    output LCD_DEN,
    output reg [4:0] LCD_R,
    output reg [5:0] LCD_G,
    output reg [4:0] LCD_B
);

wire [15:0] pixel;
wire [7:0] pixel_address;
reg we = 0;
reg [7:0] waddr = 0;
reg [15:0] wdata = 0;

/*dp_buffer dp_buffer_inst(
    .clk(CLK),
    .raddr(pixel_address),
    .rdata(pixel)
);*/

dp_buffer dp_buffer_inst(
    .clk(CLK),
    .we(we),
    .waddr(waddr),
    .wdata(wdata),
    .raddr(pixel_address),
    .rdata(pixel)
);


/** Logic */

//the parameters for the horizontal(x) and vertical(y) axis have been given
/*
    Parameter	            Horizontal	    Vertical
    Active region	        480 pixels	    272 lines
    Buffer Region	        45 clocks	    13 lines
    Total per line/frame	525 clocks	    285 lines
*/
parameter active_x = 480;
parameter totFrame_x = 526; //we have to consider 0 as well. 
parameter active_y = 272;
parameter totFrame_y = 286; //we have to consider 0 as well

reg [9:0] x_cnt = 0;
reg [9:0] y_cnt = 0;

assign LCD_CLK = CLK;

always @(posedge CLK) begin
    if(x_cnt < totFrame_x - 1) begin
        x_cnt <= x_cnt + 1;
    end else begin
        x_cnt <= 0;
        if(y_cnt < totFrame_y - 1) begin
            y_cnt <= y_cnt + 1;
        end else begin
            y_cnt <= 0;
        end
    end
end

//Display Enable (DE)
//only high during active. So, we have to make sur ethe axis cnt is less than the active region.
assign LCD_DEN = (x_cnt < active_x) && (y_cnt < active_y);

//Exercise 1 and 2

wire [3:0] mario_x;
wire [3:0] mario_y;

//to make the sprites appear on the horizontal axis of the LCD, i need to call the y_axis on mario_x
assign mario_x = y_cnt[3:0];  
assign mario_y = x_cnt[3:0];

assign pixel_address = (mario_y << 4) + mario_x;

//unlike lab 5, our rgb format will be different since we are doing only 16 bits.
//  REMEMBER: upper 5 bits -> red, middle 6 -> green, lower 5 -> blue
always @(*) begin
    if(LCD_DEN) begin
        LCD_R = pixel[15:11];
        LCD_G = pixel[10:5];
        LCD_B = pixel[4:0];
    end else begin
        LCD_R = 5'd0;
        LCD_G = 6'd0;
        LCD_B = 5'd0;
    end
end

//we need to receive the 16x16 values from controller pico
reg [15:0] shift_reg = 0;
reg [3:0] cnt = 0;

//called posedge spi_sck and spi_cs to fix cut-off and color issue
//the fix works. 
always @(posedge SPI_SCK or posedge SPI_CS) begin
    //since the CS is low in the pico when transferring the bits, we should only recieve when its low as well
    if(SPI_CS == 0) begin   
        //the incoming bits need to be shifted and we need to count them
        //similar to what i did in lab 4/5
        shift_reg <= {shift_reg[14:0], SPI_MOSI};

        //now, here is the code for once we recieve the bits
        if(cnt == 15) begin
            wdata <= {shift_reg[14:0], SPI_MOSI};
            we <= 1;    //according to the instructions. 
            cnt <= 0;
            waddr <= waddr + 1;
        end else begin
            we <= 0;
            cnt <= cnt +1;
        end
    end else begin
        cnt <= 0;
        we <= 0;
        waddr <= 0;
    end
end

endmodule