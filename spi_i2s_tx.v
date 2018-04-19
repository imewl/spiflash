//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : spi_i2s_tx.v
// Author      : WangLei
// Created     : 2016.10.04
// Description : I2S's shifter out 
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2016.10.04     WangLei      v1.0         Initial version
//**********************************************************************

module spi_i2s_tx (
					rst_n,
					i2s_clk_shft_tx,
					// from shift controller, using inv-clk
					shft_state,
					tx_shft_first_load, 
					tx_shft_load,
					rcv_cmd,
					cmd_shft,
					trans_cnt,
					
					// fro APB interface
					d_reg_flag,
					d_reg_spi_rd,
					tx_d_reg,
					tx_reg_hold, 
					tx_reg_hold_rcv,
					msb_lsb, 
					
					// from FIFO
					tx_fifo_dat,
					tx_fifo_fill_rd,
					rx_fifo_fill_wr,// using inv-clk
					
					// output ports
					sdo, miso_s
					
						);

// input and output definition
input			rst_n, i2s_clk_shft_tx;
input [3:0]     shft_state; 
input           tx_shft_first_load;
input           tx_shft_load;
input           rcv_cmd;
input [7:0]     cmd_shft;
input [5:0]     trans_cnt;


input           d_reg_flag;
output          d_reg_spi_rd;
input [31:0]    tx_d_reg;
input           tx_reg_hold;
output          tx_reg_hold_rcv;
input           msb_lsb;

input [31:0]	tx_fifo_dat;
input [3:0]     tx_fifo_fill_rd;
input [3:0]     rx_fifo_fill_wr;

output			sdo;
output          miso_s;
// reg and wire definition
reg             miso_s;
reg [31:0]      tx_d_reg_reg;
reg             tx_reg_hold_rcv;
reg [31:0]		tx_shft;
reg             d_reg_spi_rd;
reg             shft_end;

parameter		shft_idle = 4'h0, shft_i2s_st_mst = 4'h1, shft_i2s_wk_mst = 4'h2,
				shft_i2s_end_mst = 4'h3, shft_i2s_st_slv = 4'h4, shft_i2s_wk_slv = 4'h5,
				shft_spi_st_slv = 4'h6, shft_spi_stareg_rd_slv = 4'h7, shft_spi_fifo_rd_slv = 4'h8,
				shft_spi_dreg_rd_slv = 4'h9, shft_spi_fifo_wr_slv = 4'ha;
////////////////////////
//TX REG read function
////////////////////////
always@(posedge i2s_clk_shft_tx or negedge rst_n)
begin
	if (~rst_n) 
		begin tx_reg_hold_rcv <= 1'b0; tx_d_reg_reg <= 32'h0000_0000; end
	else if(tx_reg_hold)
		begin tx_reg_hold_rcv <= 1'b1; tx_d_reg_reg <= tx_d_reg; end
	else 
		begin tx_reg_hold_rcv <= 1'b0; tx_d_reg_reg <= tx_d_reg_reg; end
end

always@(posedge i2s_clk_shft_tx or negedge rst_n)
begin
	if (~rst_n)
		d_reg_spi_rd <= 1'b0;
	else if(rcv_cmd && (cmd_shft == 8'h98))
		d_reg_spi_rd <= 1'b1; 
	else if(!d_reg_flag)
		d_reg_spi_rd <= 1'b0;
	else
		d_reg_spi_rd <= d_reg_spi_rd;
end
				
// tx_shft
always@(posedge i2s_clk_shft_tx or negedge rst_n)
begin
	if (~rst_n)
		begin tx_shft <= 32'h0000_0000; end
	else if(tx_shft_first_load)
		begin tx_shft <= {tx_fifo_dat[30:0],1'b0};  end
	//else if(tx_shft_load)
	//	begin tx_shft <= tx_fifo_dat;  end
	else if(rcv_cmd && (cmd_shft == 8'h80))
		begin 
			if(msb_lsb)
				tx_shft <= {23'h000000, d_reg_flag, rx_fifo_fill_wr, tx_fifo_fill_rd}; 
			else
				tx_shft <= {rx_fifo_fill_wr, tx_fifo_fill_rd, 7'h00, d_reg_flag, 16'h0000}; 
		end
	else if(rcv_cmd && (cmd_shft == 8'h98))
		begin tx_shft <= tx_d_reg_reg; end
	else
		begin tx_shft <= (tx_shft << 1); end
end
always@(posedge i2s_clk_shft_tx or negedge rst_n)
begin
	if (~rst_n)
		shft_end <= 1'b0;
	else if((shft_state == shft_spi_fifo_rd_slv) && (trans_cnt == 6'h01))
		shft_end <= 1'b1;
	else
		shft_end <= 1'b0;
end
				
assign		sdo = ((shft_state == shft_i2s_wk_mst) || (shft_state == shft_i2s_end_mst) 
					|| (shft_state == shft_i2s_wk_slv) )?tx_shft[31]:tx_fifo_dat[31];

always@(*)
begin
	if(
		(rcv_cmd && (cmd_shft == 8'h90)) ||
		shft_end)
		miso_s = tx_fifo_dat[31];
	else 
		miso_s = tx_shft[31];
end	

endmodule
