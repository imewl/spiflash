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
//  Filename:   qspi_clk_div
//  Author:          
//  Date:            
//
//  Project:         
//  Descriptions: AHB Interface register for Quad-SPI controller.
//---------------------------------------------------------------------

module   qspi_clk_div (
                       ahb_rst_i,
                       ahb_clk_i,
					   qspi_prescal_i,
					   qspi_busy_i,
					   qspi_clk_o
					   );
//--------------------------------
//  Ports
//--------------------------------					   
input                  ahb_rst_i;
input                  ahb_clk_i;
input [7:0]            qspi_prescal_i;
input                  qspi_busy_i;
output                 qspi_clk_o;
//--------------------------------
//  Wires and REGs
//--------------------------------
reg [7:0]              qspi_prescal_r;            
reg [7:0]              clk_div_cnt;            
reg                    clk_div;            

always@(posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    qspi_prescal_r <= 8'h0;
  end
  else if(!qspi_busy_i) begin
    qspi_prescal_r <= qspi_prescal_i;
  end
end

always@(posedge ahb_clk_i or negedge ahb_rst_i) begin
  if(!ahb_rst_i) begin
    clk_div_cnt <= 8'h1;
	clk_div     <= 1'b0;
  end
  else begin
    if(clk_div_cnt < qspi_prescal_r)
       clk_div_cnt <= clk_div_cnt + 1'b1;
    else
       clk_div_cnt <= 8'h1;
  
    if(clk_div_cnt  == qspi_prescal_r)
	  clk_div <= ~clk_div;
	else
	  clk_div <= clk_div;
  end
end
assign qspi_clk_o = (qspi_prescal_r == 8'h0)?ahb_clk_i:clk_div;

endmodule 