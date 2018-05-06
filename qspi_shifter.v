//---------------------------------------------------------------------
//                                          
//     ____     ____     _____    _____    __  __    _____     ____  
//    /\___\   /\___\   /\____\  |\_____\ |\_\|\_\  |\____\   /\___\ 
//   |\/ _ _\ |\/ _  \  \/ ____| ||  ___| ||  \/  | \|_   _| |\/ _ _\
//   || |     || /_\  | \| |__   || |_\   ||      |   || |   || |    
//   || |___  || |__| |  _\__ \  ||  _|_  || |\/| |  _|| |_  || |___ 
//   \| |___\ || | || | |\__\| | || |___\ || |  | | |\_| |_\ \| |___\
//    \\____/ \|_| \|_| \|____/  \|_____| \|_|  |_| \|_____|  \\____/
//
//  COPYRIGHT 2017, ALL RIGHTS RESERVED
//  
//  Filename:   qspi_shifter
//  Author:          
//  Date:            
//
//  Project:         
//  Descriptions: AHB Interface register for Quad-SPI controller.
//---------------------------------------------------------------------

module   qspi_shifter (
                       rst_n_i,
					   qspi_clk_i,
					   qspi_indi_op_st_i,
					   qspi_fmode_i,
					   qspi_admode_i,
					   qspi_imode_i,
					   qspi_dmode_i,
					   qspi_instruction_i,
					   qspi_flash_addr_i,
					   qspi_adsize_i,
					   qspi_dlr_i,
					   
					   qspi_bsy_o,
					   qspi_clk_o,
					   qspi_cs_n_o,
					   qspi_d_o,
					   qspi_d_i,
					   qspi_d_oe,
					   
					   rd_fifo_clr_o,
					   rd_fifo_wrreq_o,
					   rd_fifo_dat_o,
					   
					   wr_fifo_rdreq_o,
					   wr_fifo_dat_i
					   );

//--------------------------------
//  Ports
//--------------------------------	
input                  rst_n_i;
input                  qspi_clk_i;
input                  qspi_indi_op_st_i;
input [1:0]            qspi_fmode_i;
input [7:0]            qspi_instruction_i;
input [31:0]           qspi_flash_addr_i;
input [1:0]            qspi_admode_i;
input [1:0]            qspi_adsize_i;
input [1:0]            qspi_imode_i;
input [1:0]            qspi_dmode_i;
input [31:0]           qspi_dlr_i;


output                 qspi_bsy_o;
output                 qspi_clk_o;
output                 qspi_cs_n_o;
output [3:0]           qspi_d_o;
input  [3:0]           qspi_d_i;
output [3:0]           qspi_d_oe;

output                 rd_fifo_clr_o;
output                 rd_fifo_wrreq_o;
output [7:0]           rd_fifo_dat_o;

output                 wr_fifo_rdreq_o;
input [7:0]            wr_fifo_dat_i;

parameter    IDLE   = 4'h0,
             START  = 4'h1,  // start the CS active
			 INSTR  = 4'h2,  // instruction phase
			 ADDR   = 4'h3,
			 WR_DA  = 4'h8,
			 RD_DA  = 4'h9;
			 
//--------------------------------
//  Wires and REGs
//--------------------------------
reg         qspi_bsy_o;

reg [3:0]   qspi_d_o;        
reg [3:0]   qspi_d_oe; 

reg [3:0]   state, next_state;
reg         qspi_cs_n_r;
reg         qspi_cs_n_r1;
reg [7:0]   phase_cnt;

reg [7:0]   qspi_instruction_r;
reg [3:0]   qspi_d_o_r;        
reg [3:0]   qspi_d_oe_r;
reg         qspi_spi_clk_oe_r;
reg         qspi_spi_clk_oe;
reg [32:0]  addr_byte_std;
reg [31:0]  qspi_address_r;
reg [7:0]   rd_fifo_dat_o;
reg [7:0]   qspi_data_r;
reg         wr_fifo_rdreq_o;

reg        end_of_instr;
reg        end_of_addr;
reg        end_of_rddat;
reg        end_of_wrdat;

reg [7:0]   phase_inst_std;
reg [7:0]   phase_addr_std;
reg [7:0]   phase_dat_std;



always@(posedge qspi_clk_i or negedge rst_n_i ) begin
  if(!rst_n_i) begin
    state  <= IDLE;
  end
  else begin
    state  <= next_state;
  end
end

always@(*) begin
  case(state)
  IDLE: begin
    if(qspi_indi_op_st_i)
	  next_state  =  START;
	else
	  next_state  = IDLE;
  end
  START: begin
    if(qspi_imode_i != 2'h0)
      next_state   =  INSTR; 
	else if(qspi_admode_i != 2'h0)
	  next_state   =  ADDR;
	else
	  next_state  = IDLE;
  end
  
  INSTR: begin
    if(end_of_instr) begin
	  if(qspi_admode_i == 2'b00) begin
	    if(qspi_dmode_i == 2'b00)
	      next_state  = IDLE;
		else if(qspi_fmode_i == 2'b00)
		  next_state  = WR_DA;
		else if(qspi_fmode_i == 2'b01)
		  next_state  = RD_DA;
		else
		  next_state  = IDLE;
	  end
	  else
	    next_state   =  ADDR;
	end
	else
	  next_state   =  INSTR;
  end
  
  ADDR: begin
    if(end_of_addr) begin
	  if((qspi_dmode_i != 2'b00) && (qspi_fmode_i == 2'b00))
	    next_state = WR_DA;
	  else if((qspi_dmode_i != 2'b00) && (qspi_fmode_i == 2'b01))
	    next_state  = RD_DA;
	  else 
	    next_state  = IDLE;
	end
	else
	  next_state   =  ADDR;
  end
  
  WR_DA: begin
    if(end_of_wrdat)
	  next_state  = IDLE;
	else
	  next_state  = WR_DA;
  end
  
  RD_DA: begin
    if(end_of_rddat)
	  next_state  = IDLE;
	else
	  next_state  = RD_DA;
  end
  
  default: begin
    next_state  = IDLE;
  end
  endcase
end

always@(posedge qspi_clk_i or negedge rst_n_i ) begin
  if(!rst_n_i) begin
    phase_cnt            <=   8'h00;
	qspi_cs_n_r          <=   1'b1;
	qspi_instruction_r   <=   8'h0;
	end_of_instr         <=   1'b0;
	trans_byte_cnt       <=   33'h0;
	qspi_address_r       <=   32'h0;
	end_of_addr          <=   1'b0;
	end_of_wrdat         <=   1'b0;
	end_of_rddat         <=   1'b0;
	qspi_data_r          <=   8'hff;
	wr_fifo_rdreq_o    <=  1'b1;
  end
  else begin
    case(next_state) 
	IDLE : begin
	  phase_cnt          <=   8'h00;
	  qspi_cs_n_r        <= 1'b1;
	  end_of_instr       <= 1'b0;
	  trans_byte_cnt     <= 33'h0;
	  end_of_addr          <=   1'b0;
	end
	START : begin
	  qspi_cs_n_r        <=  1'b0;
	  if(qspi_imode_i != 2'b00) begin // there is instruction phase
	    qspi_instruction_r <=  qspi_instruction_i;
	    phase_cnt          <=  phase_inst_std;
		trans_byte_cnt     <=  33'h0;
	  end
	  else if(qspi_admode_i != 2'b00) begin // there is no instruction phase but has address phase
	    phase_cnt          <=  phase_addr_std;
		trans_byte_cnt     <=  addr_byte_std;
	    case(qspi_adsize_i)
		2'b00: 	qspi_address_r[31:24]     <=  qspi_flash_addr_i[7:0]; // 8bit
		2'b01: 	qspi_address_r[31:16]     <=  qspi_flash_addr_i[15:0]; // 16bit
		2'b10: 	qspi_address_r[31:8]      <=  qspi_flash_addr_i[23:0]; // 24bit
		2'b11: 	qspi_address_r[31:0]      <=  qspi_flash_addr_i[31:0]; // 32bit
		endcase
	  end
	  else if(qspi_dmode_i != 2'b00) begin// no address phase but has data phase
	    phase_cnt         <=  phase_dat_std;
		trans_byte_cnt    <=  qspi_dlr_i;
	  end
	  
	  if((qspi_dmode_i != 2'b00) && (qspi_fmode_i == 2'b00))
	    wr_fifo_rdreq_o    <=  1'b0;
	  else
	    wr_fifo_rdreq_o    <=  1'b1;
		
	end
	INSTR : begin
	  wr_fifo_rdreq_o    <=  1'b1;
	  if(phase_cnt == 8'h0) begin
	    end_of_instr       <= 1'b1;
		if(qspi_admode_i != 2'b00) begin
		  phase_cnt  <=  phase_addr_std;
		  trans_byte_cnt     <=  addr_byte_std;
		end
		else if(qspi_dmode_i != 2'b00) begin
		  phase_cnt  <=  phase_dat_std;
		  trans_byte_cnt     <=  qspi_dlr_i;
		end
	  end
	  else begin
	    phase_cnt  <= phase_cnt - 1'b1;
	    end_of_instr <= 1'b0;
      end
	  case(qspi_imode_i) // qspi_instruction_r & qspi_d_o_r
	  2'b00 : begin
	    qspi_instruction_r  <=  8'h0;
	  end
	  2'b01: begin
	    qspi_instruction_r  <=  {qspi_instruction_r[6:0],1'b0};
	  end
	  2'b10: begin
	    qspi_instruction_r  <=  {qspi_instruction_r[5:0], 2'b00};
	  end
	  2'b11: begin
	    qspi_instruction_r  <=  {qspi_instruction_r[3:0], 4'b0000};
	  end
	  default: ;
	  endcase
    end
	
	ADDR :  begin
	  end_of_instr <= 1'b0;
	  wr_fifo_rdreq_o    <=  1'b1;
	  if(phase_cnt == 8'h0) begin
	    if(trans_byte_cnt == 33'h0) begin // end of ADDRESS phase
		  end_of_addr  <= 1'b1;
		  if(qspi_dmode_i != 2'b00) begin
		    phase_cnt  <=  phase_dat_std;
			trans_byte_cnt <= qspi_dlr_i;
		  end
		end
		else begin
		  phase_cnt  <=  phase_addr_std;
		  end_of_addr  <= 1'b0;
		  trans_byte_cnt <= trans_byte_cnt - 1'b1;
		end
	  end
	  else begin
	    phase_cnt  <= phase_cnt - 1'b1;
	  end
	  
	  case(qspi_admode_i) // 
	  2'b00 : begin
	    qspi_address_r  <=  8'h0;
	  end
	  2'b01: begin
	    qspi_address_r  <=  {qspi_address_r[30:0],1'b0};
	  end
	  2'b10: begin
	    qspi_address_r  <=  {qspi_address_r[29:0], 2'b00};
	  end
	  2'b11: begin
	    qspi_address_r  <=  {qspi_address_r[27:0], 4'b0000};
	  end
	  default: ;
	  endcase
	  
	end
	
	WR_DA: begin
	  end_of_instr         <= 1'b0;
	  end_of_addr          <= 1'b0;
	  if(phase_cnt == 8'h0) begin
	    if(trans_byte_cnt == 33'h0) begin // end of ADDRESS phase
		  end_of_wrdat  <= 1'b1;
		end
		else begin
		  phase_cnt  <=  phase_dat_std;
		  end_of_wrdat  <= 1'b0;
		  trans_byte_cnt <= trans_byte_cnt - 1'b1;
		end
	  end
	  else begin
	    phase_cnt            <= phase_cnt - 1'b1;
	  end
	  if(phase_cnt == phase_wrdat_std) begin
	    case(qspi_dmode_i)
	    2'b01: qspi_data_r        <= {wr_fifo_dat_i[6:0], 1'b0};
	    2'b10: qspi_data_r        <= {wr_fifo_dat_i[5:0], 2'b00};
	    2'b11: qspi_data_r        <= {wr_fifo_dat_i[3:0], 4'b0000};
		endcase
	  end
	  else begin
	    case(qspi_dmode_i)
	    2'b01: qspi_data_r        <= {qspi_data_r[6:0], 1'b0};
	    2'b10: qspi_data_r        <= {qspi_data_r[5:0], 2'b00};
	    2'b11: qspi_data_r        <= {qspi_data_r[3:0], 4'b0000}; // actually useless
		endcase
	  end

	end
	
	RD_DA: begin
	  end_of_instr <= 1'b0;
	  end_of_addr          <=   1'b0;
	  if(phase_cnt == 8'h0) begin
	    if(trans_byte_cnt == 33'h0) begin // end of DATA phase
		  end_of_rddat  <= 1'b1;
		end
		else begin
		  phase_cnt  <=  phase_dat_std;
		  end_of_rddat  <= 1'b0;
		  trans_byte_cnt <= trans_byte_cnt - 1'b1;
		end
	  end
	  else begin
	    phase_cnt  <= phase_cnt - 1'b1;
	  end
	  case(qspi_dmode_i)
	  2'b01: rd_fifo_dat_o <= {rd_fifo_dat_o[6:0], qspi_d_i[1]};
	  2'b10: rd_fifo_dat_o <= {rd_fifo_dat_o[5:0], qspi_d_i[1:0]};
	  2'b11: rd_fifo_dat_o <= {rd_fifo_dat_o[3:0], qspi_d_i[3:0]};
	  default: ;
	  endcase
	end
	
	default: ;
	endcase
  end
end

// for output enable
always@(*) begin
  qspi_d_o_r   = 4'hf;
  qspi_d_oe_r  = 4'h0;
  qspi_spi_clk_oe_r  = 1'b0;
  case(next_state)
  IDLE : begin
    qspi_d_o_r   = 4'hf;
	qspi_d_oe_r  = 4'h0;
	qspi_spi_clk_oe_r  = 1'b0;
  end
  
  START: begin
    qspi_d_o_r   = 4'hf;
	qspi_d_oe_r  = 4'h0;
	qspi_spi_clk_oe_r  = 1'b0;
  end

  INSTR: begin
    qspi_spi_clk_oe_r  = 1'b1;
    case(qspi_imode_i)
	2'b01: begin
	  qspi_d_o_r   = {3'b111, qspi_instruction_r[7]}; 
	  qspi_d_oe_r  = 4'hd;
	end
	2'b10: begin
	  qspi_d_o_r   = {2'b11, qspi_instruction_r[7:6]}; 
	  qspi_d_oe_r  = 4'hf;
	end
	2'b11: begin
	  qspi_d_o_r   = {qspi_instruction_r[7:4]}; 
	  qspi_d_oe_r  = 4'hf;
	end
	default: begin
	  qspi_d_o_r   = 4'hf;
	  qspi_d_oe_r  = 4'h0;
	end
	endcase
  end
  
  ADDR: begin
    qspi_spi_clk_oe_r  = 1'b1;
	case(qspi_admode_i)
	2'b01: begin
	  qspi_d_o_r = {3'b111, qspi_address_r[31]}; // one line
	end
	2'b10: begin
	  qspi_d_o_r = {2'b11, qspi_address_r[31:30]}; // two line
	end
	2'b11: begin
	  qspi_d_o_r = {qspi_address_r[31:28]}; // 4 line
	end
	endcase
  end
  
  RD_DA: begin
    qspi_spi_clk_oe_r  = 1'b1;
  end
  
  WR_DA: begin
    qspi_spi_clk_oe_r  = 1'b1;
	if(phase_cnt == phase_wrdat_std) begin // the beginning of one byte
	  case(qspi_dmode_i)
	  2'b01: qspi_d_o_r  = {3'b111, wr_fifo_dat_i[7]  };
	  2'b10: qspi_d_o_r  = {2'b11,  wr_fifo_dat_i[7:6]};
	  2'b11: qspi_d_o_r  = {wr_fifo_dat_i[7:4]};
	  endcase
	end
	else begin
	  case(qspi_dmode_i)
	  2'b01: qspi_d_o_r  = {3'b111, qspi_data_r[7]  };
	  2'b10: qspi_d_o_r  = {2'b11,  qspi_data_r[7:6]};
	  2'b11: qspi_d_o_r  = {qspi_data_r[7:4]};
	  endcase
	end
	  
  end
  
  default: begin
    qspi_d_o_r   = 4'hf;
	qspi_d_oe_r  = 4'h0;
	qspi_spi_clk_oe_r  = 1'b0;
  end
  endcase
  
end

// for counter std
always@(*) begin 
  addr_byte_std = 33'h0;
  
  phase_inst_std = 8'h0;
  phase_addr_std = 8'h0;
  phase_dat_std  = 8'h0;

  case(qspi_adsize_i)
    2'b00:  addr_byte_std  = 33'h0;
    2'b01:  addr_byte_std  = 33'h1;
    2'b10:  addr_byte_std  = 33'h2;
    2'b11:  addr_byte_std  = 33'h3;
  endcase
  
  case(qspi_imode_i)
  2'b00: phase_inst_std   =   8'h0;
  2'b01: phase_inst_std   =   8'h07;
  2'b10: phase_inst_std   =   8'h03;
  2'b11: phase_inst_std   =   8'h01;
  endcase
  
  case(qspi_dmode_i)
  2'b00: phase_dat_std   =   8'h00; // no data phase
  2'b01: phase_dat_std   =   8'h07;
  2'b10: phase_dat_std   =   8'h03;
  2'b11: phase_dat_std   =   8'h01;
  endcase
  
  case(qspi_admode_i)
	2'b01:   phase_addr_std   =   8'h07; //  Address phase on one line
    2'b10:   phase_addr_std   =   8'h03; //  Address phase on two lines
    2'b11:   phase_addr_std   =   8'h01; //  Address phase on four lines
  endcase
  
end

always@(*) begin
  if(state == IDLE)
    if(qspi_indi_op_st_i)
	  qspi_bsy_o = 1'b1;
	else 
	  qspi_bsy_o = 1'b0;
  else 
    qspi_bsy_o = 1'b1;
end

always@(negedge qspi_clk_i or negedge rst_n_i ) begin
  if(!rst_n_i) begin
    qspi_cs_n_r1  <= 1'b1;
	qspi_d_o      <= 4'hf;
	qspi_d_oe     <= 4'h0;
  end
  else begin
    qspi_cs_n_r1 <= qspi_cs_n_r;
	qspi_d_o     <= qspi_d_o_r;
	qspi_d_oe    <= qspi_d_oe_r;
  end
end

always@(negedge qspi_clk_i or negedge rst_n_i ) begin
  if(!rst_n_i) begin
    qspi_spi_clk_oe  <= 1'b1;
  end
  else begin
    qspi_spi_clk_oe   <= qspi_spi_clk_oe_r;
  end
end

assign rd_fifo_clr_o = ((next_state == START) && (qspi_fmode_i == 2'b01))?1'b0:1'b1;
assign rd_fifo_wrreq_o = ((state == RD_DA) && (phase_cnt == 8'h07))?1'b0:1'b1;

assign qspi_clk_o  = qspi_spi_clk_oe?qspi_clk_i:1'b0;
assign qspi_cs_n_o = qspi_cs_n_r && qspi_cs_n_r1;
endmodule 