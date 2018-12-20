module couter_down_24_seconds(clk, rst, start, LED, digit_seg, digit_cath);
input clk, rst, start;
output LED;
output [7:0] digit_seg;
output [1:0] digit_cath;

wire clk_2;
wire BTN_pulse;
wire flag;

wire [3:0] code1;
wire [3:0] code0;
wire finnal_flag;
wire bell_code;
assign finnal_flag = {code1,code0}==0? 0:1;
flash u_flash(.clk_2(clk_2), .rst(rst), .finnal_flag(finnal_flag), .switch(LED), .bell_code(bell_code));
flag_control u_flag(.clk(clk), .rst(rst), .BTN_pulse(BTN_pulse), .flag(flag)); 

seg_scan decode(.clk_50M(clk),.rst_button(rst), .switch({code1,code0}), .digit_seg(digit_seg), .digit_cath(digit_cath));

debounce #(.N(7)) u_debounce(
    .clk(clk),
    .rst(rst),
    .key(~start),
    .key_pulse(BTN_pulse));

frequency_divider #(.N(24999999)) u_clk_2(
    .clkin(clk),
    .clkout(clk_2)
    );
sequencer u_se(.clk(clk_2), .rst(rst), .flag(flag), .code1(code1), .code0(code0));

endmodule

module sequencer(clk, rst, flag, code1, code0);
input clk;
input rst;
input flag;
output reg [3:0] code1;
output reg [3:0] code0;
initial
begin
    code1=2;
    code0=4;
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // reset
        code1<=2;
        code0<=4;
    end
    else if (flag==1) begin
            if (code1==0 & code0==0) begin
                    code1<=code1;
                    code0<=code0;
            end
            else begin
                if (code1==0) begin
                    code1<=code1;
                    code0<=code0-1;
                end
                else if (code0==0) begin
                    code1<=code1-1;
                    code0<=9;
                end
                else begin
                    code1<=code1;
                    code0<=code0-1;             
                end
            end
    end
    else begin
        code1<=code1;
        code0<=code0;
    end
    
end
endmodule
module flag_control(clk, rst, BTN_pulse, flag);
input clk;
input rst;
input BTN_pulse;
output reg flag;
initial begin
flag=0;
end

always @(posedge clk or posedge rst ) begin
    if (rst) begin
        // reset
        flag <= 0;
    end
    else if (BTN_pulse) begin
        flag<=1;
    end

    else begin
        flag<=flag;
    end
end

endmodule


module seg_scan(clk_50M,rst_button, switch, digit_seg, digit_cath);
input clk_50M; //板载50M晶振
input rst_button;
input [7:0] switch;
output reg [7:0] digit_seg; //七段数码管的段选端
output [1:0] digit_cath; //2个数码管的片选端
wire reset; //复位按键
assign reset = rst_button;

//计数分频，通过读取32位计数器div_count不同位数的上升沿或下降沿来获得频率不同的时钟
reg [31:0] div_count;
always @(posedge clk_50M,posedge reset)
begin
    if(reset)
        div_count <= 0;   //如果按下复位按键，计数清零
    else
        div_count <= div_count + 1;
end

//拨码开关控制数码管显示，每4位拨码开关控制一个七段数码管
wire [7:0] digit_display;
assign digit_display = switch;

wire [3:0] digit;
always @(*)      //对所有信号敏感
begin
    case (digit)
        4'h0:  digit_seg <= 8'b11111100; //显示0~F
        4'h1:  digit_seg <= 8'b01100000;   
        4'h2:  digit_seg <= 8'b11011010;
        4'h3:  digit_seg <= 8'b11110010;
        4'h4:  digit_seg <= 8'b01100110;
        4'h5:  digit_seg <= 8'b10110110;
        4'h6:  digit_seg <= 8'b10111110;
        4'h7:  digit_seg <= 8'b11100000;
        4'h8:  digit_seg <= 8'b11111110;
        4'h9:  digit_seg <= 8'b11110110;
        4'hA:  digit_seg <= 8'b11101110;
        4'hB:  digit_seg <= 8'b00111110;
        4'hC:  digit_seg <= 8'b10011100;
        4'hD:  digit_seg <= 8'b01111010;
        4'hE:  digit_seg <= 8'b10011110;
        4'hF:  digit_seg <= 8'b10001110;
    endcase
end

//通过读取32位计数器的第10位的上升沿得到分频时钟，用于数码管的扫描
reg segcath_holdtime;
always @(posedge div_count[10], posedge reset)
begin
if(reset)
     segcath_holdtime <= 0;
else
     segcath_holdtime <= ~segcath_holdtime;
end

//7段数码管位选控制
assign digit_cath ={segcath_holdtime, ~segcath_holdtime};
// 相应位数码管段选信号控制
assign digit =segcath_holdtime ? digit_display[7:4] : digit_display[3:0];

endmodule

module debounce (clk,rst,key,key_pulse);
 
        parameter       N  =  1;                      //要消除的按键的数量
 
    input             clk;
        input             rst;
        input   [N-1:0]   key;                        //输入的按键                   
    output  [N-1:0]   key_pulse;                  //按键动作产生的脉冲   
 
        reg     [N-1:0]   key_rst_pre;                //定义一个寄存器型变量存储上一个触发时的按键值
        reg     [N-1:0]   key_rst;                    //定义一个寄存器变量储存储当前时刻触发的按键值
 
        wire    [N-1:0]   key_edge;                   //检测到按键由高到低变化是产生一个高脉冲
 
        //利用非阻塞赋值特点，将两个时钟触发时按键状态存储在两个寄存器变量中
        always @(posedge clk  or  posedge rst)
          begin
             if (rst) begin
                 key_rst <= {N{1'b1}};                //初始化时给key_rst赋值全为1，{}中表示N个1
                 key_rst_pre <= {N{1'b1}};
             end
             else begin
                 key_rst <= key;                     //第一个时钟上升沿触发之后key的值赋给key_rst,同时key_rst的值赋给key_rst_pre
                 key_rst_pre <= key_rst;             //非阻塞赋值。相当于经过两个时钟触发，key_rst存储的是当前时刻key的值，key_rst_pre存储的是前一个时钟的key的值
             end    
           end
 
        assign  key_edge = key_rst_pre & (~key_rst);//脉冲边沿检测。当key检测到下降沿时，key_edge产生一个时钟周期的高电平
 
        reg [17:0]    cnt;                       //产生延时所用的计数器，系统时钟12MHz，要延时20ms左右时间，至少需要18位计数器     
 
        //产生20ms延时，当检测到key_edge有效是计数器清零开始计数
        always @(posedge clk or posedge rst)
           begin
             if(rst)
                cnt <= 18'h0;
             else if(key_edge)
                cnt <= 18'h0;
             else
                cnt <= cnt + 1'h1;
             end  
 
        reg     [N-1:0]   key_sec_pre;                //延时后检测电平寄存器变量
        reg     [N-1:0]   key_sec;                    
 
 
        //延时后检测key，如果按键状态变低产生一个时钟的高脉冲。如果按键状态是高的话说明按键无效
        always @(posedge clk  or  posedge rst)
          begin
             if (rst) 
                 key_sec <= {N{1'b1}};                
             else if (cnt==18'h3ffff)
                 key_sec <= key;  
          end
       always @(posedge clk  or  posedge rst)
          begin
             if (rst)
                 key_sec_pre <= {N{1'b1}};
             else                   
                 key_sec_pre <= key_sec;             
         end      
       assign  key_pulse = key_sec_pre & (~key_sec);     
       initial
       begin
        cnt<=0;
        key_rst<=0;
        key_rst_pre<=0;
        key_sec_pre<=0;
        key_sec<=0;
       end
 
endmodule


module frequency_divider(clkin, clkout);
parameter N = 1;
input clkin;
output reg clkout;
reg [27:0] cnt;
initial 
begin
cnt<=0;
clkout<=0;
end
always @(posedge clkin) begin
    if (cnt==N) begin
        clkout <= !clkout;
        cnt <= 0;
    end
    else begin
        cnt <= cnt + 1;
    end
end
endmodule

module flash(clk_2, rst, finnal_flag, switch, bell_code);
input clk_2;
input rst;
input finnal_flag;
output reg switch;
output reg [2:0] bell_code;
reg [2:0] cnt;
initial
begin
    switch<=1;
    cnt<=0;
    bell_code<=0;
end

always @(posedge clk_2 or posedge rst) begin
    if (rst) begin
        // reset
        switch<=1;
        cnt<=0;
    end
    else if (finnal_flag==0 &cnt<6) begin
        switch<=~switch;
        cnt<=cnt+1;
    end
    else if (cnt==6) begin
        switch<=1;
        cnt<=7;
    end
    else begin
        switch<=switch;
    end
end

always @(posedge clk_2) begin
    case(cnt)
    0:begin
        bell_code<=0;
    end
    1:begin
        bell_code<=1;
    end
    2:begin
        bell_code<=2;
    end
    3:begin
        bell_code<=3;
    end
    4:begin
        bell_code<=4;
    end
    5:begin
        bell_code<=5;
    end
    6:begin
        bell_code<=6;
    end
    default:begin
        bell_code<=0;
    end
    endcase
end
endmodule