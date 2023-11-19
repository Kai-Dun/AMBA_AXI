`timescale 1ns/10ps
`define CYCLE_TIME 10.0

parameter ID_WIDTH = 4;
parameter ADDR_WIDTH = 4;
parameter DATA_WIDTH = 16;
parameter BRESP_WIDTH = 3;
parameter WR_MEM_DELAY = 0;
parameter RD_MEM_DELAY = 0;

parameter STROBE_WIDTH = DATA_WIDTH/8;
parameter MEM_ADDR_SIZE = ADDR_WIDTH - $clog2(STROBE_WIDTH);



module AMBA_AXI_ram_tb();
reg 						clk, rst_n;
//axi write address channel
reg 						s_axi_awvalid;
wire						s_axi_awready;
reg [ID_WIDTH - 1 : 0] 		s_axi_awid;
reg [ADDR_WIDTH - 1 : 0] 	s_axi_awaddr;
reg [7:0] 					s_axi_awlen;
reg [2:0] 					s_axi_awsize;
reg [1:0] 					s_axi_awburst;//only INCR mode(2'b01), 
//axi write data channel
reg 						s_axi_wvalid;
wire 						s_axi_wready;
reg [DATA_WIDTH - 1 : 0] 	s_axi_wdata;
reg [STROBE_WIDTH - 1 : 0]	s_axi_wstrb;
reg 						s_axi_wlast;
//axi write response channel
wire	 					s_axi_bvalid;
reg 						s_axi_bready;
wire [ID_WIDTH - 1 : 0] 	s_axi_bid;
wire [BRESP_WIDTH - 1 : 0]  s_axi_bresp;
//axi read address channel
reg 						s_axi_arvalid;
wire						s_axi_arready;
reg [ID_WIDTH - 1 : 0] 		s_axi_arid;
reg [ADDR_WIDTH - 1 : 0] 	s_axi_araddr;
reg [7:0]					s_axi_arlen;
reg [2:0]					s_axi_arsize;
reg [1:0]					s_axi_arburst;
//axi read data channel
wire						s_axi_rvalid;
reg 						s_axi_rready;
wire [ID_WIDTH - 1 : 0] 	s_axi_rid;
wire [DATA_WIDTH - 1 : 0]	s_axi_rdata;
wire [BRESP_WIDTH - 1 : 0]	s_axi_rresp;
wire						s_axi_rlast;


//======================== debug ==============================
wire [DATA_WIDTH - 1 : 0] mem_w[(1 << MEM_ADDR_SIZE) - 1 : 0];
assign mem_w = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.mem;
//
wire [1:0] W_state, W_next_state;
assign W_state = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.W_state;
assign W_next_state = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.W_next_state;

reg [7:0] wdata_index_cnt;
assign wdata_index_cnt = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.wdata_index_cnt;

wire [1+$clog2(WR_MEM_DELAY) : 0] wr_mem_delay_cnt;
assign wr_mem_delay_cnt = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.wr_mem_delay_cnt;

wire [ADDR_WIDTH - 1 : 0] 		s_axi_awaddr_reg;
assign s_axi_awaddr_reg = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.s_axi_awaddr_reg;
//
//wire R_state, R_next_state;
//assign R_state = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.R_state;
//assign R_next_state = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.R_next_state;
//
//wire [7:0] rdata_index_cnt;
//assign rdata_index_cnt = AMBA_AXI_ram_tb.AMBA_AXI_ram_Inst.rdata_index_cnt;



//======================== debug end ===========================


always #(`CYCLE_TIME/2) clk = ~clk ;

integer i, j, cnt;
initial begin
	clk = 0;
	rst_n = 0;
	
	#20
	
	reset_task;
	
	write_task;
	
	read_task;
	
	$display("finish");
end

AMBA_AXI_ram
#(
	.ID_WIDTH(ID_WIDTH),
	.ADDR_WIDTH(ADDR_WIDTH),
	.DATA_WIDTH(DATA_WIDTH),
	.BRESP_WIDTH(BRESP_WIDTH),
	.WR_MEM_DELAY(WR_MEM_DELAY),
	.RD_MEM_DELAY(RD_MEM_DELAY)
)
AMBA_AXI_ram_Inst
(
//axi global signal
	.clk(clk),
	.rst_n(rst_n),
//axi write request channel
	.s_axi_awvalid(s_axi_awvalid),
	.s_axi_awready(s_axi_awready),
	.s_axi_awid(s_axi_awid),
	.s_axi_awaddr(s_axi_awaddr),
	.s_axi_awlen(s_axi_awlen),
	.s_axi_awsize(s_axi_awsize),
	.s_axi_awburst(s_axi_awburst), 			//only INCR mode(2'b01), 
//axi write data channel
	.s_axi_wvalid(s_axi_wvalid),
	.s_axi_wready(s_axi_wready),
	.s_axi_wdata(s_axi_wdata),
	.s_axi_wstrb(s_axi_wstrb), 
	.s_axi_wlast(s_axi_wlast),
//axi write response channel
	.s_axi_bvalid(s_axi_bvalid),
	.s_axi_bready(s_axi_bready),
	.s_axi_bid(s_axi_bid),
	.s_axi_bresp(s_axi_bresp),
//axi read request channel
	.s_axi_arvalid(s_axi_arvalid),
	.s_axi_arready(s_axi_arready),
	.s_axi_arid(s_axi_arid),
	.s_axi_araddr(s_axi_araddr),
	.s_axi_arlen(s_axi_arlen),
	.s_axi_arsize(s_axi_arsize),
	.s_axi_arburst(s_axi_arburst),
//read data channel
	.s_axi_rvalid(s_axi_rvalid),
	.s_axi_rready(s_axi_rready),
	.s_axi_rid(s_axi_rid),
	.s_axi_rdata(s_axi_rdata),
	.s_axi_rresp(s_axi_rresp),
	.s_axi_rlast(s_axi_rlast)
);
	
	
	
task reset_task;
    //axi write request channel
    s_axi_awvalid = 0;
    s_axi_awid = 0;
    s_axi_awaddr = 0;
    s_axi_awlen = 0;
    s_axi_awsize = 0;
    s_axi_awburst = 0;
    //axi write data channel
    s_axi_wvalid = 0;
    s_axi_wdata = 0;
    s_axi_wstrb = 0;
    s_axi_wlast = 0;
    //axi write response channel
    s_axi_bready = 0;
    //axi read request channel
    s_axi_arvalid = 0;
    s_axi_arid = 0;
    s_axi_araddr = 0;
    s_axi_arlen = 0;
    s_axi_arsize = 0;
    s_axi_arburst = 0;
    //axi read data channel
    s_axi_rready = 0;
	
	@(negedge clk);
	rst_n = 0;
	@(negedge clk);
	rst_n = 1;
    @(negedge clk);
endtask


task write_task;
    for(j=0; j<16; j=j+8)begin
        s_axi_awvalid = 1;
        s_axi_awid = 2;
        s_axi_awaddr = j;
        s_axi_awlen = 4;
        s_axi_awsize = 0;
        s_axi_awburst = 2'b01;

        wait_wr_request_ready;
		  @(negedge clk);

        //axi write data channel
        s_axi_wvalid = 1;
        strobe_init_control;
        s_axi_wlast = 0;
        //axi write response channel
        s_axi_bready = 1;
        
        for(i=10+j; i < 14+j; i=i+1)begin
		  
			wait_wr_data_ready;
		   //=========================== when size = 0 ============================
			 if(i<10+2+j)
             s_axi_wdata = {8'h0a + j[7:0], 8'h0b + j[7:0]};
			 else
			 	s_axi_wdata = {8'h0c + j[7:0], 8'h0d + j[7:0]};
			
			//=========================== when size = 1 ============================
			
//			s_axi_wdata = {8'h0c + j[7:0] + i[7:0], 8'h0d + j[7:0] + i[7:0]};
			
			@(negedge clk);
			strobe_shift_control;
			if(s_axi_wstrb == 0)
				strobe_init_control;
        end

        wait_wr_response_ready;
    end
	s_axi_awvalid = 0;
	
endtask

task wait_wr_request_ready;
	cnt = 0;
	while(~s_axi_awready)begin
		@(negedge clk);
		cnt = cnt + 1;
		
		if(cnt>100) begin
			$display ("---------------------------------------------------------------------------------------");
            $display ("                              wr_request FAIL!                                         ");
            $display ("                    s_axi_awaddr = %d, s_axi_wdata = %d                      ",s_axi_awaddr, s_axi_wdata);
            $display ("---------------------------------------------------------------------------------------");
			break;
		end
	end
endtask

task wait_wr_data_ready;
	cnt = 0;
	while(~s_axi_wready)begin
		@(negedge clk);
		cnt = cnt + 1;
		
		if(cnt>8) begin
			$display ("---------------------------------------------------------------------------------------");
            $display ("                                wr_data FAIL!                                          ");
            $display ("                    s_axi_awaddr = %d, s_axi_wdata = %d                      ",s_axi_awaddr, s_axi_wdata);
            $display ("---------------------------------------------------------------------------------------");
			break;
		end
	end
endtask

task wait_wr_response_ready;
	cnt = 0;
	while(~s_axi_bvalid)begin
		@(negedge clk);
		cnt = cnt + 1;
		
		if(cnt>8) begin
			$display ("---------------------------------------------------------------------------------------");
            $display ("                              wr_response FAIL!                                        ");
            $display ("                    s_axi_awaddr = %d, s_axi_wdata = %d                      ",s_axi_awaddr, s_axi_wdata);
            $display ("---------------------------------------------------------------------------------------");
			break;
		end
	end
endtask

task strobe_init_control;
	case(s_axi_awsize)
		0 : s_axi_wstrb = { {(STROBE_WIDTH - 1 << 0){1'b0}} , {(1 << 0){1'b1}}};
		1 : s_axi_wstrb = { {(STROBE_WIDTH - 1 << 1){1'b0}} , {(1 << 1){1'b1}}};
		2 : s_axi_wstrb = { {(STROBE_WIDTH - 1 << 2){1'b0}} , {(1 << 2){1'b1}}};
		3 : s_axi_wstrb = { {(STROBE_WIDTH - 1 << 3){1'b0}} , {(1 << 3){1'b1}}};
		4 : s_axi_wstrb = { {(STROBE_WIDTH - 1 << 4){1'b0}} , {(1 << 4){1'b1}}};
		5 : s_axi_wstrb = { {(STROBE_WIDTH - 1 << 5){1'b0}} , {(1 << 5){1'b1}}};
		6 : s_axi_wstrb = { {(STROBE_WIDTH - 1 << 6){1'b0}} , {(1 << 6){1'b1}}};
		7 : s_axi_wstrb = { {(STROBE_WIDTH - 1 << 7){1'b0}} , {(1 << 7){1'b1}}};
	endcase
	
endtask

task strobe_shift_control;
	case(s_axi_awsize)
		0 : s_axi_wstrb = s_axi_wstrb << (1 << 0);
		1 : s_axi_wstrb = s_axi_wstrb << (1 << 1);
		2 : s_axi_wstrb = s_axi_wstrb << (1 << 2);
		3 : s_axi_wstrb = s_axi_wstrb << (1 << 3);
		4 : s_axi_wstrb = s_axi_wstrb << (1 << 4);
		5 : s_axi_wstrb = s_axi_wstrb << (1 << 5);
		6 : s_axi_wstrb = s_axi_wstrb << (1 << 6);
		7 : s_axi_wstrb = s_axi_wstrb << (1 << 7);
	endcase
	
endtask


task read_task;
	for(j=0; j<16; j=j+8)begin
		s_axi_arvalid = 1;
		s_axi_arid = 2;
		s_axi_araddr = j;
		s_axi_arlen = 4;
		s_axi_arsize = 0;
		s_axi_arburst = 2'b01;

		wait_rd_request_ready;
		@(negedge clk);

		//axi read data channel
		s_axi_rready = 1;

		for(i=0; i<4; i=i+1)begin
			wait_rd_data_valid;
		end
    end

	s_axi_arvalid = 0;
endtask	

task wait_rd_request_ready;
	cnt = 0;
	while(~s_axi_arready)begin
		@(negedge clk);
		cnt = cnt + 1;
		
		if(cnt>8) begin
			$display ("---------------------------------------------------------------------------------------");
            $display ("                              rd_request FAIL!                                         ");
            $display ("                    s_axi_araddr = %d, s_axi_rdata = %d                      ",s_axi_araddr, s_axi_rdata);
            $display ("---------------------------------------------------------------------------------------");
			break;
		end
	end
endtask

task wait_rd_data_valid;
	cnt = 0;
	while(~s_axi_rvalid)begin
		@(negedge clk);
		cnt = cnt + 1;
		
		if(cnt>8) begin
			$display ("---------------------------------------------------------------------------------------");
            $display ("                                rd_data FAIL!                                          ");
            $display ("                    s_axi_awaddr = %d, s_axi_wdata = %d                      ",s_axi_awaddr, s_axi_wdata);
            $display ("---------------------------------------------------------------------------------------");
			break;
		end
	end
	
	@(negedge clk);
endtask



endmodule 

	