//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : spi_i2s_apb_if.v
// Author      : WangLei
// Created     : 2015.01.28
// Description : APB bus interface logic of SPI and I2S module, including the TX and RX FIFO
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2015.01.28     WangLei      v1.0         Modified from sdio_ahb_if
// 2015.10.23     WangLei      v1.1        fix some bug, add the 16/24 bit data length
// 2016.10.10     WangLei      v2.0        Added the MSB_LSB function
//**********************************************************************

module spi_i2s_apb_if (
			// For APB bus
    		pclk, rst_n, psel, penable, paddr, pwrite, pwdata, prdata,
			// control reg
			bidimode, spi_txrx, msb_lsb, spe, mstr, 
			// interrupt reg
			txeie, rxneie, errie, txesel, rxesel,
			// state reg
			tx_fifo_fill, rx_fifo_fill, bsy, ovr, udr, chside, tx_shift_empty,
			// config reg
			i2smod, i2se, i2sms, i2scfg, pcmsync, i2sstd, ckpol, datlen, chlen, 
			// predivider reg
			mckoe, odd, i2sdiv,
			// for tx fifo
			dr_wr, tx_fifo_data_in, 
			// for rx fifo
			dr_rd, rx_fifo_out,
			// for reg output
			d_reg_flag, tx_d_reg, csn_wsi, tx_reg_hold, tx_reg_hold_rcv, d_reg_spi_rd,
			
			// interrupt
			spi_i2s_int, err_comm_ctrl, spi_out_int_i, spi_out_int_o, spi_out_int_oe
        	);
//--------------------------------------------------------
//Input/Output define
//--------------------------------------------------------
input         	pclk;            // APB's clock 
input         	rst_n;           // system reset
// AHB bus signal
input         	psel;   
input           penable;           
input [7:0]   	paddr;
input         	pwrite; // high for write, low for read
input [31:0]  	pwdata;
output[31:0]  	prdata;

output          bidimode; // being "0" means bidrectional, being "1" means one directional
output          spi_txrx; // only used when bidimode is "1", being "0" means only rx, being "1" means only tx
output          msb_lsb;
output          spe; // SPI enable, being high means i2s is enable
output          mstr; // SPI MASTER/SLAVE, being "0" means slave, being "1" means MASTER
output			txeie, rxneie, errie; 
output [1:0]	txesel, rxesel;
input [3:0] 	tx_fifo_fill;
input [3:0] 	rx_fifo_fill;
input			bsy;
input           ovr, udr;// need furthor usage
input           chside, tx_shift_empty;
output [1:0]	i2sstd, datlen;
output			i2scfg;
output          i2smod; // being "0" means SPI, being "1" means I2S
output			i2sms; // master/slave select
output			i2se; // i2s enable, being high means i2s is enable
output			pcmsync, ckpol;
output			chlen; // being high means 32bit ,low means 16bit
output			mckoe, odd;
output [13:0]	i2sdiv;

output			dr_wr;
output [31:0]	tx_fifo_data_in;

output          dr_rd;
input [31:0]    rx_fifo_out;
output          d_reg_flag;
output [31:0]   tx_d_reg;
input           csn_wsi;
output          tx_reg_hold;
input           tx_reg_hold_rcv;
input           d_reg_spi_rd;

output			spi_i2s_int;
input			err_comm_ctrl;
input           spi_out_int_i;
output          spi_out_int_o;
output          spi_out_int_oe;
//--------------------------------------------------------
//Reg and wire define
//--------------------------------------------------------
reg [31:0]		prdata_reg;

reg             spe;

reg				txeie, rxneie, errie, outie; 
reg				txe, rxne, err;
reg [1:0]		txesel, rxesel; // choose when the TX/RX int generate
reg [1:0]		i2sstd, datlen;
reg				i2smod, i2se, i2sms, pcmsync, ckpol, chlen, i2scfg;
reg				mckoe, odd;
reg [13:0]		i2sdiv;

wire			cr1_wr, cr2_wr, dr_wr, cfgr_wr, pr_wr, host_int_wr;
wire			cr1_rd, cr2_rd, sr_rd, dr_rd, cfgr_rd, pr_rd, host_int_rd;
wire [31:0]		rx_fifo_out;
reg [31:0]		tx_fifo_data_in;
reg             tx_reg_hold;
reg             d_reg_flag;
reg             mstr;
reg [31:0]      tx_d_reg;
reg             csn_wsi_reg;
reg             out_int_oe;
reg             out_int_i_reg;
reg             out_int_o_reg;
reg             msb_lsb; // being "1" means MSB

//  APB write signal
assign          cr1_wr = psel & penable & pwrite & (paddr == 8'h00); 
assign			cr2_wr = psel & penable & pwrite & (paddr == 8'h04); 
assign			dr_wr  = psel & penable & pwrite & (paddr == 8'h0c); 
assign          d_reg_wr = psel & penable & pwrite & (paddr == 8'h10); 
assign			cfgr_wr = psel & penable & pwrite & (paddr == 8'h1c); 
assign			pr_wr = psel & penable & pwrite & (paddr == 8'h20); 
assign			host_int_wr = psel & penable & pwrite & (paddr == 8'h24); 

// APB read signal
assign			cr1_rd = psel & (~penable) & (~pwrite) & (paddr == 8'h00); 
assign			cr2_rd = psel & (~penable) & (~pwrite) & (paddr == 8'h04); 
assign			sr_rd = psel & (~penable) & (~pwrite) & (paddr == 8'h08); 
assign			dr_rd = psel & (~penable) & (~pwrite) & (paddr == 8'h0c); 
assign			d_reg_rd = psel & (~penable) & (~pwrite) & (paddr == 8'h10); 
assign			cfgr_rd = psel & (~penable) & (~pwrite) & (paddr == 8'h1c); 
assign			pr_rd = psel & (~penable) & (~pwrite) & (paddr == 8'h20); 
assign			host_int_rd = psel & (~penable) & (~pwrite) & (paddr == 8'h24); 

//--------------------------------------------------------
//APB write
//--------------------------------------------------------
// write control register 1, mainly for SPI
always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		begin msb_lsb <= 1'b0; spe <= 1'b0; mstr <= 1'b0; end
	else if (cr1_wr)
		begin msb_lsb <= pwdata[12]; spe <= pwdata[6]; mstr <= pwdata[2]; end
end 

// write control register 2, mainly for interrupt
always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		begin out_int_oe <= 1'b0; txeie <= 1'b0; rxneie <= 1'b0; errie <= 1'b0; outie <= 1'b0; end
	else if (cr2_wr)
		begin out_int_oe <= pwdata[12]; txeie <= pwdata[7]; rxneie <= pwdata[6]; errie <= pwdata[5]; outie <= pwdata[4]; txesel <= pwdata[3:2]; rxesel <= pwdata[1:0];end
end 

// Set host interrupt
always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		begin out_int_o_reg <= 1'b0; end
	else if(host_int_wr)
		begin out_int_o_reg <= pwdata[0]; end
end
	
always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		out_int_i_reg <= 1'b0; 
	else if(!spi_out_int_oe)
		out_int_i_reg <= 1'b0;
	else 
		out_int_i_reg <= spi_out_int_i;
end

assign spi_out_int_oe = out_int_oe;
assign spi_out_int_o = spi_out_int_oe?out_int_o_reg:1'b0;
//-------------------------------------------------------
// interrupt control
//-------------------------------------------------------

always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		txe <= 1'b0;
	else if(cr2_wr)
		txe <= pwdata[10];
	else 
		begin
			case(txesel)
				2'b00: if ((tx_fifo_fill == 4'h0) && tx_shift_empty) 	
						txe <= 1'b1;
				2'b01: if (tx_fifo_fill == 4'h0)
						txe <= 1'b1;
				2'b10: if (tx_fifo_fill <= 4)
						txe <= 1'b1;
				2'b11: if (tx_fifo_fill < 8)
						txe <= 1'b1;
				default: txe <= 1'b0;
			endcase
		end
	
end

always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		rxne <= 1'b0;
	else if(cr2_wr)
		rxne <= pwdata[9];
	else 
		begin
			case(rxesel)
				2'b00: if (rx_fifo_fill == 4'h0) 	
						rxne <= 1'b1;
				2'b01: if (rx_fifo_fill != 4'h0)
							rxne <= 1'b1;
						else
							rxne <= 1'b0;
				2'b10: if (rx_fifo_fill >= 4)
						rxne <= 1'b1;
				2'b11: if (rx_fifo_fill == 8)
						rxne <= 1'b1;
				default: rxne <= 1'b0;
			endcase
		end
	
end

always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		err <= 1'b0;
	else if (cr2_wr)
		err <= pwdata[8]; // need to add other situation. 
	else if (err_comm_ctrl)
		err <= 1'b1;
end

assign	spi_i2s_int =	(txe && txeie) |
						(rxne && rxneie) |
						(err && errie) |
						(out_int_i_reg && outie) ;

always@(*)
begin
	case({i2sstd,datlen,chlen})
	//5'b00000: tx_fifo_data_in = pwdata;
	5'b00001, 5'b01001, 5'b11001: tx_fifo_data_in = { pwdata[15:0], 16'h0000};
	5'b00011, 5'b01011, 5'b11011: tx_fifo_data_in = { pwdata[23:0], 8'h00};
	5'b10001: tx_fifo_data_in = {16'h0000, pwdata[15:0]};
	5'b10011: tx_fifo_data_in = {8'h00, pwdata[23:0]};
	default:begin 
				if(msb_lsb)
					tx_fifo_data_in = pwdata;
				else
					tx_fifo_data_in = { pwdata[7:0], pwdata[15:8], pwdata[23:16], pwdata[31:24] } ;
			end
	endcase
end


// write configure register 
always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		begin 
			i2smod <= 1'b0; i2se <= 1'b0; i2sms <= 1'b0; i2scfg <= 1'b0; pcmsync <= 1'b0; i2sstd <= 2'b00; ckpol <= 1'b0;  
			datlen <= 2'b00; chlen <= 1'b0; 
		end
	else if (cfgr_wr) 
		begin 
			if((!i2se) && (!spe) )
				i2smod <= pwdata[11]; 
			i2se <= pwdata[10]; 
			if(!i2se)
			begin 
				i2sms <= pwdata[9]; i2scfg <= pwdata[8]; pcmsync <= pwdata[7]; i2sstd <= pwdata[5:4]; ckpol <= pwdata[3];  
				if(pwdata[2:1] != 2'b11) // 2'b11 is not allow; 00:16bit 01:24bit 10:32bit
					datlen <= pwdata[2:1]; 
					
				if((datlen == 2'b00) || (pwdata[2:1] == 2'b00)) // data length is 16bit
					chlen <= pwdata[0]; 
				else // otherwise channel lenghth fixed to 32bit
					chlen <= 1'b1; 
			end
		end
end 

// write prescaler register 
always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		begin 
			mckoe <= 1'b0; odd <= 1'b0; i2sdiv <= 14'h0000;
		end
	else if (pr_wr & (!i2se)) 
		begin 
			mckoe <= pwdata[15]; odd <= pwdata[14]; i2sdiv <= pwdata[13:0];
		end
end 


//--------------------------------------------------------
//APB read
//--------------------------------------------------------
always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		prdata_reg <= 32'h00000000;
	else if(cr1_rd)
		prdata_reg <= {19'h0000,msb_lsb,5'h00,spe,3'h0, mstr,2'b00};
	else if(cr2_rd)
		prdata_reg <= {19'h00000, out_int_oe, 1'b0,txe, rxne, err, txeie, rxneie, errie, outie, txesel, rxesel};
	else if(sr_rd)
		prdata_reg <= {16'h0000,tx_fifo_fill, rx_fifo_fill, bsy, ovr,2'b00, udr, chside, 2'b00};
	else if(cfgr_rd)
		prdata_reg <= {21'h000000, i2se, i2sms, i2scfg, pcmsync, 1'b0, i2sstd, ckpol, datlen, chlen};
	else if(pr_rd)
		prdata_reg <= {16'h0000, mckoe, odd, i2sdiv};
	else if(host_int_rd)	
		prdata_reg <= {30'h00000000, out_int_i_reg};
	else
		prdata_reg <= 32'h00000000;
end

assign prdata = ((psel == 1'b1) && (~pwrite) && (paddr == 8'h0C))?
				(msb_lsb?rx_fifo_out:{rx_fifo_out[7:0], rx_fifo_out[15:8], rx_fifo_out[23:16], rx_fifo_out[31:24]})
				:prdata_reg;

//--------------------------------------------------------
// For SPI reg read
//--------------------------------------------------------

always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		begin tx_d_reg <= 32'h00000000; d_reg_flag <= 1'b0; end
	else if(!tx_reg_hold && d_reg_wr)
		begin 
			d_reg_flag <= 1'b1; 
			if(msb_lsb)
				tx_d_reg <= pwdata;
			else
				tx_d_reg <= {pwdata[7:0], pwdata[15:8], pwdata[23:16], pwdata[31:24]};
		end
	else if(d_reg_spi_rd)
		begin tx_d_reg <= 32'h0000_0000; d_reg_flag <= 1'b0; end
	else 
		begin tx_d_reg <= tx_d_reg; d_reg_flag <= d_reg_flag; end
end

always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		csn_wsi_reg <= 1'b0;
	else
		csn_wsi_reg <= csn_wsi;
end

always @(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		tx_reg_hold <= 1'b0;
	else if(!csn_wsi && csn_wsi_reg && !tx_reg_hold)
		tx_reg_hold <= 1'b1;
	else if(tx_reg_hold_rcv && tx_reg_hold)
		tx_reg_hold <= 1'b0; 
	
end


endmodule
