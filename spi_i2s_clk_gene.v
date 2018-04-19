//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : spi_i2s_clk_gene.v
// Author      : WangLei
// Created     : 2015.01.28
// Description : The clock generator of I2S module
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2015.02.08     WangLei      v1.0         Modified from sdio_ahb_if
//**********************************************************************

module spi_i2s_clk_gene(
					pclk, rst_n,scki,
					//module reg 
					i2se, bsy, chlen, mckoe, odd, i2sdiv,  
					i2sms, ckpol,
					// clock out
					i2s_clk_out, i2s_mck_out, i2s_clk_shft, i2s_clk_shft_inv,
					csn_wsi, rst_n_shft
					);
input			pclk, rst_n,scki;
input			mckoe, odd;
input			chlen; // being high means 32bit ,low means 16bit
input			i2se; // i2s enable, being high means i2s is enable
input			bsy;
input			i2sms;// select master or slave
input			ckpol;// clock steady state
input [13:0]	i2sdiv;
output			i2s_clk_out;
output          i2s_mck_out;
output          i2s_clk_shft;
output          i2s_clk_shft_inv;
input			csn_wsi;
output          rst_n_shft;

// reg and wire definition
reg [14:0]		clk_div_counter;
reg				clk_pre_div;// divider the pclk by i2sdiv and odd
reg				clk_div_chlen; // divider the clk_pre_div by 4 or 8 according to the channel length
reg [3:0]		clk_div_2nd_counter;
reg				i2s_mode; // to keep working in the ending stage when i2se is off
wire [14:0]		div_para;

assign	div_para = (i2sdiv << 1) + odd;
always@(posedge pclk or negedge rst_n)  // clk_div_counter & clk_pre_div
begin
	if (~rst_n)
		begin clk_div_counter <= 15'h0000; clk_pre_div <= 1'b0; end
	else
		if(i2s_mode)
			begin
				if(clk_div_counter < i2sdiv )
					begin clk_div_counter <= clk_div_counter + 1'b1; clk_pre_div <= 1'b0; end
				else if((clk_div_counter >= i2sdiv ) && (clk_div_counter < div_para))
					begin clk_div_counter <= clk_div_counter + 1'b1; clk_pre_div <= 1'b1; end
				else if(clk_div_counter == div_para)
					begin clk_div_counter <= 15'h0001; clk_pre_div <= 1'b0; end
			end
		else
			begin clk_div_counter <= 15'h0000; clk_pre_div <= ckpol; end
end

always@(posedge clk_pre_div or negedge rst_n)  // clk_div_chlen
begin
	if (~rst_n)
		begin clk_div_2nd_counter <= 4'h0; clk_div_chlen <= 1'b0; end
	else
		if(i2s_mode)
			if(chlen)
				begin 
					if(clk_div_2nd_counter < 1)
						begin clk_div_2nd_counter <= clk_div_2nd_counter + 1'b1; clk_div_chlen <= 1'b0; end
					else if((clk_div_2nd_counter >= 1) && (clk_div_2nd_counter < 3))
						begin clk_div_2nd_counter <= clk_div_2nd_counter + 1'b1; clk_div_chlen <= 1'b1; end
					else if(clk_div_2nd_counter == 3) 
						begin clk_div_2nd_counter <= 4'h0; clk_div_chlen <= 1'b0; end
				end
			else
				begin 
					if(clk_div_2nd_counter < 3)
						begin clk_div_2nd_counter <= clk_div_2nd_counter + 1'b1; clk_div_chlen <= 1'b0; end
					else if((clk_div_2nd_counter >= 3) && (clk_div_2nd_counter < 7))
						begin clk_div_2nd_counter <= clk_div_2nd_counter + 1'b1; clk_div_chlen <= 1'b1; end
					else if(clk_div_2nd_counter == 7) 
						begin clk_div_2nd_counter <= 4'h0; clk_div_chlen <= 1'b0; end
				end
		else
			begin clk_div_2nd_counter <= 4'h0; clk_div_chlen <= ckpol; end
end

always@(posedge pclk or negedge rst_n)  // i2s_mode
begin
	if (~rst_n)
		i2s_mode <= 1'b0;
	else if(i2se && bsy && i2sms)
		i2s_mode <= 1'b1;
	else if(!(i2se || bsy) )
		i2s_mode <= 1'b0;
	else 
		i2s_mode <= i2s_mode;
end

reg     csn_wsi_reg;
always@(posedge pclk or negedge rst_n)  // i2s_mode
begin
	if (~rst_n)
		csn_wsi_reg <= 1'b1;
	else 
		csn_wsi_reg <=  csn_wsi;
end

assign rst_n_shft = rst_n?(({csn_wsi_reg, csn_wsi} == 2'b11)?1'b0:1'b1):1'b0;

assign	i2s_clk_out = bsy?((mckoe)?clk_div_chlen:clk_pre_div):ckpol;
assign	i2s_clk_shft = i2sms?i2s_clk_out:scki; // for rx, tx should invert this clock
assign  i2s_clk_shft_inv = ~i2s_clk_shft;
assign	i2s_mck_out = bsy?clk_pre_div:ckpol;
endmodule 