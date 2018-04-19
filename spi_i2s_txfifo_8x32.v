//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : spi_i2s_txfifo_8x32.v
// Author      : Wang Lei
// Created     : 2015.01.30
// Description : A two-port FIFO for SPI_I2S module's RX/TX fifo 
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2015.01.30      Wang Lei    v1.0         initial version
// 2015.02.16      Wang Lei    v2.0         Using one clock
//**********************************************************************

module spi_i2s_txfifo_8x32    (
	rst_n,
	size_select,
	// for write side
	clk_wr,
    write,
	mem_fill_wr,
	data_in,
	// for read side
	clk_rd,
	read,
	data_out,
	mem_fill_rd
    );

input			rst_n; 
input			clk_wr;
input [1:0]			size_select;
input         write; 
output [3:0]  mem_fill_wr; 
input  [31:0] data_in; 
input         clk_rd;
input         read; 
output [31:0] data_out;   
output [3:0]  mem_fill_rd;
 
// Reg and Wire definition
reg [31:0] data_out;
reg [31:0] mem [7:0]; 

reg  [3:0] bny_wr; // write side binary code
reg  [3:0] gry_wr; // write side gray code
reg  [3:0] gry_rd_wrreg;
reg  [3:0] gry_rd_wrreg1;
reg  [3:0] bny_rd_wr;
wire [3:0] bny_wr_next;
wire [3:0] gry_wr_next;
      
reg  [3:0] bny_rd; // read side binary code
reg  [3:0] gry_rd; // read side gray code
reg  [3:0] gry_wr_rdreg;
reg  [3:0] gry_wr_rdreg1;
reg  [3:0] bny_wr_rd;
wire [3:0] bny_rd_next;
wire [3:0] gry_rd_next;

wire [2:0] bny_rd_mem;
wire [2:0] bny_wr_mem;

wire  do_read;
wire  do_write;
wire  has_data;
wire  has_space;

integer i;

always@(posedge clk_wr or negedge rst_n)
begin
	if(!rst_n)
		begin bny_wr <= 4'h0; gry_wr <= 4'h0; end 
	else
		begin
			bny_wr <= bny_wr_next;
			gry_wr <= gry_wr_next;
		end
end

assign bny_wr_next = do_write? (bny_wr + 1'b1): bny_wr; // next address of binary code
assign gry_wr_next = (bny_wr_next >> 1) ^ bny_wr_next;  // next address of Gray code

// double sample the read side pointer using write side clock
always@(posedge clk_wr or negedge rst_n)
begin
	if(!rst_n)
		begin gry_rd_wrreg <= 4'h0; gry_rd_wrreg1 <= 4'h0; end
	else
		begin
			gry_rd_wrreg <= gry_rd;
			gry_rd_wrreg1 <= gry_rd_wrreg;
		end
end

always @(*) // trans gry_rd_wrreg1 from Gray to binary
begin
    for(i = 0; i <= 3; i = i + 1)
      bny_rd_wr[i] = ^(gry_rd_wrreg1 >> i);
end

assign mem_fill_wr = (bny_wr >= bny_rd_wr)?(bny_wr - bny_rd_wr):({1'b1,bny_wr}-bny_rd_wr);
assign has_space = (mem_fill_wr == 4'h8)?1'b0:1'b1;
assign do_write  = write && has_space ; 

// write data into FIFO
assign bny_wr_mem = bny_wr[2:0];
always@(posedge clk_wr or negedge rst_n)
begin
	if(!rst_n)
		begin 
			mem[0] <= 32'h0000; mem[1] <= 32'h0000; mem[2] <= 32'h0000; mem[3] <= 32'h0000; 
			mem[4] <= 32'h0000; mem[5] <= 32'h0000; mem[6] <= 32'h0000; mem[7] <= 32'h0000; 
		end
	else if(do_write)
		mem[bny_wr_mem] <= data_in;
end

always@(posedge clk_rd or negedge rst_n)
begin
	if(!rst_n)
		begin bny_rd <= 4'h0; gry_rd <= 4'h0;end 
	else
		begin
			bny_rd <= bny_rd_next;
			gry_rd <= gry_rd_next;
		end
end

assign bny_rd_next = do_read? (bny_rd + 1'b1): bny_rd;
assign gry_rd_next = (bny_rd_next >> 1) ^ bny_rd_next;

// double sample the write side pointer using read side clock
always@(posedge clk_rd or negedge rst_n)
begin
	if(!rst_n)
		begin gry_wr_rdreg <= 4'h0; gry_wr_rdreg1 <= 4'h0; end
	else
		begin
			gry_wr_rdreg <= gry_wr;
			gry_wr_rdreg1 <= gry_wr_rdreg;
		end
end

always @(*) // trans gry_rd_wrreg1 from Gray to binary
begin
    for(i = 0; i <= 3; i = i + 1)
     // bny_wr_rd[i] = ^(gry_wr_rdreg1 >> i);
      bny_wr_rd[i] = ^(gry_wr_rdreg >> i);
end

assign mem_fill_rd = (bny_wr_rd >= bny_rd)?(bny_wr_rd - bny_rd):({1'b1,bny_wr_rd}-bny_rd);
assign has_data = (mem_fill_rd == 4'h0)?1'b0:1'b1;
assign do_read   = read & has_data;

assign	bny_rd_mem = bny_rd[2:0];
always@(*)
begin
	if(mem_fill_rd == 4'h0)
		data_out = 32'h0000_0000;
	else
		data_out = mem[bny_rd_mem];
end

endmodule
