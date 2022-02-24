module adda_ctrl
(
    input   wire            sys_clk     ,   //输入系统时钟,50MHz
    input   wire            sys_rst_n   ,   //输入复位信号,低电平有效
    input   wire            i2c_end     ,   //i2c设备一次读/写操作完成
    input   wire    [7:0]   rd_data     ,   //输出i2c设备读取数据
	input   wire    [2:0]   wave_select ,   //输出波形选择
	
	input   wire            vga_clk     ,
	input   wire    [9:0]	ram_rd_addr ,

    output  reg             rd_en       ,    // I2C读写控制信号
	output  reg             wr_en       ,    // I2C读写控制信号
    output  reg             i2c_start   ,   //输入i2c设备触发信号
	output  reg     [7:0]   wr_data     ,   //输入i2c设备数据
    output  reg     [15:0]  byte_addr   ,   //输入i2c设备字节地址
	
    output  wire    [19:0]  po_data     ,    //数码管待显示数据
	output  wire    [7:0]   pic_data        //自ROM读出的图片数据
);
//************************************************************************//
//******************** Parameter and Internal Signal *********************//
//************************************************************************//
//parameter     define
parameter   sin_wave    =   3'b001      ,   //正弦波
            tri_wave    =   3'b010      ,   //三角波
            saw_wave    =   3'b100      ;    //锯齿波

parameter   CTRL_DATA   =   8'b0100_0001;   //AD/DA控制字
parameter   CNT_WAIT_MAX=   18'd99  ;   //采样间隔计数最大值
parameter   DA_IDLE     =   3'b001  ,
            DA_START    =   3'b010  ,
            DA_CMD      =   3'b011  ;
parameter   AD_IDLE     =   3'b100,
            AD_START    =   3'b101,
            AD_CMD      =   3'b110;
			

parameter   CNT_MAX     =   199_999;  //0.2s计数器最大值

//wire  define
wire    [31:0]  data_reg/* synthesis keep */;   //数码管待显示数据缓存
wire    [7:0]   da_data ;   //DA数据

wire    [31:0]   fre_data;
reg     [31:0]  fre_cnt;

reg              fre_ab;
reg     [31:0]   fre_cnt_reg;
reg              fre_en;
reg     [1:0]    zero_cnt;

//reg   define
reg     [17:0]  cnt_wait;   //采样间隔计数器
reg     [4:0]   state   ;   //状态机状态变量
reg     [7:0]   ad_data ;   //AD数据

reg     [7:0]   pre_rd_data;

reg             ram_wr_en; //输出写RAM使能，高点平有效
reg     [9:0]   ram_wr_addr ; //写RAM地址

reg     [10:0]  rom_rd_addr ; //读ROM地址
reg     [9:0]   rom_addr_reg; //ROM地址寄存

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
		
//da_data:DA数据
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
	begin
        rom_rd_addr <=  10'd0;
		rom_addr_reg <= 10'd0;
	end
	else if( rom_addr_reg == 10'd640 )
	    rom_addr_reg <= 10'd0;
    else  if((state == DA_CMD)&&(i2c_end == 1'b1))
	  case(wave_select)
        sin_wave:
            begin
                rom_addr_reg    <=  rom_addr_reg + 10'd1;
                rom_rd_addr     <=  rom_addr_reg;
            end     
        tri_wave:
            begin
                rom_addr_reg    <=  rom_addr_reg + 10'd1;
                rom_rd_addr     <=  rom_addr_reg + 10'd640;
            end     
        saw_wave:
        begin
                rom_addr_reg    <=  rom_addr_reg + 10'd1;
                rom_rd_addr     <=  rom_addr_reg + 11'd1280;
            end     
        default:
            begin
                rom_addr_reg    <=  rom_addr_reg + 10'd1;
                rom_rd_addr     <=  rom_addr_reg;
            end     
       endcase
	  else 
	      rom_rd_addr <= rom_rd_addr;
		
//cnt_wait:采样间隔计数器
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_wait    <=  18'd0;
    else    if((state == DA_IDLE)||(state == AD_IDLE))
        if(cnt_wait == CNT_WAIT_MAX)
            cnt_wait    <=  18'd0;
        else
            cnt_wait    <=  cnt_wait + 18'd1;
    else
        cnt_wait    <=  18'd0;

//state:状态机状态变量
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  DA_IDLE;
    else
        case(state)
            DA_IDLE:
                if(cnt_wait == CNT_WAIT_MAX)
                    state   <=  DA_START;
                else
                    state   <=  DA_IDLE;
            DA_START:
                state   <=  DA_CMD;
            DA_CMD:
                 if(i2c_end == 1'b1)
                    state   <=  AD_IDLE;
                 else
                    state   <=  DA_CMD;
			AD_IDLE:
                if(cnt_wait == CNT_WAIT_MAX)
                    state   <=  AD_START;
                else
                    state   <=  AD_IDLE;
            AD_START:
                state   <=  AD_CMD;
            AD_CMD:
                if(i2c_end == 1'b1)
                    state   <=  DA_IDLE;
                else
                    state   <=  AD_CMD;
            default:state   <=  DA_IDLE;
        endcase

//i2c_start:输入i2c设备触发信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        i2c_start   <=  1'b0;
    else    if((state == AD_START)||(state == DA_START))
        i2c_start   <=  1'b1;
    else
        i2c_start   <=  1'b0;
		
//wr_en:输入i2c设备写使能信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_en   <=  1'b0;
    else    if(state == DA_CMD)
		wr_en   <=  1'b1;
    else
        wr_en   <=  1'b0;	

//rd_en:输入i2c设备读使能信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        rd_en   <=  1'b0;
    else    if(state == AD_CMD)
        begin
		  rd_en   <=  1'b1;
		  ram_wr_en  <=  1'b1;
		end
    else
	    begin
          rd_en   <=  1'b0;
 	  	  ram_wr_en  <=  1'b0;
        end

//byte_addr:输入i2c设备字节地址
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        byte_addr   <=  16'b0;
    else
        byte_addr   <=  CTRL_DATA;
		
//wr_data:输入i2c设备数据
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_data <=  8'b0;
    else    if(state == DA_START)
        wr_data <=  da_data;
    else
        wr_data <=  wr_data;

//ad_data:AD数据
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        ad_data <=  8'b0;
    else    if((state == AD_CMD)&&(i2c_end == 1'b1))
        ad_data    <=  rd_data;		
		
		
//测频率：pre_rd_data
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        pre_rd_data <=  8'd0;
	else  
	    pre_rd_data <= rd_data;
	
//测频率：zero_cnt
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        zero_cnt <=  2'd0;
    else    if((rd_data == 8'd2)&&(pre_rd_data == 8'd1)&&(fre_en <= 1'b0))
        zero_cnt <= zero_cnt + 2'd1;
	else  
	    zero_cnt <= zero_cnt;

//测频率：fre_ab
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        fre_ab <=  1'b0;
    else    if(zero_cnt == 2'd1)
        fre_ab <= 1'b1;
    else    
        fre_ab <= 1'd0;
		
//测频率：fre_en
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        fre_en <=  1'b0;
    else    if(zero_cnt == 2'd2)
        fre_en <= 1'b1;
    else    
        fre_en <= fre_en;

//测频率：fre_cnt_reg
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        fre_cnt_reg <=  1'b0;
    else    if(fre_ab == 1'b1)
        fre_cnt_reg <= fre_cnt_reg + 32'd1;
    else    
        fre_cnt_reg <= fre_cnt_reg;

// assign 	fre_cnt = (fre_en == 1'b1)? fre_cnt_reg : fre_cnt;

//测频率：fre_cnt
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        fre_cnt <=  1'b0;
    else    if(fre_en == 1'b1)
        fre_cnt <= fre_cnt_reg;
    else    
        fre_cnt <= fre_cnt;

assign  fre_data = (32'd1_000_000 / fre_cnt);
			
//写使能有效时，
always@(posedge sys_clk or  negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        ram_wr_addr    <=  10'd0;
    else    if((ram_wr_addr == 10'd639) && (ram_wr_en == 1'b1))
        ram_wr_addr    <=  10'd0;
    else    if((ram_wr_en == 1'b1)&&(i2c_end == 1'b1))
        ram_wr_addr    <=  ram_wr_addr + 1'b1;
	else 
	    ram_wr_addr   <=   ram_wr_addr;
	
ram_256x8	ram_256x8_inst 
(
	.data ( ad_data ),
	.rdaddress ( ram_rd_addr ),
	.rdclock ( vga_clk ),
	.wraddress (ram_wr_addr),
	.wrclock ( sys_clk ),
	.wren ( ram_wr_en ),
	.q ( pic_data )
);
	

rom_256x8	rom_256x8_inst 
(
	.address ( rom_rd_addr ),
	.clock   ( sys_clk     ),
	
	.q       ( da_data     )
);
		
//data_reg:数码管待显示数据缓存
assign  data_reg = fre_data;

//po_data:数码管待显示数据
assign  po_data = data_reg[19:0];

endmodule



