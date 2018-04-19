//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : spi_i2s_comm_ctrl.v
// Author      : WangLei
// Created     : 2015.01.28
// Description : APB bus interface logic of SPI and I2S module, including the TX and RX FIFO
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2015.01.28     WangLei      v1.0         Modified from sdio_ahb_if
//**********************************************************************

module spi_i2s_comm_ctrl (
						pclk, 
						rst_n,
						i2smod, 
						i2se,
						i2sms,
						i2sstd,
						i2scfg,
						datlen,
						pcmsync,
						chlen,
						mstr,
						tx_fifo_fill,
						tx_shift_empty, 
						bsy, 
						rx_shft_upload,
						rst_n_shft,
						i2s_rx_enable,
						err_comm_ctrl,
						sdoe,
						csn_ws_oe,
						sckoe,
						miso_oe, 
						mosi_oe
						);
// input and output definition
input		pclk, rst_n;
input       i2smod;
input		i2se;
input		i2sms;
input [1:0]	i2sstd;
input [1:0]	datlen;
input		i2scfg;
input		pcmsync;
input		chlen;
input       mstr;
input [3:0]	tx_fifo_fill;
input		tx_shift_empty;
output		bsy;
output		rx_shft_upload;
output		rst_n_shft;
output		i2s_rx_enable;
output		err_comm_ctrl;
output      sdoe;
output      csn_ws_oe;
output		sckoe;
output      miso_oe;
output		mosi_oe;
// reg and wire definition
reg [2:0]	state, next_state;
//reg			i2s_clk_reg;
//reg			chside;
reg			bsy;

parameter	idle = 3'b000, transition = 3'b001, ending = 3'b011, err_state = 3'b100;

always@(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		state <= idle;
	else
		state <= next_state;
end

always@(*)
begin
	case(state)
	idle: 		begin 
					if(i2se && (tx_fifo_fill != 4'h0))
						next_state = transition;
					else
						next_state = idle;
				end
	transition:	begin
					if(~i2se)
						next_state = ending;
					else if((tx_fifo_fill == 4'h0) && (tx_shift_empty == 1'b1))
						next_state = err_state;
					else
						next_state = transition;
				end
	ending:		begin
					if(~bsy)
						next_state = idle;
					else
						next_state = ending;
				end
	err_state:	begin
					if(~i2se)
						next_state = idle;
					else	
						next_state = err_state;
				end
	default:	begin next_state = idle; end
	endcase
end

always@(posedge pclk or negedge rst_n)
begin
	if (~rst_n)
		begin bsy <= 1'b0;  end
	else
		case(next_state)
			idle:	begin 
						bsy <= 1'b0;
					end
			transition:	begin 
							if(i2sms)
								begin 
									bsy <= 1'b1;
								end // master mode
							else 
								begin 
									bsy <= 1'b1;
								end // slave mode
						end
			ending:		begin
							if(i2sms)
								begin
									if((tx_fifo_fill == 4'h0) && tx_shift_empty )
										bsy <= 1'b0;
									else
										bsy <= 1'b1;
								end
							else
								begin
									bsy <= 1'b0;
								end
						end
			err_state:	begin
							bsy <= 1'b0;
						end
			default: begin bsy <= 1'b0; end
		endcase
end


assign	rst_n_shft = rst_n && (state != idle);
assign	i2s_rx_enable = i2scfg && bsy;
assign	err_comm_ctrl = (state == err_state)?1'b1:1'b0;
assign  sdoe = i2smod?(i2se?1'b1:1'b0):1'b0;
assign  csn_ws_oe = i2smod?(i2sms?1'b1:1'b0):(mstr?1'b1:1'b0);
assign  sckoe = i2smod?(i2sms?1'b1:1'b0):(mstr?1'b1:1'b0);
assign  miso_oe = i2smod?(1'b0):(mstr?1'b0:1'b1);
assign  mosi_oe = i2smod?(1'b0):(mstr?1'b1:1'b0);
endmodule
