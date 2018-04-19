//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : spi_i2s_shft_ctrl.v
// Author      : WangLei
// Created     : 2015.01.28
// Description : I2S's shifter's controller
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2015.02.15     WangLei      v1.0         Initial version
//**********************************************************************

module spi_i2s_shft_ctrl (
						// SPI ctrl & cfg signal
						spe,mstr, tx_sta_reg, 
						// SPI ports
						mosi_s,  miso_m,
						//I2S signal
						sdi, 
						ckpol,
						
						i2smod,
						i2se,
						i2sms,
						i2sstd,
						i2scfg,
						datlen,
						pcmsync,
						chlen,
						i2s_clk_shft,
						rst_n,
						tx_fifo_fill,
						tx_fifo_dat,
						tx_shift_empty,
						tx_fifo_acq,
						rx_shft_upload,
						i2s_rx_enable,
						rx_shft,
						chside,
						
						wso,
						rx_fifo_wr,
						
						shft_state,
						tx_shft_first_load,
						tx_shft_load,
						rcv_cmd,
						cmd_shft,
						trans_cnt
						);

// input and output definition
input			sdi;
input			ckpol;
//SPI/I2S CONFIG
input           spe;
input           mstr;
input [31:0]    tx_sta_reg;

// SPI ports
input           mosi_s;

input           miso_m;
input			i2smod;
input			i2se;
input			i2sms;
input [1:0]		i2sstd;
input [1:0]		datlen;
input			i2scfg;
input			pcmsync;
input			chlen;
input			i2s_clk_shft;
input			rst_n;
input			rx_shft_upload;
input [3:0]		tx_fifo_fill;
input [31:0]	tx_fifo_dat;
input			i2s_rx_enable;
output [31:0]	rx_shft;
output			tx_shift_empty;
output			tx_fifo_acq;
output			chside;

output			wso;
output			rx_fifo_wr;
output [3:0]    shft_state;
output			tx_shft_first_load;
output			tx_shft_load;
output			rcv_cmd;
output [7:0]	cmd_shft;
output [5:0]    trans_cnt;
// reg and wire definition

reg [31:0]		rx_shft;
reg	[5:0]		trans_cnt;
//reg				tx_shift_empty;
reg [5:0]		frm_length_high, frm_length_low;
wire			end_of_trans;
reg [3:0]		shft_state, next_shft_state;
reg [5:0]		frm_cnt;
reg				chside;
reg				tx_shft_first_load, tx_shft_load;
reg [1:0]		start_cnt, start_cycles;
reg				rx_fifo_wr;
reg [7:0]       cmd_shft;
reg [3:0]       cmdrcv_cnt;
reg             rcv_cmd;
reg             rx_shft_first_load;
wire            dat_shft_in, spi_fifo_rx_enable;
wire            shft_first_load, shft_load;
wire            rx_fifo_load;

parameter		shft_idle = 4'h0, shft_i2s_st_mst = 4'h1, shft_i2s_wk_mst = 4'h2,
				shft_i2s_end_mst = 4'h3, shft_i2s_st_slv = 4'h4, shft_i2s_wk_slv = 4'h5,
				shft_spi_st_slv = 4'h6, shft_spi_reg_rd_slv = 4'h7, shft_spi_fifo_rd_slv = 4'h8,
				shft_spi_fifo_wr_slv = 4'h9;
				//shft_end_slv = 3'b111;
//-------------------------------------------------------------------------------
// begin of shifter state 
//-------------------------------------------------------------------------------
always@(posedge i2s_clk_shft or negedge rst_n)
begin
	if(~rst_n)
		shft_state <= shft_idle;
	else
		shft_state <= next_shft_state;
end

always@(*)
begin
	case(shft_state)
	shft_idle:	begin
					if(i2smod) begin
						if(i2sms) begin 
							if(i2se)
								if(ckpol)
									next_shft_state = shft_i2s_st_mst;
								else
									next_shft_state = shft_i2s_wk_mst;
							else
								next_shft_state = shft_idle;
						end
						else begin // in slave mode
							if(i2sstd == 2'b00)
								begin 
								if(i2se )
									next_shft_state = shft_i2s_st_slv;
								else
									next_shft_state = shft_idle;
								end
							else
								begin 
								if(i2se)
									next_shft_state = shft_i2s_st_slv;
								else
									next_shft_state = shft_idle;
								end
						end
					end
					else begin // for SPI mode
						if(mstr) begin
							next_shft_state = shft_idle; // temp for master
						end
						else begin
							if(spe)
								next_shft_state = shft_spi_st_slv;
							else
								next_shft_state = shft_idle;
						end
					end
				end
	shft_spi_st_slv:	begin
							if(rcv_cmd)
								case(cmd_shft)
								8'h80, 8'h98: next_shft_state = shft_spi_reg_rd_slv;
								8'h90: next_shft_state = shft_spi_fifo_rd_slv; // can do read & write
								8'hd0: next_shft_state = shft_spi_fifo_wr_slv; // only host write slave
								default: next_shft_state = shft_idle;
								endcase
							else
								next_shft_state = shft_spi_st_slv;
						end
	shft_spi_reg_rd_slv: begin
							if(!end_of_trans)
								next_shft_state = shft_spi_reg_rd_slv;
							else
								next_shft_state = shft_idle;
						  end
	shft_spi_fifo_rd_slv: begin
							if(!end_of_trans)
								next_shft_state = shft_spi_fifo_rd_slv;
							else
								next_shft_state = shft_idle;
						  end
	shft_spi_fifo_wr_slv: begin
							if(spe)
								next_shft_state = shft_spi_fifo_wr_slv;
							else
								next_shft_state = shft_idle;
	                      end
	shft_i2s_st_mst:	begin
						if(start_cnt == start_cycles)
							next_shft_state = shft_i2s_wk_mst;
						else
							next_shft_state = shft_i2s_st_mst;
					end
	shft_i2s_wk_mst:	begin
						if(~i2se)
							next_shft_state = shft_i2s_end_mst;
						else
							next_shft_state = shft_i2s_wk_mst;
					end
	shft_i2s_end_mst:	begin
						if(end_of_trans)
							next_shft_state = shft_idle;
						else
							next_shft_state = shft_i2s_end_mst;
					end
	shft_i2s_st_slv:	begin
							if(start_cnt == start_cycles)
								next_shft_state = shft_i2s_wk_slv;
							else
								next_shft_state = shft_i2s_st_slv;
						end
	shft_i2s_wk_slv:	begin
							if(~i2se)
								next_shft_state = shft_idle;
							else
								next_shft_state = shft_i2s_wk_slv;
					end
	default:	begin next_shft_state = shft_idle; end 
	endcase
end

always@(posedge i2s_clk_shft or negedge rst_n)
begin
	if (~rst_n)
		begin 
			chside <= 1'b0; frm_cnt <= 6'h00; start_cnt <= 2'b00;
			cmd_shft <= 8'h00; cmdrcv_cnt <= 4'h0; rcv_cmd <= 1'b0; 
		end
	else
		case(next_shft_state)
			shft_idle:	begin 
						frm_cnt <= 6'h00; start_cnt <= 2'b00; 
						if(i2sstd == 2'b00)
							begin chside <= 1'b1; end
						else
							begin chside <= 1'b0; end
						cmd_shft <= 8'h00; cmdrcv_cnt <= 4'h0; rcv_cmd <= 1'b0;
					end
			shft_spi_st_slv:	begin
									chside <= 1'b0; frm_cnt <= 6'h00; start_cnt <= 2'b00;
									cmd_shft <= {cmd_shft[6:0], mosi_s}; cmdrcv_cnt <= cmdrcv_cnt + 1'b1;
									if(cmdrcv_cnt == 4'h7)
										begin rcv_cmd <= 1'b1; end
									else
										begin rcv_cmd <= 1'b0; end
								end
			shft_spi_reg_rd_slv, shft_spi_fifo_rd_slv, shft_spi_fifo_wr_slv: begin
										chside <= 1'b0; frm_cnt <= 6'h00; start_cnt <= 2'b00;
										cmd_shft <= 8'h00; cmdrcv_cnt <= 4'h0; rcv_cmd <= 1'b0;
									end
			shft_i2s_st_mst:	begin
								start_cnt <= start_cnt + 1'b1; 
								if(i2sms)
									begin 
										if(chside)
											if(frm_cnt == frm_length_high)
												begin frm_cnt <= 6'h01;end
											else
												begin frm_cnt <= frm_cnt + 1'b1;end
										else
											if(frm_cnt == frm_length_low)
												begin frm_cnt <= 6'h01; end
											else
												begin frm_cnt <= frm_cnt + 1'b1;end
											if(i2sstd == 2'b00)
												chside <= 1'b0;
											else
												chside <= 1'b1;
									end // master mode
								else 
									begin 
										chside <= 1'b0;
									end // slave mode
							end
			shft_i2s_wk_mst:	begin 
								start_cnt <= 2'b00;
								case({i2sms, chside})
								2'b00,2'b01:	begin frm_cnt <= 6'h00; chside <= 1'b0;end 
								2'b10:	begin 
											if(frm_cnt == frm_length_low)
												begin frm_cnt <= 6'h01; chside <= 1'b1;end
											else
												begin frm_cnt <= frm_cnt + 1'b1;chside <= 1'b0;end
										end 
								2'b11:	begin
											if(frm_cnt == frm_length_high)
												begin frm_cnt <= 6'h01; chside <= 1'b0;end
											else
												begin frm_cnt <= frm_cnt + 1'b1;chside <= 1'b1;end
										end
								default:begin frm_cnt <= 6'h00; chside <= 1'b0; end
								endcase
							end
			shft_i2s_end_mst:	begin
								start_cnt <= 2'b00;
								case({i2sms, chside, i2sstd})
								4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110,
								4'b0111:	begin frm_cnt <= 6'h00; chside <= 1'b0;end  
								4'b1000:	begin
												if(frm_cnt == frm_length_low)
												begin frm_cnt <= 6'h01; chside <= 1'b1;end
												else
												begin frm_cnt <= frm_cnt + 1'b1;chside <= 1'b0;end
											end
								4'b1100:	begin
												if(frm_cnt == frm_length_high)
												begin frm_cnt <= 6'h01; chside <= 1'b1;end
												else
												begin frm_cnt <= frm_cnt + 1'b1;chside <= 1'b1;end
											end
								4'b1000, 4'b1001, 4'b1010, 4'b1011:	begin
												if(frm_cnt == frm_length_low)
												begin frm_cnt <= 6'h01; chside <= 1'b0;end
												else
												begin frm_cnt <= frm_cnt + 1'b1;chside <= 1'b0;end
											end
								4'b1100, 4'b1101, 4'b1110, 4'b1111:	begin
												if(frm_cnt == frm_length_high)
												begin frm_cnt <= 6'h01; chside <= 1'b0;end
											else
												begin frm_cnt <= frm_cnt + 1'b1;chside <= 1'b1;end
											end
								default:	begin frm_cnt <= frm_cnt; chside <= 1'b0; end // slave mode
								endcase
							end
			shft_i2s_st_slv:	begin
									start_cnt <= start_cnt + 1'b1;chside <= 1'b0; frm_cnt <= 6'h00;
								end
			shft_i2s_wk_slv:	begin 
									start_cnt <= 2'b00; chside <= 1'b0; frm_cnt <= 6'h00;
								end
			default: begin start_cnt <= 2'b00; chside <= 1'b0; frm_cnt <= 6'h00; end
		endcase
end

//-------------------------------------------------------------------------------
// end of shifter state 
//-------------------------------------------------------------------------------

assign	end_of_trans = (tx_fifo_fill == 4'h0) && (trans_cnt == 6'h01);

assign	wso = (shft_state == shft_idle)?((i2sstd == 2'b00)?1'b1:1'b0):chside;

always@(*)
begin
	case({i2sstd,datlen,chlen})
	5'b00000, 5'b01000, 5'b10000:	begin 
					frm_length_high = 16; frm_length_low = 16;
				end
	5'b00001, 5'b00010, 5'b00011, 5'b00100, 5'b00101, 5'b01001, 5'b01010,
	5'b01011, 5'b01100, 5'b01101, 5'b10001, 5'b10010, 5'b10011, 5'b10100, 5'b10101:	begin 
					frm_length_high = 32; frm_length_low = 32;
				end
	5'b11000:	begin
					if(pcmsync)
						begin frm_length_high = 13; frm_length_low = 3;end
					else
						begin frm_length_high = 1; frm_length_low = 15;end
				end
	5'b11001, 5'b11010, 5'b11011, 5'b11100, 5'b11101:	begin
				if(pcmsync)
					begin frm_length_high = 13; frm_length_low = 19;end
				else
					begin frm_length_high = 1; frm_length_low = 31;end
			end
	default:begin frm_length_high = 32; frm_length_low = 32; end
	endcase
end

always@(*)
begin
	if(i2sms)
		case(i2sstd)
		2'b00: start_cycles = 2'b10;
		2'b01: start_cycles = 2'b01;
		default: start_cycles = 2'b10;
		endcase
	else
		start_cycles = 2'b01;
end
// trans_cnt
always@(posedge i2s_clk_shft or negedge rst_n)
begin
	if (~rst_n)
		trans_cnt <= 6'h00; 
	else if(shft_first_load)
		trans_cnt <= 6'h1f;
	else if(shft_load)
		trans_cnt <= 6'h20;
	else
		trans_cnt <= trans_cnt - 1'b1;
end

assign rx_fifo_load = (rcv_cmd && (cmd_shft == 8'hd0));

assign shft_first_load = tx_shft_first_load || rx_shft_first_load;
assign shft_load = tx_shft_load && rx_fifo_load;

// for I2S TX load signal
always@(posedge i2s_clk_shft or negedge rst_n) // For FIFO load signal
begin
	if (~rst_n)
		begin tx_shft_first_load <= 1'b0; tx_shft_load <= 1'b0; end
	else
		begin
			if( 
				(((shft_state == shft_idle) || (shft_state == shft_i2s_st_mst) || (shft_state == shft_i2s_st_slv)) && (start_cnt == start_cycles)) ||
			    ((shft_state == shft_spi_st_slv) && (rcv_cmd && (cmd_shft == 8'h90)) && (tx_fifo_fill != 4'h0)) ||
				((shft_state == shft_spi_fifo_rd_slv) && (trans_cnt == 6'h01) && (tx_fifo_fill != 4'h0)) 
				
				)
				tx_shft_first_load <= 1'b1;
			else
				tx_shft_first_load <= 1'b0;
			if( ((shft_state == shft_i2s_wk_mst) || (shft_state == shft_i2s_end_mst)) 
			&& ((trans_cnt == 6'h00) || (trans_cnt == 6'h01)) && (tx_fifo_fill != 4'h0) )
				tx_shft_load <= 1'b1;
			else
				tx_shft_load <= 1'b0;
		end
end
always@(posedge i2s_clk_shft or negedge rst_n) // For FIFO load signal
begin
	if (~rst_n)
		begin rx_shft_first_load <= 1'b0; end
	else
		begin
			if(
				( (shft_state == shft_spi_st_slv) && (rcv_cmd && (cmd_shft == 8'hd0)) )  ||
				( (shft_state == shft_spi_fifo_wr_slv) && (trans_cnt == 6'h01) )
			)
				rx_shft_first_load <= 1'b1;
			else
				rx_shft_first_load <= 1'b0; 
		end
end

assign		tx_fifo_acq = tx_shft_first_load || tx_shft_load;
//assign		rx_fifo_wr = i2s_rx_enable && tx_shft_load;
assign		tx_shift_empty = (trans_cnt == 6'h00)?1'b1:1'b0;
				
always@(posedge i2s_clk_shft or negedge rst_n)
begin
	if (~rst_n)
		rx_fifo_wr <= 1'b0;
	else
		begin
			if ((trans_cnt == 6'h03) && (i2s_rx_enable || spi_fifo_rx_enable))
				rx_fifo_wr <= 1'b1;
			else
				rx_fifo_wr <= 1'b0;
		end
end
 
assign dat_shft_in = i2smod?sdi:(mstr?miso_m:mosi_s);
assign spi_fifo_rx_enable = ( (next_shft_state == shft_spi_fifo_wr_slv) ) ;

always@(posedge i2s_clk_shft or negedge rst_n)
begin
	if (~rst_n)
		rx_shft <= 32'h0000_0000;
	else if(i2s_rx_enable || spi_fifo_rx_enable)
		if(rx_fifo_wr)//if(rx_shft_upload)
			rx_shft <= {31'h0000_0000, dat_shft_in};
		else
			rx_shft <= {rx_shft[30:0], dat_shft_in};
end

endmodule
