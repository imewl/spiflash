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
//  Filename:   qspi_ctrl_reg
//  Author:          
//  Date:            
//
//  Project:         
//  Descriptions: AHB Interface register for Quad-SPI controller.
//---------------------------------------------------------------------
module qspi_ctrl_reg (
                // AHB Slave Interface
				ahb_rst_i,
                ahb_clk_i,
                qspi_addr_i,
                qspi_val_i,
				qspi_rd_i,
                qspi_ben_i,
                qspi_wdata_i,
                qspi_rdata_o,
				qspi_ack_o,
				
				qspi_busy_i,
				qspi_indi_op_st_o,
				
				// control register
				qspi_prescal_o,
				qspi_dlr_o,
				qspi_fmode_o,
				qspi_dmode_o,
				qspi_adsize_o,
				qspi_admode_o,
				qspi_imode_o,
				qspi_instruction_o,
				qspi_address_o,
				
				// FIFO
				wr_fifo_clr_o,
				wr_fifo_wrreq_o,
				wr_fifo_dat_o,
				wr_fifo_full_i,
				
				rd_fifo_rdreq_o,
                rdfifo_rdata_i,
				rdfifo_empt_i,
				
				qspi_cs_n_i
  );
//--------------------------------
//  Ports
//--------------------------------
input           ahb_rst_i;
input           ahb_clk_i;

input [31:0]    qspi_addr_i;
input           qspi_val_i;
input           qspi_rd_i;
input [3:0]     qspi_ben_i;
input [31:0]    qspi_wdata_i;
output[31:0]    qspi_rdata_o;
output          qspi_ack_o;
input           qspi_busy_i;
output          qspi_indi_op_st_o;

output [7:0]    qspi_prescal_o;
output [31:0]   qspi_dlr_o;
output [1:0]    qspi_fmode_o;
output [1:0]    qspi_dmode_o;
output [1:0]    qspi_adsize_o;
output [1:0]    qspi_admode_o;
output [1:0]    qspi_imode_o;
output [7:0]    qspi_instruction_o;
output [31:0]   qspi_address_o;

output        wr_fifo_clr_o;
output        wr_fifo_wrreq_o;
output [7:0]  wr_fifo_dat_o;
input         wr_fifo_full_i;

output        rd_fifo_rdreq_o;
input [7:0]   rdfifo_rdata_i;
input         rdfifo_empt_i;

input         qspi_cs_n_i;
//--------------------------------
//  Wires and REGs
//--------------------------------
reg            qspi_ack_o;
wire [31:0]    qspi_ccr;
wire           wr_qspi_cr;
wire           wr_qspi_dlr;
wire           wr_qspi_ccr;
wire           wr_qspi_ar;
wire           wr_qspi_dr;

wire           rd_qspi_ccr;
wire           rd_qspi_dr;
reg            qspi_indi_op_st_o;
reg            rd_fifo_rdreq_o;
reg            rd_fifo_rdreq_reg;
reg            wr_fifo_wrreq_o;
reg            wr_qspi_dr_reg;

parameter      IDLE        = 4'h0, 
               RD_DAT      = 4'h1,
               RD_DAT_ACK  = 4'h2,
			   WR_DAT      = 4'h5,
			   WR_DAT_ACK  = 4'h6;

reg [31:0]     qspi_rdata_o;
reg [3:0]      fifo_op_state;
reg [3:0]      fifo_op_cnt;
reg [31:0]     rd_dat_r;
reg [31:0]     wr_dat_r;

reg [7:0]      qspi_prescal_o, qspi_prescal_r;// 0x0000, bit [31:24], clock prescaler
reg [31:0]     qspi_dlr_o; // 0x0010, bit[31:0], data length register
reg [1:0]      qspi_fmode_o, qspi_fmode_r;
                                   // 0x0014, bit[27:26]
                                   // 00: Indirect write mode
                                   // 01: Indirect read mode
                                   // 10: Reserved
                                   // 11: Memory-mapped mode
                                   // be written only when BUSY = 1'b0
reg [1:0]      qspi_dmode_o, qspi_dmode_r;
                                   // 0x0014, bit[25:24]
                                   // 00: No Data
                                   // 01: Data on one line
                                   // 10: Data on two lines
                                   // 11: Data on three lines
                                   // be written only when BUSY = 1'b0
reg [1:0]      qspi_adsize_o, qspi_adsize_r;
                                   // 0x0014, bit[13:12]
                                   // 00: 8-bit address
                                   // 01: 16-bit address
                                   // 10: 24-bit address
                                   // 11: 32-bit address
                                   // be written only when BUSY = 1'b0
reg [1:0]      qspi_admode_o, qspi_admode_r;
                                   // 0x0014, bit[11:10]
                                   // 00: No Address phase
                                   // 01: Address phase on one line
                                   // 10: Address phase on two lines
                                   // 11: Address phase on four lines
                                   // be written only when BUSY = 1'b0
reg [1:0]      qspi_imode_o, qspi_imode_r;  
                                   // 0x0014, bit[9:8]
                                   // 00: No instruction
                                   // 01: Instuction on one line
                                   // 10: Instuction on two lines
                                   // 11: Instuction on four lines
                                   // be written only when BUSY = 1'b0
reg[7:0]       qspi_instruction_o, qspi_instruction_r;
                                   // 0x0014, bit[7:0]
                                   // Store the INSTRUCTION to be send to FLASH
                                   // be written only when BUSY = 1'b0
								   // write to this reg may start a new SPI trans
reg [31:0]     qspi_address_o, qspi_address_r; // 0x0018, bit [31:0], address register

// 0x0020,  data register

assign      wr_qspi_cr  = qspi_val_i && (!qspi_rd_i) && (qspi_addr_i[15:0] == 16'h0000);
assign      wr_qspi_dlr = qspi_val_i && (!qspi_rd_i) && (qspi_addr_i[15:0] == 16'h0010);
assign      wr_qspi_ccr = qspi_val_i && (!qspi_rd_i) && (qspi_addr_i[15:0] == 16'h0014);
assign      wr_qspi_ar  = qspi_val_i && (!qspi_rd_i) && (qspi_addr_i[15:0] == 16'h0018);
assign      wr_qspi_dr  = qspi_val_i && (!qspi_rd_i) && (qspi_addr_i[15:0] == 16'h0020);

assign      rd_qspi_ccr = qspi_val_i && (qspi_rd_i)  && (qspi_addr_i[15:0] == 16'h0014);
assign      rd_qspi_dr  = qspi_val_i && (qspi_rd_i)  && (qspi_addr_i[15:0] == 16'h0020);

always @ (posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    qspi_dlr_o    <=  32'h0;
  end
  else begin
    if(wr_qspi_dlr && (!qspi_busy_i)) begin
	  if(qspi_ben_i[3]) begin
	    qspi_dlr_o[31:24] <=  qspi_wdata_i[31:24];
	  end
	  if(qspi_ben_i[2]) begin
	    qspi_dlr_o[23:16] <=  qspi_wdata_i[23:16];
	  end
	  if(qspi_ben_i[1]) begin
	    qspi_dlr_o[15:8] <=  qspi_wdata_i[15:8];
	  end
	  if(qspi_ben_i[0]) begin
	    qspi_dlr_o[7:0] <=  qspi_wdata_i[7:0];
	  end
	end
  end
end

always @ (posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    qspi_prescal_r    <=  8'h0;
  end
  else begin
    if(wr_qspi_cr && (!qspi_busy_i)) begin
	  if(qspi_ben_i[3]) begin
	    qspi_prescal_r <=  qspi_wdata_i[31:24];
	  end
	end
  end
end

always @ (posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    qspi_prescal_r    <=  8'h0;
  end
  else begin
    if(wr_qspi_cr && (!qspi_busy_i)) begin
	  if(qspi_ben_i[3]) begin
	    qspi_prescal_r <=  qspi_wdata_i[31:24];
	  end
	end
  end
end
			   
always @ (posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    qspi_fmode_r          <=  2'h0;
    qspi_dmode_r          <=  2'h0;
	qspi_adsize_r         <=  2'h0;
    qspi_admode_r         <=  2'h0;
    qspi_imode_r          <=  2'h0;
    qspi_instruction_r    <=  8'h0;
  end
  else begin
    if(wr_qspi_ccr && (!qspi_busy_i)) begin
	  if(qspi_ben_i[3]) begin
	    qspi_fmode_r       <=   qspi_wdata_i[27:26];
	    qspi_dmode_r       <=   qspi_wdata_i[25:24];
	  end
	  if(qspi_ben_i[1]) begin
	    qspi_adsize_r       <=  qspi_wdata_i[13:12];
	    qspi_admode_r       <=  qspi_wdata_i[11:10];
	    qspi_imode_r        <=  qspi_wdata_i[9:8];
	  end
	  if(qspi_ben_i[0]) begin
	    qspi_instruction_r  <=  qspi_wdata_i[7:0];
	  end
	end
  end
end

always @ (posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
	qspi_address_r        <=  32'h0;
  end
  else begin
    if(wr_qspi_ar && (!qspi_busy_i)) begin
	  if(qspi_ben_i[3]) begin
	    qspi_address_r[31:24]   <=  qspi_wdata_i[31:24];
	  end
	  if(qspi_ben_i[2]) begin
	    qspi_address_r[23:16]   <=  qspi_wdata_i[23:16];
	  end
	  if(qspi_ben_i[1]) begin
	    qspi_address_r[15:8]   <=  qspi_wdata_i[15:8];
	  end
	  if(qspi_ben_i[0]) begin
	    qspi_address_r[7:0]   <=  qspi_wdata_i[7:0];
	  end
	end
  end
end

always@(*) begin

  if(wr_qspi_ar && (!qspi_busy_i) && qspi_ben_i[0])
    qspi_address_o[7:0]  = qspi_wdata_i[7:0];
  else
    qspi_address_o  = qspi_address_r;
	
  if(wr_qspi_ar && (!qspi_busy_i) && qspi_ben_i[1])
    qspi_address_o[15:8]  = qspi_wdata_i[15:8];
  else
    qspi_address_o  = qspi_address_r;
  
  if(wr_qspi_ar && (!qspi_busy_i) && qspi_ben_i[2])
    qspi_address_o[23:16]  = qspi_wdata_i[23:16];
  else
    qspi_address_o  = qspi_address_r;
  
  if(wr_qspi_ar && (!qspi_busy_i) && qspi_ben_i[3])
    qspi_address_o[31:24]  = qspi_wdata_i[31:24];
  else
    qspi_address_o  = qspi_address_r;

  if(wr_qspi_cr && (!qspi_busy_i) && qspi_ben_i[3]) begin
    qspi_prescal_o  = qspi_wdata_i[31:24];
  end
  else begin
    qspi_prescal_o = qspi_prescal_r;
  end

  if(wr_qspi_ccr && (!qspi_busy_i) && qspi_ben_i[3]) begin
    qspi_fmode_o  = qspi_wdata_i[27:26];
	qspi_dmode_o  = qspi_wdata_i[25:24];
  end
  else begin
    qspi_fmode_o  = qspi_fmode_r;
    qspi_dmode_o  = qspi_dmode_r;
  end
  
  if(wr_qspi_ccr && (!qspi_busy_i) && qspi_ben_i[1]) begin
    qspi_adsize_o = qspi_wdata_i[13:12];
    qspi_admode_o = qspi_wdata_i[11:10];
	qspi_imode_o  = qspi_wdata_i[9:8];
  end
  else begin
    qspi_adsize_o = qspi_adsize_r;
    qspi_admode_o = qspi_admode_r;
    qspi_imode_o  = qspi_imode_r;
  end
	
  if(wr_qspi_ccr && (!qspi_busy_i) && qspi_ben_i[0])
    qspi_instruction_o  = qspi_wdata_i[7:0];
  else
    qspi_instruction_o  = qspi_instruction_r;
	
end				


always@(*) begin
  if(rd_qspi_ccr) begin
    qspi_rdata_o = qspi_ccr;
  end
  else if(rd_qspi_dr && qspi_ack_o) begin
    qspi_rdata_o = rd_dat_r;
  end
  else begin
    qspi_rdata_o = 32'h0;
  end
end

assign qspi_ccr  = {22'h0,qspi_imode_o, qspi_instruction_o};

//-----------------------------------------------------
// start a indirect read/write operation
//-----------------------------------------------------
always @ (posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    qspi_indi_op_st_o  <= 1'b0;
  end
  else if(wr_qspi_ccr && (!qspi_busy_i) && qspi_ben_i[0] && (qspi_imode_o != 2'b00) &&      // a write to INSTRUCTION
  (qspi_admode_o == 2'b00) && ((qspi_fmode_o == 2'b01) || (qspi_dmode_o == 2'b00))  ) begin // no address & no data
    qspi_indi_op_st_o  <= 1'b1;
  end
  else if(wr_qspi_ar && (!qspi_busy_i) && (qspi_ben_i != 4'h0) && (qspi_admode_o != 2'b00) &&      // a write to ADDRESS
  ((qspi_fmode_o == 2'b01) || (qspi_dmode_o == 2'b00))  ) begin                                    // no data
    qspi_indi_op_st_o  <= 1'b1;
  end
  else if(wr_qspi_dr && (!qspi_busy_i) && (qspi_ben_i != 4'h0) && (qspi_admode_o != 2'b00) &&      // a write to DATA
  ((qspi_fmode_o == 2'b00) || (qspi_dmode_o != 2'b00))  ) begin                                    // need address and data
    qspi_indi_op_st_o  <= 1'b1;
  end
  else begin
    qspi_indi_op_st_o  <= 1'b0;
  end
end

//-----------------------------------------------------
// for RD FIFO
//-----------------------------------------------------

always @ (posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    fifo_op_state <= IDLE;
	fifo_op_cnt   <= 4'h0;
  end
  else begin
    case(fifo_op_state)
	IDLE: begin
	  fifo_op_cnt   <= 4'h0;
	  if(rd_qspi_dr && (qspi_fmode_o == 2'b01)) begin
	    fifo_op_state <= RD_DAT;
	  end
	  else if(wr_qspi_dr && (qspi_fmode_o == 2'b00)) begin
	    fifo_op_state <= WR_DAT;
	  end
	end

	RD_DAT: begin
	  case(qspi_ben_i)
	  4'hf: begin
	    if(fifo_op_cnt == 4'h4)
		  fifo_op_state  <= RD_DAT_ACK;
		else if(rdfifo_empt_i) begin
		  fifo_op_cnt  <= fifo_op_cnt + 1'b1;
		end
		else begin
		  if(qspi_cs_n_i) begin
		    fifo_op_state  <= RD_DAT_ACK;
		  end
		end
	  end
	  4'h3: begin
	    fifo_op_cnt  <= fifo_op_cnt + 1'b1;
		if(fifo_op_cnt == 4'h2)
		  fifo_op_state  <= RD_DAT_ACK;
	  end
	  4'h1: begin
	    fifo_op_cnt      <= fifo_op_cnt + 1'b1;
		if(fifo_op_cnt == 4'h1)
		  fifo_op_state  <= RD_DAT_ACK;
	  end
	  4'h0: begin
	    fifo_op_state  <= RD_DAT_ACK;
	  end
	  endcase
	end
	
	RD_DAT_ACK: begin
	  fifo_op_cnt      <= 4'h0;
      fifo_op_state    <= IDLE;
	end
	
	WR_DAT: begin
	  case(qspi_ben_i)
	  4'hf: begin
	    if(fifo_op_cnt == 4'h4)
		  fifo_op_state  <= WR_DAT_ACK;
		else if(wr_fifo_full_i) begin
		  fifo_op_cnt  <= fifo_op_cnt + 1'b1;
		end
      end
	  4'h3: begin
	    if(fifo_op_cnt == 4'h2)
		  fifo_op_state  <= WR_DAT_ACK;
		else if(wr_fifo_full_i) begin
		  fifo_op_cnt  <= fifo_op_cnt + 1'b1;
		end
      end
	  4'h1: begin
	    if(fifo_op_cnt == 4'h1)
		  fifo_op_state  <= WR_DAT_ACK;
		else if(wr_fifo_full_i) begin
		  fifo_op_cnt  <= fifo_op_cnt + 1'b1;
		end
	  end
	  4'h0: begin
	    fifo_op_state  <= WR_DAT_ACK;
	  end
	  endcase
	end
	
	WR_DAT_ACK: begin
	  fifo_op_cnt      <= 4'h0;
      fifo_op_state    <= IDLE;
	end
	
	endcase
  end
end

always@(*) begin
  rd_fifo_rdreq_o  =  1'b1;
  wr_fifo_wrreq_o  =  1'b1;
  case(fifo_op_state)
  IDLE: begin
    if(rd_qspi_dr && rdfifo_empt_i ) begin
	  rd_fifo_rdreq_o  =  1'b0;
	end
	
  end
  
  RD_DAT: begin
    case(qspi_ben_i)
	4'hf: begin
	  if((fifo_op_cnt != 4'h4) && rdfifo_empt_i) begin
	    rd_fifo_rdreq_o  =  1'b0;
	  end
	end
	4'h3: begin
	  if((fifo_op_cnt != 4'h2) && rdfifo_empt_i) begin
	    rd_fifo_rdreq_o  =  1'b0;
	  end
  	end
	4'h1: begin
	  if((fifo_op_cnt != 4'h1) && rdfifo_empt_i) begin
	    rd_fifo_rdreq_o  =  1'b0;
	  end
	end
	endcase
  end
  
  WR_DAT: begin
    case(qspi_ben_i)
	4'hf: begin
	  if((fifo_op_cnt != 4'h4) && wr_fifo_full_i) begin
	    wr_fifo_wrreq_o  =  1'b0;
	  end
	end
	4'h3: begin
	  if((fifo_op_cnt != 4'h2) && wr_fifo_full_i) begin
	    wr_fifo_wrreq_o  =  1'b0;
	  end
  	end
	4'h1: begin
	  if((fifo_op_cnt != 4'h1) && wr_fifo_full_i) begin
	    wr_fifo_wrreq_o  =  1'b0;
	  end
	end
	endcase
  end
  
  endcase
end

always @ (posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    rd_fifo_rdreq_reg  <= 1'b1;
	rd_dat_r           <= 32'h0;
	wr_dat_r           <= 32'h0;
	wr_qspi_dr_reg     <= 1'b0;
  end
  else begin
    rd_fifo_rdreq_reg  <= rd_fifo_rdreq_o;
	wr_qspi_dr_reg     <= wr_qspi_dr;
	if(!rd_fifo_rdreq_reg) begin
	  rd_dat_r         <= {rd_dat_r[23:0], rdfifo_rdata_i};
	end
	if(wr_qspi_dr && (!wr_qspi_dr_reg))
	  wr_dat_r         <= qspi_wdata_i;
	else if(!wr_fifo_wrreq_o)
	  wr_dat_r         <= {8'h00, wr_dat_r[31:8]};
  end
end
assign   wr_fifo_dat_o = wr_dat_r[7:0];
//-----------------------------------------------------
// for qspi_ack_o
//-----------------------------------------------------
always@(*) begin
	if (!qspi_val_i) begin 
	  qspi_ack_o = 1'b0; 
    end
	else if(rd_qspi_dr)	 begin 
	  if(fifo_op_state == RD_DAT_ACK)
	    qspi_ack_o = 1'b1;  
	  else
	    qspi_ack_o = 1'b0; 
	end
	else if(wr_qspi_dr) begin
	  if(fifo_op_state == WR_DAT_ACK)
	    qspi_ack_o = 1'b1;  
	  else
	    qspi_ack_o = 1'b0; 
	end
	else begin 
	  qspi_ack_o = 1'b1; 
    end
end

assign   wr_fifo_clr_o  =  1'b1;

endmodule
