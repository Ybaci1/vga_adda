`timescale  1ns/1ns
/////////////////////////////////////////////////////////////////////////
// Author        : EmbedFire
// Create Date   : 2019/07/10
// Module Name   : key_control
// Project Name  : top_dds
// Target Devices: Altera EP4CE10F17C8N
// Tool Versions : Quartus 13.0
// Description   : 按键控制模块,控制波形选择
// 
// Revision      : V1.0
// Additional Comments:
// 
// 实验平台: 野火_征途Pro_FPGA开发板
// 公司    : http://www.embedfire.com
// 论坛    : http://www.firebbs.cn
// 淘宝    : https://fire-stm32.taobao.com
////////////////////////////////////////////////////////////////////////

module  key_control
(
    input   wire            sys_clk     ,   //系统时钟,50MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
    input   wire    [2:0]   key         ,   //输入1位按键

    output  reg     [2:0]   wave_select,     //输出波形选择
	output  reg     [2:0]   FRE_select,
	output  reg     [1:0]   RAN_select   
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
parameter   sin_wave    =   3'b001,    //正弦波
            tri_wave    =   3'b010,    //三角波
            saw_wave    =   3'b100;    //锯齿波
			
parameter   FRE_ONE     =   3'b001,
            FRE_TWO     =   3'b010,
			FRE_THREE   =   3'b011,
			FRE_FOUR    =   3'b100,
            FRE_FIVE    =   3'b101;
			
parameter   RAN_ONE     =   2'b01,
            RAN_TWO     =   2'b10,
			RAN_THREE   =   2'b11;

parameter   CNT_MAX =   20'd999_999;    //计数器计数最大值

//wire  define
wire            key2    ;   //按键2
wire            key1    ;   //按键1
wire            key0    ;   //按键0


//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//wave:按键状态对应波形
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wave_select   <=  3'b000;
    else    if(key0 == 1'b1)
	case(wave_select)
	    sin_wave: wave_select <= tri_wave;
		tri_wave: wave_select <= saw_wave;
		saw_wave: wave_select <= sin_wave;
	default : wave_select <= sin_wave;
	endcase
    else
        wave_select   <=  wave_select;
		
//FRE:按键状态对应行间隔
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        FRE_select   <=  3'b000;
    else    if(key1 == 1'b1)
	case(FRE_select)
	    FRE_ONE: FRE_select <= FRE_TWO;
		FRE_TWO: FRE_select <= FRE_THREE;
		FRE_THREE: FRE_select <= FRE_FOUR;
		FRE_FOUR: FRE_select <= FRE_FIVE;
		FRE_FIVE: FRE_select <= FRE_ONE;
	default : FRE_select <= FRE_ONE;
	endcase
    else
        FRE_select   <=  FRE_select;
		
//RAN:按键状态对应波形
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        RAN_select   <=  3'b000;
    else    if(key2 == 1'b1)
	case(RAN_select)
	    RAN_ONE: RAN_select <= RAN_TWO;
		RAN_TWO: RAN_select <= RAN_THREE;
		RAN_THREE: RAN_select <= RAN_ONE;
	default : RAN_select <= RAN_ONE;
	endcase
    else
        RAN_select   <=  RAN_select;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------- key_fifter_inst2 --------------
key_filter 
#(
    .CNT_MAX      (CNT_MAX  )       //计数器计数最大值
)
key_filter_inst2
(
    .sys_clk      (sys_clk  )   ,   //系统时钟50Mhz
    .sys_rst_n    (sys_rst_n)   ,   //全局复位
    .key_in       (key[2]   )   ,   //按键输入信号

    .key_flag     (key2     )       //按键消抖后标志信号
);

//------------- key_fifter_inst1 --------------
key_filter 
#(
    .CNT_MAX      (CNT_MAX  )       //计数器计数最大值
)
key_filter_inst1
(
    .sys_clk      (sys_clk  )   ,   //系统时钟50Mhz
    .sys_rst_n    (sys_rst_n)   ,   //全局复位
    .key_in       (key[1]   )   ,   //按键输入信号

    .key_flag     (key1     )       //按键消抖后标志信号
);

//------------- key_fifter_inst0 --------------
key_filter 
#(
    .CNT_MAX      (CNT_MAX  )       //计数器计数最大值
)
key_filter_inst0
(
    .sys_clk      (sys_clk  )   ,   //系统时钟50Mhz
    .sys_rst_n    (sys_rst_n)   ,   //全局复位
    .key_in       (key[0]   )   ,   //按键输入信号

    .key_flag     (key0     )       //按键消抖后标志信号
);

endmodule
