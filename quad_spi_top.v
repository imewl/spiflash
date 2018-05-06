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
            // For register AHB slave
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
			// For Memory mapped AHB slave
    		
			// for DMA
			,tx_fifo_space
			,rx_fifo_fill
			//out-side IO
			,qspi_clk_o
			,qspi_d_i
			,qspi_d_o  
			,qspi_d_oe
			          // bit[0] MOSI
			          // bit[1] MISO
			          // bit[2] can be used as nWP
			          // bit[3] can be used as nHOLD
			,qspi_cs_n_o
			
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

output [3:0]	 tx_fifo_space;
output [3:0]     rx_fifo_fill;

output           qspi_clk_o;
input  [3:0]     qspi_d_i;
output [3:0]     qspi_d_o;
output [3:0]     qspi_d_oe;
output           qspi_cs_n_o;

//--------------------------------------------------------
//Reg Wire define
//--------------------------------------------------------
wire             qspi_val;
wire [31:0]      qspi_addr_r_o;
wire             qspi_rd;
wire [3:0]       qspi_ben;
wire [31:0]      qspi_wdata;
wire [31:0]      qspi_rdata;
wire             qspi_ack;
wire             qspi_bsy;
wire             qspi_indi_op_st;
wire [7:0]       qspi_prescal;
wire [7:0]       qspi_instruction;
wire             qspi_clk;
wire [1:0]       qspi_fmode;
wire [1:0]       qspi_imode;
wire [1:0]       qspi_admode;
wire [1:0]       qspi_dmode;
wire [1:0]       qspi_adsize;
wire             rd_fifo_clr;
wire             rd_fifo_wrreq;
wire [7:0]       rd_fifo_dat;
wire [31:0]      qspi_flash_addr;
wire [31:0]      qspi_dlr;
wire [31:0]      rd_fifo_q;
wire             rd_fifo_rdreq;
wire             rdfifo_empt;
wire             wr_fifo_wrreq;
wire [7:0]       wr_fifo_dat;
wire             wr_fifo_rdreq;
wire [7:0]       wr_fifo_q;

// AHB SLAVE INTERFACE

qspi_clk_div    u_clk_div (
                .ahb_rst_i                (hresetn_i      )
               ,.ahb_clk_i                (hclk_i         )
	           ,.qspi_prescal_i           (qspi_prescal   )
	           ,.qspi_busy_i              (qspi_bsy       )
	           ,.qspi_clk_o               (qspi_clk       )
                );

qspi_ahb_slave_itf u_ahb_if(
                 .hclk_i          (hclk_i         )
                ,.hresetn_i       (hresetn_i      )
                ,.haddr_i         (haddr_i        )
                ,.htrans_i        (htrans_i       )
                ,.hwdata_i        (hwdata_i       )
                ,.hwrite_i        (hwrite_i       )
                ,.hsize_i         (hsize_i        )
                ,.hburst_i        (hburst_i       )
                ,.hsel_i          (hsel_i         )
                ,.hready_i        (1'b1           )
                ,.qspi_hready_o   (hready_o       )
                ,.qspi_hresp_o    (hresp_o        )
                ,.qspi_hrdata_o   (hrdata_o       )
                ,.qspi_select_o   ()            
                ,.qspi_val_r_o    (qspi_val       )
                ,.qspi_addr_r_o   (qspi_addr_r_o  )
                ,.qspi_rd_r_o     (qspi_rd        )
                ,.qspi_ben_r_o    (qspi_ben       )
                ,.qspi_wdata_o    (qspi_wdata     )
                ,.qspi_rdata_i    (qspi_rdata     )
                ,.qspi_ack_i      (qspi_ack       )

                ,.qspi_bsy_i      (qspi_bsy       )
				);
				
qspi_ctrl_reg    u_ctrl_reg (
                 .ahb_rst_i               (hresetn_i    ) 
                ,.ahb_clk_i               (hclk_i       )
				,.qspi_val_i              (qspi_val     )
                ,.qspi_addr_i             (qspi_addr_r_o)
                ,.qspi_rd_i               (qspi_rd      )
                ,.qspi_ben_i              (qspi_ben     )
                ,.qspi_wdata_i            (qspi_wdata   )
                ,.qspi_rdata_o            (qspi_rdata   )
				,.qspi_ack_o              (qspi_ack     )
				,.qspi_busy_i             (qspi_bsy     )
				,.qspi_indi_op_st_o       (qspi_indi_op_st)
				
				,.qspi_prescal_o          (qspi_prescal)
				,.qspi_dlr_o              (qspi_dlr    )
				,.qspi_fmode_o            (qspi_fmode  )
				,.qspi_dmode_o            (qspi_dmode  )
				,.qspi_adsize_o           (qspi_adsize )
				,.qspi_admode_o           (qspi_admode)
				,.qspi_imode_o            (qspi_imode)
				,.qspi_instruction_o      (qspi_instruction)
				,.qspi_address_o          (qspi_flash_addr)
				
				,.wr_fifo_clr_o           (wr_fifo_clr)
				,.wr_fifo_wrreq_o         (wr_fifo_wrreq)
				,.wr_fifo_dat_o           (wr_fifo_dat)
				,.wr_fifo_full_i          (wrfifo_full    )
				
				,.rd_fifo_rdreq_o (rd_fifo_rdreq  )
				,.rdfifo_rdata_i  (rd_fifo_q      )
				,.rdfifo_empt_i   (rdfifo_empt    )
				
				,.qspi_cs_n_i     (qspi_cs_n_o    )
				
				
                );
ffdc_128x8     u_wr_dat_fifo(
                // write-side
                 .wrclk                   (hclk_i          )
                ,.wrreq                   (wr_fifo_wrreq)
                ,.data                    (wr_fifo_dat)
                ,.wrfull                  (wrfifo_full)
                ,.wrempty                 ()
                ,.wrusedw                 ()
                // read-side
                ,.rdclk                   (qspi_clk)
                ,.rdreq                   (wr_fifo_rdreq)
                ,.q                       (wr_fifo_q)
                ,.rdfull                  ()
                ,.rdempty                 ()
                ,.rdusedw                 ()
                // asynchronous and write-side reset for all modules
                ,.aclr_wr                 (wr_fifo_clr)
                ,.aclr_rd                 (hresetn_i)
                ,.wrrst                   (hresetn_i)
                );
				
ffdc_128x8     u_rd_dat_fifo(
                // write-side
                 .wrclk                   (qspi_clk       )
                ,.wrreq                   (rd_fifo_wrreq)
                ,.data                    (rd_fifo_dat)
                ,.wrfull                  ()
                ,.wrempty                 ()
                ,.wrusedw                 ()
                // read-side
                ,.rdclk                   (hclk_i)
                ,.rdreq                   (rd_fifo_rdreq)
                ,.q                       (rd_fifo_q)
                ,.rdfull                  ()
                ,.rdempty                 (rdfifo_empt)
                ,.rdusedw                 ()
                // asynchronous and write-side reset for all modules
                ,.aclr_wr                 (hresetn_i)
                ,.aclr_rd                 (rd_fifo_clr)
                ,.wrrst                   (hresetn_i)
                );

qspi_shifter     u_qspi_shifter (
                 .rst_n_i                 (hresetn_i)
				,.qspi_clk_i              (qspi_clk)
				,.qspi_indi_op_st_i       (qspi_indi_op_st )
				,.qspi_fmode_i            (qspi_fmode      )
				,.qspi_admode_i           (qspi_admode     )
				,.qspi_imode_i            (qspi_imode      )
				,.qspi_dmode_i            (qspi_dmode      )
				,.qspi_instruction_i      (qspi_instruction)
				,.qspi_flash_addr_i       (qspi_flash_addr )
				,.qspi_adsize_i           (qspi_adsize     )
				,.qspi_dlr_i              (qspi_dlr        )
				
				,.qspi_bsy_o              (qspi_bsy   )
				,.qspi_clk_o              (qspi_clk_o )
				,.qspi_cs_n_o             (qspi_cs_n_o)
				,.qspi_d_o                (qspi_d_o   )
				,.qspi_d_i                (qspi_d_i   )
				,.qspi_d_oe               (qspi_d_oe  )
				
				,.rd_fifo_clr_o           (rd_fifo_clr     )
				,.rd_fifo_wrreq_o         (rd_fifo_wrreq   )
				,.rd_fifo_dat_o           (rd_fifo_dat     )
				
				,.wr_fifo_rdreq_o         (wr_fifo_rdreq   )
				,.wr_fifo_dat_i           (wr_fifo_q       )
                );				
				
endmodule
