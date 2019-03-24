`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2015/12/30 15:11:13
// Design Name: 
// Module Name: dp_set
// Project Name: 
// Target Devices: AD5160
// Tool Versions: 
// Description: Set dp's value via spi if the value was changed.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// To use the module, se should be asserted for 9 cycle for a single session.
// In a single session, SPI write operation is invoked if the vec has been changed from the previous session.
// Otherwise, the module does not carry out any operation. 
module dp_set(
    input rst_n,     // reset signal 
    input [7:0] vec, // input vector
    input se,   // select signal enables dp update cycle
    input sclk, // spi clock
    output sdo, // spi data out
    output cs_n // spi chip select
    );
    
    reg [7:0] r_sdo;
    reg [2:0] r_cnt;
    reg r_cs_n;
    reg r_done;
    parameter val_dev = 8'h7f;
    
    assign cs_n = r_cs_n;
    assign sdo = r_sdo[7]; 
    always @(negedge sclk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            r_sdo <= val_dev;
            r_cs_n <= 1'b1;
            r_cnt <= 3'd0;
            r_done <= 1'b0;
        end else begin
        // A session begins with assertion of se.
        // Value is checked only once in a session.
        // When the value given as vec was changed, dp's value should be changed, so r_cs_n is asserted.
        // Otherwise, the session moves to "done state" immediately. 
        // In the case changing dp's value , SPI write operation takes 8 cycle, 
        // Then the session moves to "done state" and the r_cs_n is deasserted.
        // Finally the session ends by deasserting se, and then the "done state" register is initiated. 
            if(se == 1'b1) begin
                if(r_done == 1'b0) begin
                    if(r_cs_n == 1'b1) begin
                        // initial decision
                        r_sdo <= vec;
                        // then counter and the r_cs_n are initiated.
                        r_cnt <= 3'd0;
                        r_cs_n <= 1'b0;
                    end else begin
                        // this process takes 8 cycles.
                        if(r_cnt == 3'd7) begin
                            // in 8th cycle, done flag is asserted, and r_cs_n is deasserted
                            r_cs_n <= 1'b1;
                            r_done <= 1'b1;
                        end 
                        // counting up
                        r_cnt <= r_cnt + 1;
                        
                        // shifting output register.
                        r_sdo[7:1] <= r_sdo[6:0];
                        r_sdo[0] <= 1'b0; 
                    end
                end
            end else begin
                // when the session is not active, done flag is deasserted. 
                r_done <= 1'b0;
            end
        end 
    end
endmodule
