clc
clear
%% 程序说明
% 考虑到USB-CAN采集并保存的CAN报文无法通过dbc文件解析，本程序的作用是将所采集的离线数据解析，得到其物理含义
% 目前是v1版本，输入为dbc文件、Message的地址、Message的报文以及dbc文件的编写格式
% 作者 ： 燕山大学智能运载装备研究所  方睿祺
% Version 1 只能实现单个报文的解析 2022.07.18
%% 输入
Address = input('请输入Message的地址，输入10进制数，如输入308:  ')   % 获取地址
Telegram = input('请输入Message的报文，如16 07 08 02 22 39 3C 00:  ','s')   % 获取报文
Telegram(isspace(Telegram)) = [];  %把字符串的空格删去
candb = canDatabase('RAC-C1P.dbc');%读dbc文件
% 首先判断Dbc文件是Intel还是Mortorla格式，注释掉其中一个
CAN_Format = 'Intel';
% CAN_Format = 'Motorola';
%% 处理所有的Message   ——   Message_Containers
Struct_Dbc = {};
Number_Struct_Con = [];
for i = 1:length(candb.Messages)
    Message_Containers{1,i} = candb.Messages(i);  % 存放Messages
    Message_Containers{2,i} = candb.MessageInfo(i).ID;  % 存放16进制
    Message_Containers{3,i} = eval(dec2hex(Message_Containers{2,i}));  % 转换成10进制
    % 得到Message_Containers元胞数组，第一行存放Message 第二行存放16进制地址 第三行存放10进制地址
    Signal_Containers_struct{1,i} = candb.MessageInfo(i).SignalInfo;
    Number_Struct(i) = length(Signal_Containers_struct{i}); % 得到每个Message下面有多少个Signal的向量
    Number_Struct1 = Number_Struct(i); % 提取出每个Signal向量
    %     for j = 1:length(Number_Struct)
    %         Struct_Dbc_1 =  struct2cell(Signal_Containers_struct{1,j});
    %         Struct_Dbc_2 = [Struct_Dbc_2,Struct_Dbc_1];
    %     end
    %     Struct_Dbc = [Struct_Dbc,Struct_Dbc_2]; %将所有的Signal展开，方便调用
end
%% 展开得到所有的Signal   ——   Struct_Dbc
for j = 1:length(Number_Struct)
    Struct_Dbc_1 =  struct2cell(Signal_Containers_struct{1,j});
    Struct_Dbc = [Struct_Dbc,Struct_Dbc_1];
end
%% 处理地址和报文   ——   匹配主程序main
% 得到Signal地址在Message_Containers中的ID，就可以在Struct_Dbc中操作
for i = 1:length(Message_Containers)
    if Address == Message_Containers{2,i}
        Address_Message_ID = i;
    end
end
% 取出在Struct_Dbc中的同一地址下的相关列,Start和End的列数，接下来通过调用Start和End锁定要解析的Signal范围
if Address_Message_ID == 1
    Start_Address_Message_ID = 1;
    End_Address_Message_ID = sum(Number_Struct(1:Address_Message_ID));
else
    Start_Address_Message_ID = sum(Number_Struct(1:Address_Message_ID-1))+1;
    End_Address_Message_ID = sum(Number_Struct(1:Address_Message_ID));
end
% 将报文分配给每个字节，在Struct_Dbc中的第21行和22行得到起始位和终止位
for t = 1:size(Struct_Dbc,2)
    Start_Byte = Struct_Dbc{3,t}/4;
    Struct_Dbc{21,t} = Start_Byte+1;
    %     Start_Byte_Con = [Start_Byte_Con Start_Byte(i)];
    End_Byte =  Start_Byte+Struct_Dbc{4,t}/4;
    Struct_Dbc{22,t} = End_Byte;
    %     End_Byte_Con = [End_Byte_Con End_Byte(i)];
end
Signal_Analysis_out = [];
Signal_Name_Out = {};
Unit_Out = {};
% 遍历索引
for t = Start_Address_Message_ID:End_Address_Message_ID
    Factor = Struct_Dbc{9,t}; % 第9行的factor
    Offset = Struct_Dbc{10,t}; % 第10行的offset
    Start = Struct_Dbc{21,t}; % 第21行的起始位
    End = Struct_Dbc{22,t};  % 第22行的终止位
    %按照Start和End取出报文
    Signal_Name_Out = [Signal_Name_Out,Struct_Dbc{1,t}];
    Unit_Out = [Unit_Out,Struct_Dbc{13,t}];
    % 判断模式是Intel还是Motorola
    if CAN_Format == 'Intel'
        % 将16进制转化成10进制，其中涉及到了元素的交换
        %比如说：12 34 56 78 ,要换成 78 56 34 12
        Telegram1 = reverse(Telegram(Start:End));
        for n = 1:2:End-Start
            x = Telegram1(n);
            Telegram1(n) = Telegram1(n+1);
            Telegram1(n+1) = x;
        end
    else
        Telegram1 = Telegram;
    end
    % 10进制计算
    Signal_Analysis = hex2dec(Telegram1) * Factor + Offset;
    Signal_Analysis_out = [Signal_Analysis_out Signal_Analysis];
end
%% 输出
Signal_Analysis_out = num2cell(Signal_Analysis_out);
Signal_Out = struct('Signal_Name',Signal_Name_Out,'Value',Signal_Analysis_out,'Unit',Unit_Out);