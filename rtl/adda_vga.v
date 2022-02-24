module  adda_vga
(
    input   wire            sys_clk     ,   //输入系统时钟,50MHz
    input   wire            sys_rst_n   ,   //输入复位信号,低电平有效
	input   wire    [2:0]   key         ,   //输入1位按键

    output  wire            i2c_scl     ,   //输出至i2c设备的串行时钟信号scl
    inout   wire            i2c_sda     ,   //输出至i2c设备的串行数据信号sda
    output  wire            stcp        ,   //输出数据存储寄时钟
    output  wire            shcp        ,   //移位寄存器的时钟输入
    output  wire            ds          ,   //串行数据输入
    output  wire            oe          ,   //使能信号
	output  wire            hsync       ,   //输出行同步信号
    output  wire            vsync       ,   //输出场同步信号
    output  wire    [15:0]  rgb             //输出像素信息
);

//************************************************************************//
//******************** Parameter and Internal Signal *********************//
//************************************************************************//
//parameter define
parameter    DEVICE_ADDR    =   7'h48           ;   //i2c设备地址
parameter    SYS_CLK_FREQ   =   26'd50_000_000  ;   //输入系统时钟频率
parameter    SCL_FREQ       =   18'd250_000   ;   //i2c设备scl时钟频率

//wire define
wire            vga_clk ;   //VGA工作时钟,频率25MHz
wire            locked  ;   //PLL locked信号
wire            rst_n   ;   //VGA模块复位信号
wire    [9:0]   pix_x   ;   //VGA有效显示区域X轴坐标
wire    [9:0]   pix_y   ;   //VGA有效显示区域Y轴坐标
wire    [15:0]  pix_data;   //VGA像素点色彩信息

wire            i2c_clk     ;   //i2c驱动时钟
wire            i2c_start   ;   //i2c触发信号
wire    [15:0]  byte_addr   ;   //i2c字节地址
wire            i2c_end     ;   //i2c一次读/写操作完成
wire    [ 7:0]  rd_data     ;   //i2c设备读取数据
wire    [ 7:0]  wr_data     ;   //输入i2c设备数据
wire    [19:0]  data        ;   //数码管待显示数据
wire            rd_en       ;   //读使能信号
wire            wr_en       ;   //写使能信号
wire    [2:0]   wave_select ;   //波形选择
wire    [2:0]   FRE_select  ;
wire    [1:0]   RAN_select  ;

wire    [9:0]	ram_rd_addr ;
wire    [7:0]   pic_data    ;    //自ROM读出的图片数据

//rst_n:VGA模块复位信号
assign  rst_n = (sys_rst_n & locked);

//------------- clk_gen_inst -------------
clk_gen clk_gen_inst
(
    .areset     (~sys_rst_n ),  //输入复位信号,高电平有效,1bit
    .inclk0     (sys_clk    ),  //输入50MHz晶振时钟,1bit
    .c0         (vga_clk    ),  //输出VGA工作时钟,频率25Mhz,1bit
    .locked     (locked     )   //输出pll locked信号,1bit
);

//------------- vga_ctrl_inst -------------
vga_ctrl  vga_ctrl_inst
(
    .vga_clk    (vga_clk    ),  //输入工作时钟,频率25MHz,1bit
    .sys_rst_n  (rst_n      ),  //输入复位信号,低电平有效,1bit
    .pix_data   (pix_data   ),  //输入像素点色彩信息,16bit

    .pix_x      (pix_x      ),  //输出VGA有效显示区域像素点X轴坐标,10bit
    .pix_y      (pix_y      ),  //输出VGA有效显示区域像素点Y轴坐标,10bit
    .hsync      (hsync      ),  //输出行同步信号,1bit
    .vsync      (vsync      ),  //输出场同步信号,1bit
    .rgb        (rgb        )   //输出像素点色彩信息,16bit
);

//------------- vga_pic_inst -------------
vga_wave_pic vga_wave_pic_inst
(
    .vga_clk        (vga_clk    ),  //输入工作时钟,频率25MHz,1bit
    .sys_rst_n      (rst_n      ),  //输入复位信号,低电平有效,1bit
    .pix_x          (pix_x      ),  //输入VGA有效显示区域像素点X轴坐标,10bit
    .pix_y          (pix_y      ),  //输入VGA有效显示区域像素点Y轴坐标,10bit
	.pic_data       (pic_data   ),
	.FRE_select     (FRE_select ),
	.RAN_select     (RAN_select ),

    .pix_data_out   (pix_data   ),   //输出像素点色彩信息,16bit
    .ram_rd_addr    (ram_rd_addr)
);

adda_ctrl  adda_ctrl_inst
(
  .sys_clk     (i2c_clk    ),
  .sys_rst_n   (sys_rst_n  ),
  .i2c_end     (i2c_end    ),
  .rd_data     (rd_data    ),
  .wave_select (wave_select),
  
  .vga_clk     (vga_clk    ),  //输入工作时钟,频率25MHz,1bit
  .ram_rd_addr (ram_rd_addr),
  
  
  .rd_en       (rd_en      ),
  .wr_en       (wr_en      ),
  .i2c_start   (i2c_start  ),
  .byte_addr   (byte_addr  ),
  .wr_data     (wr_data    ),  //输入i2c设备数据
  .po_data     (data       ),
  .pic_data    (pic_data   )
  
);

i2c_ctrl
#(
    .DEVICE_ADDR    (DEVICE_ADDR    ),  //i2c设备器件地址
    .SYS_CLK_FREQ   (SYS_CLK_FREQ   ),  //i2c_ctrl模块系统时钟频率
    .SCL_FREQ       (SCL_FREQ       )   //i2c的SCL时钟频率
)
i2c_ctrl_inst
(
    .sys_clk        (sys_clk        ),  //输入系统时钟,50MHz
    .sys_rst_n      (sys_rst_n      ),  //输入复位信号,低电平有效
    .rd_en          (rd_en          ),
    .wr_en          (wr_en          ),
    .i2c_start      (i2c_start      ),  //输入i2c触发信号
    .addr_num       (1'b0           ),  //输入i2c字节地址字节数
    .byte_addr      (byte_addr      ),  //输入i2c字节地址
    .wr_data        (wr_data        ),  //输入i2c设备数据

    .rd_data        (rd_data        ),  //输出i2c设备读取数据
    .i2c_end        (i2c_end        ),  //i2c一次读/写操作完成
    .i2c_clk        (i2c_clk        ),  //i2c驱动时钟
    .i2c_scl        (i2c_scl        ),  //输出至i2c设备的串行时钟信号scl
    .i2c_sda        (i2c_sda        )   //输出至i2c设备的串行数据信号sda
);

seg_595_dynamic     seg_595_dynamic_inst
(
    .sys_clk    (sys_clk    ),  //系统时钟，频率50MHz
    .sys_rst_n  (sys_rst_n  ),  //复位信号，低有效
    .data       (data       ),  //数码管要显示的值
    .point      (6'b001000  ),  //小数点显示,高电平有效
    .seg_en     (1'b1       ),  //数码管使能信号，高电平有效
    .sign       (1'b0       ),  //符号位，高电平显示负号

    .stcp       (stcp       ),   //输出数据存储寄时钟
    .shcp       (shcp       ),   //移位寄存器的时钟输入
    .ds         (ds         ),   //串行数据输入
    .oe         (oe         )    //使能信号
);

key_control key_control_inst
(
    .sys_clk        (sys_clk    ),   //系统时钟,50MHz
    .sys_rst_n      (sys_rst_n  ),   //复位信号,低电平有效
    .key            (key        ),   //输入4位按键

    .wave_select    (wave_select),    //输出波形选择
    .FRE_select     (FRE_select ),
	.RAN_select     (RAN_select )
 );

endmodule

