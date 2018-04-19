//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : spi_i2s_shifter.v
// Author      : WangLei
// Created     : 2015.01.28
// Description : I2S's shifter out and in
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2015.02.15     WangLei      v1.0         Initial version
//**********************************************************************

module spi_i2s_shifter (
						sdi, 
						sdo,
						ckpol,
						i2se,
						i2sms,
						i2sstd,
						i2scfg,
						datlen,
						pcmsync,
						chlen,
						i2s_clk_shifter,
						rst_n_shifter,
						tx_fifo_fill,
						tx_fifo_dat,
						tx_shift_empty,
						tx_fifo_acq,
						rx_shifter_upload,
						rx_enable,
						rx_shifter,
						chside,
						wsi,
						wso,
						rx_fifo_wr
						);

// input and output definition
input			sdi;
output			sdo;
input			ckpol;
input			i2se;
input			i2sms;
input [1:0]		i2sstd;
input [1:0]		datlen;
input			i2scfg;
input			pcmsync;
input			chlen;
input			i2s_clk_shifter;
input			rst_n_shifter;
input			rx_shifter_upload;
input [3:0]		tx_fifo_fill;
input [31:0]	tx_fifo_dat;
input			rx_enable;
output [31:0]	rx_shifter;
output			tx_shift_empty;
output			tx_fifo_acq;
output			chside;
input			wsi;
output			wso;
output			rx_fifo_wr;
// reg and wire definition
reg [31:0]		tx_shifter;
reg [31:0]		rx_shifter;
reg	[5:0]		tx_counter;
//reg				tx_shift_empty;
reg [5:0]		frame_length_high, frame_length_low;
wire			end_of_trans;
reg [2:0]		shifter_state, next_shifter_state;
reg [5:0]		frame_counter;
reg				chside;
reg				tx_shifter_first_load, tx_shifter_load;
reg [1:0]		start_counter, start_cycles;
reg				rx_fifo_wr;
parameter		shifter_idle = 3'b000, shifter_start_mst = 3'b001, shifter_work_mst = 3'b011,
				shifter_end_mst = 3'b100, shifter_start_slv = 3'b101, shifter_work_slv = 3'b110;
				//shifter_end_slv = 3'b111;

always@(negedge i2s_clk_shifter or negedge rst_n_shifter)
begin
	if(~rst_n_shifter)
		shifter_state <= shifter_idle;
	else
		shifter_state <= next_shifter_state;
end

always@(*)
begin
	case(shifter_state)
	shifter_idle:	begin
						if(i2sms)
							begin 
							if(i2se)
								if(ckpol)
									next_shifter_state = shifter_start_mst;
								else
									next_shifter_state = shifter_work_mst;
							else
								next_shifter_state = shifter_idle;
							end
						else // in slave mode
							begin 
							if(i2sstd == 2'b00)
								begin 
								if(i2se && wsi == 1'b0)
									next_shifter_state = shifter_start_slv;
								else
									next_shifter_state = shifter_idle;
								end
							else
								begin 
								if(i2se && wsi == 1'b1)
									next_shifter_state = shifter_start_slv;
								else
									next_shifter_state = shifter_idle;
								end
							end
					end
	shifter_start_mst:	begin
						if(start_counter == start_cycles)
							next_shifter_state = shifter_work_mst;
						else
							next_shifter_state = shifter_start_mst;
					end
	shifter_work_mst:	begin
						if(~i2se)
							next_shifter_state = shifter_end_mst;
						else
							next_shifter_state = shifter_work_mst;
					end
	shifter_end_mst:	begin
						if(end_of_trans)
							next_shifter_state = shifter_idle;
						else
							next_shifter_state = shifter_end_mst;
					end
	shifter_start_slv:	begin
							if(start_counter == start_cycles)
								next_shifter_state = shifter_work_slv;
							else
								next_shifter_state = shifter_start_slv;
						end
	shifter_work_slv:	begin
							if(~i2se)
								next_shifter_state = shifter_idle;
							else
								next_shifter_state = shifter_work_slv;
					end
	default:	begin next_shifter_state = shifter_idle; end 
	endcase
end

assign	end_of_trans = (tx_fifo_fill == 4'h0) && (tx_counter == 6'h01);

always@(negedge i2s_clk_shifter or negedge rst_n_shifter)
begin
	if (~rst_n_shifter)
		begin chside <= 1'b0; frame_counter <= 6'h00; start_counter <= 2'b00; end
	else
		case(next_shifter_state)
			shifter_idle:	begin 
						frame_counter <= 6'h00;
						start_counter <= 2'b00; 
						if(i2sstd == 2'b00)
							chside <= 1'b1;
						else
							chside <= 1'b0;
					end
			shifter_start_mst:	begin
								start_counter <= start_counter + 1'b1; 
								if(i2sms)
									begin 
										if(chside)
											if(frame_counter == frame_length_high)
												begin frame_counter <= 6'h01;end
											else
												begin frame_counter <= frame_counter + 1'b1;end
										else
											if(frame_counter == frame_length_low)
												begin frame_counter <= 6'h01; end
											else
												begin frame_counter <= frame_counter + 1'b1;end
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
			shifter_work_mst:	begin 
								start_counter <= 2'b00;
								case({i2sms, chside})
								2'b00,2'b01:	begin frame_counter <= 6'h00; chside <= 1'b0;end 
								2'b10:	begin 
											if(frame_counter == frame_length_low)
												begin frame_counter <= 6'h01; chside <= 1'b1;end
											else
												begin frame_counter <= frame_counter + 1'b1;chside <= 1'b0;end
										end 
								2'b11:	begin
											if(frame_counter == frame_length_high)
												begin frame_counter <= 6'h01; chside <= 1'b0;end
											else
												begin frame_counter <= frame_counter + 1'b1;chside <= 1'b1;end
										end
								default:begin frame_counter <= 6'h00; chside <= 1'b0; end
								endcase
							end
			shifter_end_mst:	begin
								start_counter <= 2'b00;
								case({i2sms, chside, i2sstd})
								4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0100, 4'b0101, 4'b0110,
								4'b0111:	begin frame_counter <= 6'h00; chside <= 1'b0;end  
								4'b1000:	begin
												if(frame_counter == frame_length_low)
												begin frame_counter <= 6'h01; chside <= 1'b1;end
												else
												begin frame_counter <= frame_counter + 1'b1;chside <= 1'b0;end
											end
								4'b1100:	begin
												if(frame_counter == frame_length_high)
												begin frame_counter <= 6'h01; chside <= 1'b1;end
												else
												begin frame_counter <= frame_counter + 1'b1;chside <= 1'b1;end
											end
								4'b1000, 4'b1001, 4'b1010, 4'b1011:	begin
												if(frame_counter == frame_length_low)
												begin frame_counter <= 6'h01; chside <= 1'b0;end
												else
												begin frame_counter <= frame_counter + 1'b1;chside <= 1'b0;end
											end
								4'b1100, 4'b1101, 4'b1110, 4'b1111:	begin
												if(frame_counter == frame_length_high)
												begin frame_counter <= 6'h01; chside <= 1'b0;end
											else
												begin frame_counter <= frame_counter + 1'b1;chside <= 1'b1;end
											end
								default:	begin frame_counter <= frame_counter; chside <= 1'b0; end // slave mode
								endcase
							end
			shifter_start_slv:	begin
									start_counter <= start_counter + 1'b1;chside <= 1'b0; frame_counter <= 6'h00;
								end
			shifter_work_slv:	begin 
									start_counter <= 2'b00; chside <= 1'b0; frame_counter <= 6'h00;
								end
			default: begin start_counter <= 2'b00; chside <= 1'b0; frame_counter <= 6'h00; end
		endcase
end

assign		wso = (shifter_state == shifter_idle)?((i2sstd == 2'b00)?1'b1:1'b0):chside;

always@(*)
begin
	case({i2sstd,datlen,chlen})
	5'b00000, 5'b01000, 5'b10000:	begin 
					frame_length_high = 16; frame_length_low = 16;
				end
	5'b00001, 5'b00010, 5'b00011, 5'b00100, 5'b00101, 5'b01001, 5'b01010,
	5'b01011, 5'b01100, 5'b01101, 5'b10001, 5'b10010, 5'b10011, 5'b10100, 5'b10101:	begin 
					frame_length_high = 32; frame_length_low = 32;
				end
	5'b11000:	begin
					if(pcmsync)
						begin frame_length_high = 13; frame_length_low = 3;end
					else
						begin frame_length_high = 1; frame_length_low = 15;end
				end
	5'b11001, 5'b11010, 5'b11011, 5'b11100, 5'b11101:	begin
				if(pcmsync)
					begin frame_length_high = 13; frame_length_low = 19;end
				else
					begin frame_length_high = 1; frame_length_low = 31;end
			end
	default:begin frame_length_high = 32; frame_length_low = 32; end
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

always@(negedge i2s_clk_shifter or negedge rst_n_shifter)
begin
	if (~rst_n_shifter)
		begin tx_shifter <= 32'h0000_0000; tx_counter <= 6'h00; end
	else if(tx_shifter_first_load)
		begin tx_shifter <= {tx_fifo_dat[30:0],1'b0}; tx_counter <= 6'h1f; end
	else if(tx_shifter_load)
		begin tx_shifter <= tx_fifo_dat; tx_counter <= 6'h20; end
	else
		begin tx_shifter <= (tx_shifter << 1); tx_counter <= tx_counter - 1'b1; end
end

always@(posedge i2s_clk_shifter or negedge rst_n_shifter) // For FIFO load signal
begin
	if (~rst_n_shifter)
		begin tx_shifter_first_load <= 1'b0; tx_shifter_load <= 1'b0; end
	else
		begin
			if(((shifter_state == shifter_idle) || (shifter_state == shifter_start_mst) || (shifter_state == shifter_start_slv)) && (start_counter == start_cycles))
				tx_shifter_first_load <= 1'b1;
			else
				tx_shifter_first_load <= 1'b0;
			if( ((tx_counter == 6'h00) || (tx_counter == 6'h01)) && (tx_fifo_fill != 4'h0))
				tx_shifter_load <= 1'b1;
			else
				tx_shifter_load <= 1'b0;
		end
end

assign		tx_fifo_acq = tx_shifter_first_load | tx_shifter_load;
//assign		rx_fifo_wr = rx_enable && tx_shifter_load;
assign		tx_shift_empty = (tx_counter == 6'h00)?1'b1:1'b0;

assign		sdo = ((shifter_state == shifter_work_mst) || (shifter_state == shifter_end_mst) 
					|| (shifter_state == shifter_work_slv) )?tx_shifter[31]:tx_fifo_dat[31];

always@(negedge i2s_clk_shifter or negedge rst_n_shifter)
begin
	if (~rst_n_shifter)
		rx_fifo_wr <= 1'b0;
	else
		begin
			if ((tx_counter == 6'h02) && rx_enable)
				rx_fifo_wr <= 1'b1;
			else
				rx_fifo_wr <= 1'b0;
		end
end

always@(posedge i2s_clk_shifter or negedge rst_n_shifter)
begin
	if (~rst_n_shifter)
		rx_shifter <= 32'h0000_0000;
	else if(rx_enable)
		if(rx_fifo_wr)//if(rx_shifter_upload)
			rx_shifter <= {31'h0000_0000, sdi};
		else
			rx_shifter <= {rx_shifter[30:0], sdi};
end

endmodule
