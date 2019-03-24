`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/01/07 21:53:08
// Design Name: 
// Module Name: adc_get
// Project Name: 
// Target Devices: MCP3204
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Session starts with assertion of se  with a specified channel
// At the first negative edge of sclk, cs is asserted simultaneously with start bit.
// And, { x, ch[1], ch[0]} follows.
// At the forth positive edge after sending ch[0], 12bit data comes with MSB first manner.
// At the negative edge after capturing 12bit, cs is deasserted and the vec is on the output.
// Session ends with deassertion of se. vec outputs values obtained in the previous session.
// 
// Note that, the session completes after counting 20 negative edges
// 
module adc_get(
    input rst_n,
    input se,
    input [1:0] ch,
    input sclk,
    input sdi,
    output sdo,
    output cs_n,
    output [11:0] vec
    );
    
    reg [11:0] r_vec;
    reg [4:0] r_cmd;
    reg [4:0] r_cnt;
    reg r_cs_n;
    reg r_done;
    reg r_de;
    assign cs_n = r_cs_n;
    assign sdo = r_cmd[4];
    always @(negedge sclk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            r_cs_n <= 1'b1;
            r_cmd <= 5'b00000;
            r_cnt <= 5'd0;
            r_done <= 1'b0;
            r_de <= 1'b0;
        end else begin
            if(se == 1'b1) begin
                if(r_done == 1'b0) begin
                    if(r_cs_n == 1'b1) begin
                        r_cs_n <= 1'b0;
                        r_cmd <= {3'b110, ch}; // {start bit, single channel flag, don't care, channel index}
                        r_cnt <= 5'd0; 
                        r_de <= 1'b0;
                    end else begin
                        r_cmd[4:1] <= r_cmd[3:0];
                        r_cmd[0] <= 1'b0;
                    
                        r_cnt <= r_cnt + 1;
                        if(r_cnt == 5'd6) begin
                            r_de <= 1'b1;
                        end else if(r_cnt == 5'd18) begin
                            r_de <= 1'b0;
                            r_done <= 1'b1;
                            r_cs_n <= 1'b1;
                        end 
                    end
                end
            end else begin
                r_done <= 1'b0;
            end 
        end
    end
    
    assign vec = r_vec;
    always @(posedge sclk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            r_vec <= 12'd0;
        end else begin
            if(se == 1'b1) begin
                if(r_done == 1'b0) begin
                    if(r_de == 1'b1) begin
                        r_vec[0] <= sdi;
                        r_vec[11:1] <= r_vec[10:0];
                    end
                end
            end 
        end
    end
    
endmodule
