//**********************************************************************
//
//    COPYRIGHT (C)  Broadband Communication System Laborotory(BCS), 
//  Institute of Micro Electronics Chinese Academy of Sciences(IMECAS)
//
//**********************************************************************
//
// Title       : sdio_sync_a2b.v
// Author      : WangLei
// Created     : 2014.11.15
// Description : Independent RTC synchronizing module 
// Note: 
//**********************************************************************
//
//   Date           By        Version       Change Description
//----------------------------------------------------------------------
// 2014.11.15    WangLei       v1.0           initial version
//**********************************************************************

module spi_sync_a2b(
					rst_n,
					clk_b,
					dat_a,
					dat_b
					);
input	rst_n;
input	clk_b;
input	dat_a;
output	dat_b;

reg[2:0]	sync_a2b;

always@(posedge clk_b or negedge rst_n) begin
	if(!rst_n)
		sync_a2b <= 3'b000;
	else
		sync_a2b <= {sync_a2b[1:0], dat_a};
end

assign	dat_b = sync_a2b[2];

endmodule