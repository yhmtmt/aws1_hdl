`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/03/10 08:56:43
// Design Name: 
// Module Name: awsctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// This module controls ADC and four DPs via SPI interface. This module is interfaced with processing system 7 via a AXI GPIO with 2 channels ctri_i and ctrl_o.
// ctrl_i delivers four channel ADC values to processing system 7. Each ADC value is actually of 12bit but the value is packed as 8bit in ctrl_i.
// The four 8bit values packed in the ctrl_i are rudder control, main engine control, sub engine control, and rudder angle indication:
//
//   ctrl_i = | rudder c | main eng | sub eng | rudder i|
//           MSB                                       LSB
// 
// The values of ctrl_o is to be sat at each digital potentiometers (DPs). The bit layout is the same as ctrl_i.
// 
//   ctrl_o = | rudder c | main eng | sub eng | rudder i|
//           MSB                                       LSB
//
// The filter f_aws1_ctrl of aws  switches contrl source between remote controller connected to ADC and aws.
//     

// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module awsctrl(
    ctrl_val,
    sclk,
    sdi,
    sdo,
    cs_n,
    rst_n,
    );
    input [23:0] ctrl_val;
    input sclk;
    input sdi;
    output sdo;
    output [2:0] cs_n;
    input rst_n;
    
    wire [2:0] s_sdo;
    reg [2:0] r_se;
    reg [3:0] r_cnt;
    
    dp_set dp_set_0(.rst_n(rst_n), 
                    .se(r_se[0]), 
                    .vec(ctrl_val[7:0]), 
                    .sclk(sclk), 
                    .sdo(s_sdo[0]), 
                    .cs_n(cs_n[0]));

    dp_set dp_set_1(.rst_n(rst_n), 
                    .se(r_se[1]), 
                    .vec(ctrl_val[15:8]), 
                    .sclk(sclk), 
                    .sdo(s_sdo[1]), 
                    .cs_n(cs_n[1])); 

    dp_set dp_set_2(.rst_n(rst_n), 
                    .se(r_se[2]), 
                    .vec(ctrl_val[23:16]), 
                    .sclk(sclk), 
                    .sdo(s_sdo[2]), 
                    .cs_n(cs_n[2]));
                    
    assign sdo = (r_se == 3'b001 ? s_sdo[0] : 
                    (r_se == 3'b010 ? s_sdo[1] :
                    (r_se == 3'b100 ? s_sdo[2] : 1'b0)));
                                                     
    always @(posedge sclk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
           r_se <= 3'b001;
           r_cnt <= 4'd0; 
        end else begin            
            if(r_cnt == 4'd9) begin
                r_cnt <= 4'd0;
            end else begin
                r_cnt <= r_cnt + 4'd1;
            end

            case(r_se)            
            3'b001: begin
                if(r_cnt == 4'd9) begin
                    r_se <= 3'b010;
                end
            end
            
            3'b010: begin
                if(r_cnt == 4'd9) begin
                    r_se <= 3'b100;
                end
            end
            
            3'b100: begin
                if(r_cnt == 4'd9) begin
                    r_se <= 3'b001;
                end           
            end
            endcase
        end
    end
    
endmodule
