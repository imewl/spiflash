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
//  Filename:   qspi_ahb_slave_itf     
//  Author:          
//  Date:            
//
//  Project:         
//  Descriptions: AHB Interface block for Quad-SPI controller.
//---------------------------------------------------------------------

module qspi_ahb_slave_itf (

  // AHB interface
  hclk_i,
  hresetn_i,

  haddr_i,
  htrans_i,
  hwdata_i,
  hwrite_i,
  hsize_i,
  hburst_i,
  hsel_i,
  hready_i,

  qspi_hready_o,
  qspi_hresp_o,
  qspi_hrdata_o,

  qspi_select_o,

  // memory array Interface 
  qspi_val_r_o,
  qspi_addr_r_o,
  qspi_rd_r_o, 
  qspi_ben_r_o,
  qspi_wdata_o,
  qspi_rdata_i,
  qspi_ack_i,
  

  qspi_bsy_i

);

input         hclk_i;         // AHB Clock
input         hresetn_i;      // AHB Reset

input  [31:0] haddr_i;        // AHB 32 bit address
input  [1:0]  htrans_i;       // AHB transfer type
input  [31:0] hwdata_i;       // AHB 32 bit write data

input         hwrite_i;       // AHB Read/Write signal
input  [2:0]  hsize_i;        // AHB size of data transfer
   
input  [2:0]  hburst_i;       // AHB burst length

input         hsel_i;         // AHB slave select
input         hready_i;       // AHB slave ready from default slave, set 1'b1 if there is no default slave

output        qspi_hready_o;   // AHB HREADY asserted by this target, psm is for PSRAM
output [1:0]  qspi_hresp_o;    // AHB slave response
output [31:0] qspi_hrdata_o;   // AHB slave read data

output        qspi_select_o;   // Active HI signal when the PSRAM access is active

// CSR interface
output        qspi_val_r_o;
output [31:0] qspi_addr_r_o;
output        qspi_rd_r_o; 
output [3:0]  qspi_ben_r_o;
output [31:0] qspi_wdata_o;
input  [31:0] qspi_rdata_i;    // This name need to be changed depending on
                              // who is driving it
input         qspi_ack_i;      // This name needs to be changed depending on
                              // who is driving it

input         qspi_bsy_i;
//###START OF DECLARATIONS ########################################

//----------------------------
// Declarations for IOs

wire        hready_i;

reg         qspi_val_r_o;
reg  [31:0] qspi_addr_r_o;
reg         qspi_rd_r_o; 
reg  [3:0]  qspi_ben_r_o;
wire        qspi_select_o;

reg         qspi_val_c;
reg  [31:0] qspi_addr_c;
reg         qspi_rd_c; 
reg  [3:0]  qspi_ben_c;
reg         qspi_select_c;

wire        tx_wrcfrm_zero_full;
reg         tx_wrcfrm_zero_full_d;

//----------------------------

//----------------------------
// Generic defines

parameter LO = 1'b0;
parameter HI = 1'b1;

//----------------------------

//----------------------------
// Internal declarations

parameter IDLE  = 2'b00;
parameter BUSY  = 2'b01;
parameter NSEQ  = 2'b10;
parameter SEQ   = 2'b11;

parameter SINGLE = 3'b000;
parameter INCR   = 3'b001;
parameter WRAP4  = 3'b010;
parameter INCR4  = 3'b011;
parameter WRAP8  = 3'b100;
parameter INCR8  = 3'b101;
parameter WRAP16 = 3'b110;
parameter INCR16 = 3'b111;

parameter BYTE  = 3'b000;
parameter WORD  = 3'b001;
parameter DWORD = 3'b010;

parameter OKAY  = 2'b00;
parameter ERROR = 2'b01;
parameter RETRY = 2'b10;
parameter SPLIT = 2'b11;

parameter ICTRL_READY = 2'b00;
parameter ICTRL_DATA  = 2'b01;
parameter ICTRL_ERROR = 2'b10;

reg [1:0]  ictrl_state;         // Interface controller state
reg [1:0]  ictrl_state_c;

reg        hready_c;            // Shadow signal for I/O HREADY signal
reg [1:0]  hresp_c;             // Shadow signal for I/O HRESP signal
reg [31:0] hrdata_c;            // Shadow signal for I/O HRDATA signal

reg        hready_r;            // Shadow register for I/O HREADY signal
reg [1:0]  hresp_r;             // Shadow register for I/O HRESP signal
reg [31:0] hrdata_r;            // Shadow register for I/O HRDATA signal
reg        qspi_select_r;

//----------------------------

//###END OF DECLARATIONS ########################################

assign qspi_hready_o = hready_c;
assign qspi_hrdata_o = hrdata_c;
assign qspi_hresp_o  = hresp_c;
// Since hready, hrdata, hresp will be combinatorial, so must qspi_select
assign  qspi_select_o = qspi_select_c;

assign qspi_wdata_o = hwdata_i;

//assign tx_wrcfrm_zero_full = haddr_i[11:9] == 3'b000 && haddr_i[4:0] == 5'h1c  && vld_access; // can be used for illegal address
assign tx_wrcfrm_zero_full = 1'b0; 

always @ (posedge hclk_i or negedge hresetn_i) begin // STAR STS0167661
  if (~hresetn_i) begin
    hready_r     <= HI;
    hresp_r      <= 2'b00;
    hrdata_r     <= 32'h0000_0000;
    qspi_select_r <= LO;
    qspi_val_r_o  <= LO;
    qspi_rd_r_o   <= LO;
    qspi_addr_r_o <= 32'h0000_0000;
    qspi_ben_r_o  <= 4'b0000;
    ictrl_state  <= ICTRL_READY;
  end
  else begin
    hready_r     <= hready_c;
    hresp_r      <= hresp_c;
    hrdata_r     <= hrdata_c;
    qspi_select_r <= qspi_select_c;
    qspi_val_r_o  <= qspi_val_c;
    qspi_rd_r_o   <= qspi_rd_c;
    qspi_addr_r_o <= qspi_addr_c;
    qspi_ben_r_o  <= qspi_ben_c;
    ictrl_state  <= ictrl_state_c;
  end
end

//-----------------------------------------------
// State machine to generate Register access  --------
// and to generate HREADY signals.            --------
//-----------------------------------------------

always @ (ictrl_state or hsel_i or htrans_i or hready_i or hburst_i or
          hsize_i or hwrite_i or haddr_i or qspi_ack_i or qspi_rdata_i or
          qspi_val_r_o or qspi_rd_r_o or qspi_addr_r_o or qspi_ben_r_o or
          qspi_select_r or hrdata_r or hready_r or hresp_r or 
          tx_wrcfrm_zero_full or tx_wrcfrm_zero_full_d or qspi_bsy_i
) begin

  // Parallel case directive is used as all the case options are
  // mutally exclusive.
  case (ictrl_state) // synopsys parallel_case

    // ICTRL_READY : Ready state. Wait in this state to get a command from 
    //               the AHB master
    ICTRL_READY : begin

//  could get return_retry pulse on same cycle as first cycle of qspi_ack_i 
//  qspi_ack_i transitions state machine from DATA to IDLE  state

      if(tx_wrcfrm_zero_full_d) begin
        hready_c      = HI;
        hresp_c       = ERROR;
        ictrl_state_c = ictrl_state;
        qspi_addr_c    = qspi_addr_r_o;
        qspi_ben_c     = qspi_ben_r_o;
        qspi_rd_c      = qspi_rd_r_o;
        qspi_select_c  = qspi_select_r;
        qspi_val_c     = qspi_val_r_o;
        hrdata_c      = hrdata_r;
      end

      // Sample the Control signals only when HREADY is HI
      else if (hsel_i) begin

        // New transaction
        if ( (htrans_i == NSEQ ) & hready_i) begin

          hready_c     = HI;
          qspi_select_c = HI;

          // CSR access is always assumed to be single and a valid HSIZE
          //if ((hburst_i == SINGLE | hburst_i == INCR) & 
		  //(hsize_i == BYTE | hsize_i == WORD | hsize_i == DWORD) & (~qspi_bsy_i))   begin
		  if ((hburst_i == SINGLE | hburst_i == INCR) & 
		  (hsize_i == BYTE | hsize_i == WORD | hsize_i == DWORD) )   begin
            if (tx_wrcfrm_zero_full)
              hresp_c    = ERROR;
            else
              hresp_c    = OKAY;

            qspi_val_c  = HI;
	    
            qspi_rd_c   = ~hwrite_i;
            qspi_addr_c = {haddr_i [31:2], 2'b00};

            // Generation of VC byte enables from the AHB address and HSIZE

            // Parallel case directive is used as all the case options are 
            // mutally exclusive.
            case (hsize_i) // synopsys parallel_case

              BYTE : begin
                case (haddr_i [1:0])
                  2'b00 : qspi_ben_c [3:0] = 4'b0001;
                  2'b01 : qspi_ben_c [3:0] = 4'b0010;
                  2'b10 : qspi_ben_c [3:0] = 4'b0100;
                  2'b11 : qspi_ben_c [3:0] = 4'b1000;
                endcase
              end

              WORD : begin
                case (haddr_i [1])
                  1'b0 : qspi_ben_c [3:0] = 4'b0011;
                  1'b1 : qspi_ben_c [3:0] = 4'b1100;
                endcase
              end

              default : begin
                qspi_ben_c [3:0] = 4'b1111;
              end

            endcase

            ictrl_state_c = ICTRL_DATA;

          end
          // If this is a non-single transaction, assert an ERROR response 
          // on AHB
          else begin
            qspi_val_c = qspi_val_r_o;
            qspi_rd_c = qspi_rd_r_o;

            hresp_c       = ERROR;
            ictrl_state_c = ICTRL_ERROR;
            qspi_addr_c = qspi_addr_r_o;
            qspi_ben_c = qspi_ben_r_o;
          end

        end
        // Starting the transfer with a SEQ or BUSY or an INCR with more
        // than one data phase, this is illegal
        else if ((htrans_i == SEQ | htrans_i == BUSY) & hready_i) begin
          hready_c      = LO;
          hresp_c       = ERROR;
          ictrl_state_c = ICTRL_ERROR;

          qspi_val_c = qspi_val_r_o;
          qspi_rd_c = qspi_rd_r_o;
          qspi_select_c = qspi_select_r;
          qspi_addr_c = qspi_addr_r_o;
          qspi_ben_c = qspi_ben_r_o;
        end
        // Default Slave
        else begin
          if (hready_i)
            qspi_select_c = HI;
          else
            qspi_select_c = LO;

          hresp_c    = OKAY;
          hready_c   = HI;
          qspi_val_c  = LO;

          ictrl_state_c = ictrl_state;
          qspi_rd_c = qspi_rd_r_o;
          qspi_addr_c = qspi_addr_r_o;
          qspi_ben_c = qspi_ben_r_o;
        end

        hrdata_c = hrdata_r;

      end
      else begin // hsel_i = 1'b0
        hresp_c    = OKAY;
        qspi_val_c  = LO;
        hready_c   = HI;
        qspi_select_c = LO;

        hrdata_c = hrdata_r;
        ictrl_state_c = ictrl_state;
        qspi_rd_c = qspi_rd_r_o;
        qspi_addr_c = qspi_addr_r_o;
        qspi_ben_c = qspi_ben_r_o;
      end
    end

    // ICTRL_DATA : Data state. Wait in this state to get an ACK from the
    //              CSR to assert HREADY on AHB
   
	ICTRL_DATA : begin

      if( tx_wrcfrm_zero_full || (!qspi_ack_i)) // The "|| (!qspi_ack_i)" part was added by WangLei
        hready_c  = LO; 
      else 
        hready_c  = HI; 
      
	  if (hsel_i & (htrans_i == SEQ) & hready_i) begin
		if (qspi_ack_i) begin
           hrdata_c  = qspi_rdata_i;
           qspi_val_c = HI;
        end
		else begin
		   hrdata_c = hrdata_r;
           qspi_val_c = qspi_val_r_o;
		end
		ictrl_state_c = ICTRL_DATA;
	  end
      else begin
		if (qspi_ack_i) begin
           hrdata_c  = qspi_rdata_i;
           qspi_val_c = LO;
           ictrl_state_c = ICTRL_READY;
        end
		else begin 
           hrdata_c = hrdata_r;
           qspi_val_c = qspi_val_r_o;
           ictrl_state_c = ictrl_state;
		end
      end
     
      if (tx_wrcfrm_zero_full_d || tx_wrcfrm_zero_full) 
        hresp_c = ERROR;
      else
        hresp_c = OKAY;
	
	if (htrans_i == SEQ )
	  begin 
		qspi_addr_c = {haddr_i [31:2], 2'b00};
		case (hsize_i) // synopsys parallel_case

              BYTE : begin
                case (haddr_i [1:0])
                  2'b00 : qspi_ben_c [3:0] = 4'b0001;
                  2'b01 : qspi_ben_c [3:0] = 4'b0010;
                  2'b10 : qspi_ben_c [3:0] = 4'b0100;
                  2'b11 : qspi_ben_c [3:0] = 4'b1000;
                endcase
              end

              WORD : begin
                case (haddr_i [1])
                  1'b0 : qspi_ben_c [3:0] = 4'b0011;
                  1'b1 : qspi_ben_c [3:0] = 4'b1100;
                endcase
              end

              default : begin
                qspi_ben_c [3:0] = 4'b1111;
              end

        endcase
	  end
	else
	  begin
		qspi_addr_c = qspi_addr_r_o;
		 qspi_ben_c = qspi_ben_r_o;
	  end
	  
      qspi_rd_c = qspi_rd_r_o;
      qspi_select_c = qspi_select_r;

    end
    // ICTRL_ERROR : Error state. If the AHB master does any non-single
    //               access to the CSR, the UDC-AHB subsystem does and ERROR
    //               response on AHB
    ICTRL_ERROR : begin
      hready_c      = HI;
      ictrl_state_c = ICTRL_READY; 

      hrdata_c = hrdata_r;
      qspi_val_c = qspi_val_r_o;
      hresp_c = hresp_r;
      qspi_rd_c = qspi_rd_r_o;
      qspi_select_c = qspi_select_r;
      qspi_addr_c = qspi_addr_r_o;
      qspi_ben_c = qspi_ben_r_o;
    end

    default : begin
      hready_c   = hready_r;
      qspi_select_c = qspi_select_r;

      hresp_c    = OKAY;
      hrdata_c   = 32'h0000_0000;
      qspi_val_c  = LO;
      qspi_rd_c   = LO;
      qspi_addr_c = 32'h0000_0000;
      qspi_ben_c  = 4'b0000;
      ictrl_state_c  = ICTRL_READY;
    end

  endcase

end

   always @ (posedge hclk_i or negedge hresetn_i) begin // STAR STS0167661

  if (~hresetn_i) begin

    tx_wrcfrm_zero_full_d <= 0;
  end else begin
 
    tx_wrcfrm_zero_full_d <= tx_wrcfrm_zero_full;
  end
end      

endmodule
