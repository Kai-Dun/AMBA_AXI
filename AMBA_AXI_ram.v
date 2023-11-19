//subordinate + mem

module AMBA_AXI_ram
#(
	parameter ID_WIDTH = 4,
	parameter ADDR_WIDTH = 8,
	parameter DATA_WIDTH = 16,
	parameter BRESP_WIDTH = 3,
	parameter WR_MEM_DELAY = 2,
	parameter RD_MEM_DELAY = 2
)
(
//axi global signal
	clk,
	rst_n,
//axi write request channel
	s_axi_awvalid,
	s_axi_awready,
	s_axi_awid,
	s_axi_awaddr,
	s_axi_awlen,
	s_axi_awsize,
	s_axi_awburst, 							//only INCR mode(2'b01), 
//axi write data channel
	s_axi_wvalid,
	s_axi_wready,
	s_axi_wdata,
	s_axi_wstrb, 
	s_axi_wlast,
//axi write response channel
	s_axi_bvalid,
	s_axi_bready,
	s_axi_bid,
	s_axi_bresp,
//axi read request channel
	s_axi_arvalid,
	s_axi_arready,
	s_axi_arid,
	s_axi_araddr,
	s_axi_arlen,
	s_axi_arsize,
	s_axi_arburst,
//read data channel
	s_axi_rvalid,
	s_axi_rready,
	s_axi_rid,
	s_axi_rdata,
	s_axi_rresp,
	s_axi_rlast
);

//================================================================
//  local parameter
//================================================================
parameter STROBE_WIDTH = DATA_WIDTH/8;

parameter W_STATE_IDLE = 2'd0;
parameter W_STATE_BRUST = 2'd1;
parameter W_STATE_RESPON = 2'd2;

parameter R_STATE_IDLE = 1'd0;
parameter R_STATE_BRUST = 1'd1;

parameter MEM_ADDR_SIZE = ADDR_WIDTH - $clog2(STROBE_WIDTH); //because input addr increases per Byte, and Mem addr increases per STROBE(DATA_WIDTH's Byte);

//================================================================
//  input output declaration
//================================================================
//axi global signal
input 								clk, rst_n;
//axi write request channel
input 								s_axi_awvalid;
output reg 							s_axi_awready;
input [ID_WIDTH - 1 : 0] 			s_axi_awid;
input [ADDR_WIDTH - 1 : 0] 			s_axi_awaddr;
input [7:0] 						s_axi_awlen;
input [2:0] 						s_axi_awsize;
input [1:0] 						s_axi_awburst;//only INCR mode(2'b01), 
//axi write data channel
input 								s_axi_wvalid;
output reg 							s_axi_wready;
input [DATA_WIDTH - 1 : 0] 			s_axi_wdata;
input [STROBE_WIDTH - 1 : 0]		s_axi_wstrb;
input 								s_axi_wlast;
//axi write response channel
output reg	 						s_axi_bvalid;
input 								s_axi_bready;
output [ID_WIDTH - 1 : 0] 			s_axi_bid;
output [BRESP_WIDTH - 1 : 0] 		s_axi_bresp;
//axi read request channel
input 								s_axi_arvalid;
output reg							s_axi_arready;
input [ID_WIDTH - 1 : 0] 			s_axi_arid;
input [ADDR_WIDTH - 1 : 0] 			s_axi_araddr;
input [7:0]							s_axi_arlen;
input [2:0]							s_axi_arsize;
input [1:0]							s_axi_arburst;
//axi read data channel
output reg							s_axi_rvalid;
input 								s_axi_rready;
output [ID_WIDTH - 1 : 0] 			s_axi_rid;
output reg [DATA_WIDTH - 1 : 0]		s_axi_rdata;
output [BRESP_WIDTH - 1 : 0]		s_axi_rresp;
output reg							s_axi_rlast;
	
//================================================================
//  Variable
//================================================================
integer i;

reg [1:0] W_state, W_next_state; //State Machine
reg R_state, R_next_state;
reg [DATA_WIDTH - 1 : 0] mem[(1 << MEM_ADDR_SIZE) - 1 : 0]; //Memory

//Mem delay cnt
reg [1+$clog2(WR_MEM_DELAY) : 0] wr_mem_delay_cnt;
reg [1+$clog2(RD_MEM_DELAY) : 0] rd_mem_delay_cnt;
wire wr_mem_done, rd_mem_done;

//============= write request channel store ===============
reg [ID_WIDTH - 1 : 0] 			s_axi_awid_reg;
reg [ADDR_WIDTH - 1 : 0] 		s_axi_awaddr_reg;
reg [2:0] 						s_axi_awsize_reg;
reg [1:0] 						s_axi_awburst_reg;

reg [7:0] wdata_index_cnt;

//addr
wire [MEM_ADDR_SIZE - 1 : 0] 	awaddr_mem, araddr_mem;
wire wr_data_hand_en, rd_data_hand_en;


//============= read request channel store ===============
reg [ID_WIDTH - 1 : 0] 			s_axi_arid_reg;
reg [ADDR_WIDTH - 1 : 0] 		s_axi_araddr_reg;
reg [2:0] 						s_axi_arsize_reg;
reg [1:0] 						s_axi_arburst_reg;

reg [7:0] rdata_index_cnt;

//================================================================
//  Write Contorl
//================================================================
//write state_com
always@(*)begin
    case(W_state)
        W_STATE_IDLE:begin
			if(s_axi_awvalid && s_axi_awready)
				W_next_state = W_STATE_BRUST;
			else
				W_next_state = W_STATE_IDLE;
        end
        W_STATE_BRUST:begin
			if(wdata_index_cnt > 0 || ~wr_mem_done)
				W_next_state = W_STATE_BRUST;
			else
				W_next_state = W_STATE_RESPON;
        end

        W_STATE_RESPON:begin
            if(s_axi_bready)
				W_next_state = W_STATE_IDLE;
			else
				W_next_state = W_STATE_RESPON;
        end
		  
		  default: W_next_state = W_STATE_IDLE;
    endcase
end

always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        W_state <= W_STATE_IDLE;
    end
    else begin
        W_state <= W_next_state;
    end
end


//============= write request channel process =============
// input 							s_axi_awvalid;
// output reg 						s_axi_awready;
// input [ID_WIDTH - 1 : 0] 		s_axi_awid;
// input [ADDR_WIDTH - 1 : 0] 		s_axi_awaddr;
// input [7:0] 						s_axi_awlen;
// input [2:0] 						s_axi_awsize;
// input [1:0] 						s_axi_awburst;//only INCR mode(2'b01), 
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
		  s_axi_awid_reg 	<= 0;
		  s_axi_awsize_reg	<= 0;
		  s_axi_awburst_reg	<= 0;
    end
    else begin
		if(W_state == W_STATE_IDLE & s_axi_awvalid & s_axi_awready)begin
			  s_axi_awid_reg 	<= s_axi_awid;
			  s_axi_awsize_reg	<= s_axi_awsize < ($clog2(STROBE_WIDTH)) ? s_axi_awsize : ($clog2(STROBE_WIDTH));
			  s_axi_awburst_reg	<= s_axi_awburst;
		end
    end
end

//cnt for length 
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        wdata_index_cnt <= 0;
    end
    else begin
		if(W_state == W_STATE_IDLE && s_axi_awvalid && s_axi_awready)
			wdata_index_cnt <= s_axi_awlen;
		else if(wr_data_hand_en)
			wdata_index_cnt <= wdata_index_cnt - 1;
    end
end

//address 
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_awaddr_reg <= 0;
    end
    else begin
        if(W_state == W_STATE_IDLE && s_axi_awvalid && s_axi_awready)
			s_axi_awaddr_reg <= s_axi_awaddr;
		else if(wr_data_hand_en && wdata_index_cnt > 1 && s_axi_awburst_reg != 2'b00)
			s_axi_awaddr_reg <= s_axi_awaddr_reg + (1 << s_axi_awsize_reg);
    end
end

assign awaddr_mem = s_axi_awaddr_reg >> ($clog2(STROBE_WIDTH));

//output s_axi_awready
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_awready <= 0;
    end
    else begin
        if(W_state == W_STATE_IDLE)
			s_axi_awready <= 1;
		else
			s_axi_awready <= 0;
    end
end



//============= write data channel process ===============
// input 								s_axi_wvalid;
// output reg 							s_axi_wready;
// input [DATA_WIDTH - 1 : 0] 			s_axi_wdata;
// input [STROBE_WIDTH - 1 : 0]			s_axi_wstrb;
// input 								s_axi_wlast;
assign wr_data_hand_en = (W_state == W_STATE_BRUST && s_axi_wready && s_axi_wvalid);
assign wr_mem_done = wr_mem_delay_cnt == WR_MEM_DELAY;

//output s_axi_wready
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_wready <= 0;
    end
    else begin
        if (W_state == W_STATE_IDLE && W_next_state == W_STATE_BRUST || W_state == W_STATE_BRUST && W_next_state != W_STATE_RESPON && wr_mem_done)
			s_axi_wready <= 1;
		else
			s_axi_wready <= 0;
    end
end


//Memory delay cnt
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        wr_mem_delay_cnt <= 0;
    end
    else begin
		if(wr_mem_done)
			wr_mem_delay_cnt <= 0; 
		else if(wr_data_hand_en || W_state == W_STATE_BRUST && wr_mem_delay_cnt > 0)
        	wr_mem_delay_cnt <= wr_mem_delay_cnt + 1;
    end
end


//============= write response channel process ===============
// output reg	 						s_axi_bvalid;
// input 								s_axi_bready;
// output [ID_WIDTH - 1 : 0] 			s_axi_bid;
// output [BRESP_WIDTH - 1 : 0] 		s_axi_bresp;

//output s_axi_bvalid
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_bvalid <= 0;
    end
    else begin
        if (W_state != W_STATE_RESPON )
			s_axi_bvalid <= 0;
		else
			s_axi_bvalid <= 1;
    end
end

assign s_axi_bid = s_axi_awid_reg;
assign s_axi_bresp = {BRESP_WIDTH{1'b0}};



//================================================================
//  Read Contorl
//================================================================
//read state_com
always@(*)begin
    case(R_state)
        R_STATE_IDLE:begin
			if(s_axi_arvalid && s_axi_arready)
				R_next_state = R_STATE_BRUST;
			else
				R_next_state = R_STATE_IDLE;
        end
        R_STATE_BRUST:begin
			if(rdata_index_cnt > 1 || ~rd_mem_done)
				R_next_state = R_STATE_BRUST;
			else
				R_next_state = R_STATE_IDLE;
        end
		  
		default: R_next_state = R_STATE_IDLE;
    endcase
end

always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        R_state <= R_STATE_IDLE;
    end
    else begin
        R_state <= R_next_state;
    end
end


//============= read request channel process =============
// input 								s_axi_arvalid;
// output reg							s_axi_arready;
// input [ID_WIDTH - 1 : 0] 			s_axi_arid;
// input [ADDR_WIDTH - 1 : 0] 			s_axi_araddr;
// input [7:0]							s_axi_arlen;
// input [2:0]							s_axi_arsize;
// input [1:0]							s_axi_arburst;
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
		  s_axi_arid_reg 	<= 0;
		  s_axi_arsize_reg	<= 0;
		  s_axi_arburst_reg	<= 0;
    end
    else begin
		if(R_state == R_STATE_IDLE & s_axi_arvalid & s_axi_arready)begin
			  s_axi_arid_reg 	<= s_axi_arid;
			  s_axi_arsize_reg	<= s_axi_arsize < ($clog2(STROBE_WIDTH)) ? s_axi_arsize : ($clog2(STROBE_WIDTH));
			  s_axi_arburst_reg	<= s_axi_arburst;
		end
    end
end

//cnt for length 
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        rdata_index_cnt <= 0;
    end
    else begin
		if(R_state == R_STATE_IDLE && s_axi_arvalid && s_axi_arready)
			rdata_index_cnt <= s_axi_arlen;
		else if(rd_data_hand_en && rd_mem_done)
			rdata_index_cnt <= rdata_index_cnt - 1;
    end
end

//address 
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_araddr_reg <= 0;
    end
    else begin
        if(R_state == R_STATE_IDLE && s_axi_arvalid && s_axi_arready)
			s_axi_araddr_reg <= s_axi_araddr;
		else if(rd_data_hand_en && rd_mem_done && s_axi_arburst_reg != 2'b00)
			s_axi_araddr_reg <= s_axi_araddr_reg + (1 << s_axi_arsize_reg);
    end
end

assign araddr_mem = s_axi_araddr_reg >> ($clog2(STROBE_WIDTH));

//output s_axi_arready
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_arready <= 0;
    end
    else begin
        if(R_state == R_STATE_IDLE)
			s_axi_arready <= 1;
		else
			s_axi_arready <= 0;
    end
end


//============= read data channel process ===============
// output reg							s_axi_rvalid;
// input 								s_axi_rready;
// output [ID_WIDTH - 1 : 0] 			s_axi_rid;
// output reg [DATA_WIDTH - 1 : 0]		s_axi_rdata;
// output [BRESP_WIDTH - 1 : 0]			s_axi_rresp;
// output reg							s_axi_rlast;
assign rd_data_hand_en = (R_state == R_STATE_BRUST && s_axi_rready);
assign rd_mem_done = rd_mem_delay_cnt == RD_MEM_DELAY;

//output s_axi_wready
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_rvalid <= 0;
    end
    else begin
        if (R_state == R_STATE_BRUST && rd_mem_done)
			s_axi_rvalid <= 1;
		else
			s_axi_rvalid <= 0;
    end
end


//Memory delay cnt
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        rd_mem_delay_cnt <= 0;
    end
    else begin
		if(rd_mem_done)
			rd_mem_delay_cnt <= 0; 
		else if(rd_data_hand_en || R_state == R_STATE_BRUST && rd_mem_delay_cnt > 0)
        	rd_mem_delay_cnt <= rd_mem_delay_cnt + 1;
    end
end

assign s_axi_rid = s_axi_arid_reg;
assign s_axi_rresp = {BRESP_WIDTH{1'b0}};

//read mem data
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_rdata <= 0;
    end
    else begin
		if(rd_data_hand_en && rd_mem_done)
        	s_axi_rdata <= mem[araddr_mem];
    end
end

//rdata_last
always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        s_axi_rlast <= 0;
    end
    else begin
		if(rdata_index_cnt == 1 && rd_mem_done)
        	s_axi_rlast <= 1;
		else
			s_axi_rlast <= 0;
    end
end



//================================================================
//  Memory
//================================================================

always@(posedge clk, negedge rst_n)begin
    if(~rst_n)begin
        for	(i=0; i<(1 << MEM_ADDR_SIZE);i=i+1)
			mem[i] <= 0;
    end
    else begin
        for(i=0; i<STROBE_WIDTH; i=i+1)begin
			if(wr_data_hand_en & s_axi_wstrb[i])
				mem[awaddr_mem][8*(i+1)-1 -: 8] <= s_axi_wdata[8*(i+1)-1 -: 8];
		end
    end
end




endmodule 