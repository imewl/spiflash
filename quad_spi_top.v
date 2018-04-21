//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : quad_spi_top.v
// Author      : WangLei
// Created     : 2015.01.30
// Description : APB bus interface logic of SPI and I2S module, including the TX and RX FIFO
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2015.01.30     WangLei      v1.0         Initial version
// 2016.09.29     WangLei      v2.0        Added the SPI function
//**********************************************************************

module quad_spi_top (
            // For AHB slave
			hclk_i
           ,hresetn_i
           ,hsel_i
           ,haddr_i
           ,htrans_i
           ,hwrite_i
           ,hsize_i
           ,hburst_i
           //,hprot_i
           ,hwdata_i
           ,hrdata_o
           ,hready_o
           ,hresp_o
			// For APB bus
    		,pclk
			,rst_n
			,psel
			,penable
			,paddr
			,pwrite
			,pwdata 
			,prdata 
			,spi_i2s_int
			// for DMA
			,tx_fifo_space
			,rx_fifo_fill
			//out-side IO
			,spi_clk_o
			,spi_miso // bit[0] MOSI
			          // bit[1] MISO
			          // bit[2] can be used as nWP
			          // bit[3] can be used as nHOLD
			,spi_cs_n
			
        	);
//--------------------------------------------------------
//Input/Output define
//--------------------------------------------------------
// AHB BUS signal
input            hclk_i;
input			 hresetn_i;
input       	 hsel_i;
input   [31:0]	 haddr_i;
input   [1:0]	 htrans_i;
input			 hwrite_i;
input   [2:0]	 hsize_i;
input   [2:0]	 hburst_i;
//input   [3:0]	 hprot_i;
input   [31:0]	 hwdata_i;
output  [31:0]	 hrdata_o;
output			 hready_o;
output  [1:0]	 hresp_o;
// APB BUS signal
input         	pclk;       // APB's clock 
input         	rst_n;      // system reset
input         	psel;
input           penable;
input [31:0]   	paddr;
input         	pwrite;     // high for write, low for read
input [31:0]  	pwdata;
output[31:0]  	prdata;
output [3:0]	tx_fifo_space;
output [3:0]    rx_fifo_fill;

output			spi_i2s_int;

//--------------------------------------------------------
//Reg Wire define
//--------------------------------------------------------
/*
wire			pclk;
wire			rst_n;
wire			psel;
wire			penable;
wire [31:0]		paddr;
wire			pwrite;
wire [31:0]		pwdata;
wire			txeie, rxneie, errie, err_comm_ctrl;

wire            bidimode, spi_txrx, spe, mstr;
wire			i2se, i2scfg, i2sms, pcmsync, ckpol, chlen, bsy, chside;
wire [1:0]		i2sstd, datlen, txesel, rxesel;
wire			mckoe, odd;
wire [13:0]		i2sdiv;
wire			tx_fifo_acq, rx_fifo_wr;
wire [31:0]		tx_fifo_dat, rx_fifo_in;
wire			tx_shift_empty, i2s_rx_enable,  i2s_clk_shft, i2s_clk_shft_inv;

wire            ovr, udr, rx_shft_upload, i2s_mck_out;
wire            dr_wr;
wire [31:0]     rx_fifo_out, tx_sta_reg, tx_d_reg;
wire            csn_wsi_reg, tx_reg_hold, tx_reg_hold_reg, tx_reg_hold_rcv, tx_reg_hold_rcv_reg;
wire            d_reg_flag, d_reg_flag_reg, d_reg_spi_rd, d_reg_spi_rd_reg;
wire [3:0]      shft_state;
wire [7:0]      cmd_shft;
wire            tx_shft_first_load, tx_shft_load, rcv_cmd;
wire [31:0]     tx_fifo_data_in;
wire [5:0]      trans_cnt;
wire [3:0]  tx_fifo_fill_rd;
wire [3:0]  tx_fifo_fill;
wire [3:0]  rx_fifo_fill_wr;
	
wire        	tx_shift_empty_reg, chside_reg;	
*/
quad_spi_apb_if  u_apb_if(// For APB bus
    		/*.pclk(pclk), .rst_n(rst_n), .psel(psel), .penable(penable), 
			.paddr(paddr[7:0]), .pwrite(pwrite), .pwdata(pwdata), .prdata(prdata),
			// control reg
			.msb_lsb(msb_lsb), .spe(spe),  .mstr(mstr), 
			// interrupt reg
			//.txeie(txeie), .rxneie(rxneie), .errie(errie), .txesel(txesel), .rxesel(rxesel),
			// state reg
			.tx_fifo_fill(tx_fifo_fill), .rx_fifo_fill(rx_fifo_fill), .bsy(bsy), .tx_shift_empty(tx_shift_empty_reg),
			.ovr(ovr), .udr(udr), .chside(chside_reg), 
			// config reg
			.i2smod(i2smod), .i2se(i2se), .i2sms(i2sms), .i2scfg(i2scfg), .pcmsync(pcmsync), .i2sstd(i2sstd), 
			.ckpol(ckpol), .datlen(datlen), .chlen(chlen), 
			// predivider reg
			.mckoe(mckoe), .odd(odd), .i2sdiv(i2sdiv),
			// for tx fifo
			.dr_wr(dr_wr), .tx_fifo_data_in(tx_fifo_data_in), 
			// for rx fifo
			.dr_rd(dr_rd), .rx_fifo_out(rx_fifo_out),
			// for reg output
            .csn_wsi(csn_wsi_reg), .tx_reg_hold(tx_reg_hold), .tx_reg_hold_rcv(tx_reg_hold_rcv_reg),
			.d_reg_flag(d_reg_flag), .tx_d_reg(tx_d_reg), .d_reg_spi_rd(d_reg_spi_rd_reg),
			// for int & err
			.spi_i2s_int(spi_i2s_int), .err_comm_ctrl(err_comm_ctrl), .spi_out_int_i(spi_out_int_i), .spi_out_int_o(spi_out_int_o), .spi_out_int_oe(spi_out_int_oe)*/
			);
assign tx_fifo_space = 4'h8 - tx_fifo_fill;
// TX FIFO
/*
spi_i2s_txfifo_8x32 tx_fifo   (
	.rst_n(rst_n),
	.size_select(2'b0),
	// for write side
    .clk_wr(pclk),
	.write(dr_wr),
	.mem_fill_wr(tx_fifo_fill),
	.data_in(tx_fifo_data_in),
	// for read side
	.clk_rd(i2s_clk_shft_inv),
	.read(tx_fifo_acq),
	.data_out(tx_fifo_dat),
	.mem_fill_rd(tx_fifo_fill_rd)
    );

// RX FIFO
spi_i2s_rxfifo_8x32 rx_fifo   (
	.rst_n(rst_n),
	.size_select(2'b0),
	// for write side
    .clk_wr(i2s_clk_shft),
	.write(rx_fifo_wr),
	.mem_fill_wr(rx_fifo_fill_wr),
	.data_in({rx_fifo_in[30:0], sdi}),
	// for read side
	.clk_rd(pclk),
	.read(dr_rd),
	.data_out(rx_fifo_out),
	.mem_fill_rd(rx_fifo_fill)
    );			
	
spi_i2s_comm_ctrl u_comm_ctrl (
			.pclk(pclk), .rst_n(rst_n),
			.i2smod(i2smod), .i2se(i2se), .i2sms(i2sms),
			.i2sstd(i2sstd), .i2scfg(i2scfg), .datlen(datlen), .pcmsync(pcmsync), .chlen(chlen), 
			.mstr(mstr),
			.tx_fifo_fill(tx_fifo_fill), .tx_shift_empty(tx_shift_empty_reg), .bsy(bsy),
			.rx_shft_upload(rx_shft_upload), .i2s_rx_enable(i2s_rx_enable), .err_comm_ctrl(err_comm_ctrl),
			.sdoe(sdoe), .csn_ws_oe(csn_ws_oe), .sckoe(sckoe), .miso_oe(miso_oe), .mosi_oe(mosi_oe)
			);

spi_i2s_shft_ctrl	u_shft (.sdi(sdi),  .ckpol(ckpol), 
			// SPI config 
			//.bidimode(bidimode), .spi_txrx(spi_txrx), 
			.spe(spe), .mstr(mstr),  // static signal across clock domains, chould not be multi-sampled. 
			.tx_sta_reg(tx_sta_reg), 
			.mosi_s(mosi_s),
			// for spi reg output
			
			.i2smod(i2smod), .i2se(i2se), .i2sms(i2sms),// static signal across clock domains, chould not be multi-sampled. 
			.i2sstd(i2sstd), .i2scfg(i2scfg), .datlen(datlen), .pcmsync(pcmsync), .chlen(chlen), 
			.i2s_clk_shft(i2s_clk_shft), .rst_n(rst_n_shft),
			.tx_fifo_fill(tx_fifo_fill_rd),
			.tx_shift_empty(tx_shift_empty), .tx_fifo_acq(tx_fifo_acq),
			.rx_shft_upload(rx_shft_upload), .i2s_rx_enable(i2s_rx_enable),
			.rx_shft(rx_fifo_in), .chside(chside), .wso(csn_wso), .rx_fifo_wr(rx_fifo_wr),
			
			// for TX and RX shifter
			.shft_state(shft_state), .tx_shft_first_load(tx_shft_first_load), .tx_shft_load(tx_shft_load), .rcv_cmd(rcv_cmd), .cmd_shft(cmd_shft),
			.trans_cnt(trans_cnt)
			);
			
spi_i2s_tx     u_tx_shft (
			.rst_n(rst_n_shft), .i2s_clk_shft_tx(i2s_clk_shft_inv), 
			// from shifter controller
			.shft_state(shft_state), .tx_shft_first_load(tx_shft_first_load), .tx_shft_load(tx_shft_load), .rcv_cmd(rcv_cmd), .cmd_shft(cmd_shft), 
			.trans_cnt(trans_cnt), // from shifter controller, using i2s_clk_shft
			// With FIFO
			.tx_fifo_dat(tx_fifo_dat),  .tx_fifo_fill_rd(tx_fifo_fill_rd), .rx_fifo_fill_wr(rx_fifo_fill_wr),
			// With APB interface
			.tx_reg_hold(tx_reg_hold_reg), .tx_reg_hold_rcv(tx_reg_hold_rcv), .d_reg_flag(d_reg_flag_reg), .tx_d_reg(tx_d_reg),	.d_reg_spi_rd(d_reg_spi_rd),
			.msb_lsb(msb_lsb_reg),
			//output ports
			.sdo(sdo), .miso_s(miso_s)
			);
spi_i2s_clk_gene u_clk_gen (.pclk(pclk), .rst_n(rst_n), .scki(scki),
					//module reg 
				.i2se(i2se), .bsy(bsy), .chlen(chlen), .mckoe(mckoe), .odd(odd), .i2sdiv(i2sdiv),  
				.i2sms(i2sms), .ckpol(ckpol),
					// clock out
				.i2s_clk_out(scko), .i2s_mck_out(i2s_mck_out), 
				.i2s_clk_shft(i2s_clk_shft), .i2s_clk_shft_inv(i2s_clk_shft_inv), 
				.csn_wsi(csn_wsi), .rst_n_shft(rst_n_shft)
				);

assign	mck = pclk;

spi_sync_a2b u_sync_a2b_0 (
					 .rst_n(rst_n)
					,.clk_b(pclk)
					,.dat_a(csn_wsi)
					,.dat_b(csn_wsi_reg));
					
spi_sync_a2b u_sync_a2b_1 (
					 .rst_n(rst_n) 
					,.clk_b(i2s_clk_shft_inv) 
					,.dat_a(tx_reg_hold) 
					,.dat_b(tx_reg_hold_reg));
					
spi_sync_a2b u_sync_a2b_2 (
					 .rst_n(rst_n) 
					,.clk_b(pclk) 
					,.dat_a(tx_reg_hold_rcv) 
					,.dat_b(tx_reg_hold_rcv_reg));
					
spi_sync_a2b u_sync_a2b_3 (
					 .rst_n(rst_n) 
					,.clk_b(i2s_clk_shft_inv) 
					,.dat_a(d_reg_flag) 
					,.dat_b(d_reg_flag_reg));

spi_sync_a2b u_sync_a2b_4 (
					 .rst_n(rst_n) 
					,.clk_b(pclk) 
					,.dat_a(d_reg_spi_rd) 
					,.dat_b(d_reg_spi_rd_reg));	
					
spi_sync_a2b u_sync_a2b_5 (
					 .rst_n(rst_n) 
					,.clk_b(pclk) 
					,.dat_a(tx_shift_empty) 
					,.dat_b(tx_shift_empty_reg));	
					
spi_sync_a2b u_sync_a2b_6 (
					 .rst_n(rst_n) 
					,.clk_b(pclk) 
					,.dat_a(chside) 
					,.dat_b(chside_reg));		

spi_sync_a2b u_sync_a2b_7 (
					 .rst_n(rst_n) 
					,.clk_b(i2s_clk_shft_inv) 
					,.dat_a(msb_lsb) 
					,.dat_b(msb_lsb_reg));					
*/
endmodule
