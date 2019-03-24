`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/03/10 08:38:23
// Design Name: 
// Module Name: awstm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// This module synchronize aws timer event to pps signal given from GPS reciever. The communication with processing system 7 is conducted by a two-channel axi-gpio module.
// * Time difference between PPS signal and internal clock in the number of cycle is calucalated.
// * The time difference is then corrected one cycle in a certain period which is exponentially changed depending on the magnitude of the time differend.
// * If the PPS signal is not asserted within 1.5sec, the module regards that the GPS was lost and the time event is issued according to the internal clock..
// * The timer event interval is given as tevt in the number of cycles. The timer evt is sent as evt. The MSB of the evt is "lock" flag which indicates the pps signal is locked.
//   The remained 31bits in evt is the time upto 10sec (1Gcycle). 
//    
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module awstm(
        pps,
        tevt,
        evt,
        rst_n,
        clk
    );
    input pps;
    input [31:0] tevt;
    output [31:0] evt;
    input rst_n;
    input clk;
    
    reg r_pps, r_awspps;
    reg [26:0] r_tcyc;      // counts 1 second by fclk0. this counts until pps signal rises or p_pps_to reached.
    reg [26:0] r_td;        // time difference between GPS's pps and 1sec by our system clock.  
    reg [30:0] r_awstm;     // counts 10 seconds by fclk0. The timer event is sent when the value reached at r_tmev_next.
    reg [30:0] r_tmev_next; // The next r_awstm the event to be sent.The value is updated when the event is issued not to exceed the value p_awstm_max.
                            // Actually r_tmev_next may exceed p_awstm_max the cycle just after theevent sent. The value is corrected less than p_awstm_max immediately after the cycle. 
    reg [30:0] r_set_tmev; // This is used for event notification. The value is sent to axi_gpio named tmev and trigger the interrupt.
    reg [10:0] r_tcor;      // The counter counts the cycles after correcting awstime. When the counter reached r_tcor_max, correction with 1 cycle is carried out.
    reg [10:0] r_tcor_max;  // r_tcor_max is varied as min(2^(28 - log2(r_td)), 2^10)
    reg r_pps_lock;         // A flag specifies the time is locked or not by pps signal. The circuit determines it as unlocked when the r_tcyc is reached p_evt_to.
                            // This is packed at the MSB of the tmev event notification.
                            
    wire evt_pps;           // rising event of the pps signal
                             
    parameter [26:0] p_cyc_per_sec  = 27'd99_999_999;  // The number of cycles in a second. (assuming fclk0 is 100Mhz)
    parameter [26:0] p_pps_to       = 27'd149_999_999; // The number of cycles determines that the pps is not locked.. (1.5sec) 
    parameter [30:0] p_awstm_max    = 31'd999_999_999;  // Maximum of the awstm sat at 10sec. ( aws is allowed to set its cycle time less than 10 sec.)
    assign evt = r_set_tmev;
    assign evt_pps = pps & ~r_pps;

    /////////////////////// calcurating r_tcor_max  /////////////////////
    // Finary in tmp_tcor_max, the value set to r_tcor_max is calcurated.
    // The value is set at min(2^(28 - log2(r_td)), 2^10).
    wire [26:0] td_abs;
    wire [25:0] tmp1_td_abs;
    wire [25:0] tmp2_td_abs;
    wire [10:0] tmp_tcor_max;
    
    // absolute value of r_td is calcurated
    assign td_abs = (r_td[26] ? (~r_td + 17'd1): r_td);
    
    genvar i;
    
    // tmp1_td_abs fills 1 below the msb of the value stored in td_abs; td_abs => 0000010100110 , tmp1_td_abs=>0000011111111
    assign tmp1_td_abs[25] = td_abs[25]; // Note that we do not have effective value in td_abs[26], because the bit was used as sign in r_td. 
    generate 
        for(i = 24; i >= 0; i=i-1) begin :g_tmp1_td_abs
            assign tmp1_td_abs[i] = td_abs[i+1] | td_abs[i];  
        end 
    endgenerate
  
    // tmp2_td_abs determine the boundary in tmp1_td_abs as 1; tmp1_td_abs=>0000011111111, tmp2_td_abs=>0000010000000
    assign tmp2_td_abs[25] = tmp1_td_abs[25];
    generate
        for(i = 24; i >= 0; i=i-1) begin: g_tmp2_td_abs
            assign tmp2_td_abs[i] = tmp1_td_abs[i+1] ^ tmp1_td_abs[i];
        end
    endgenerate
    
    // Now we set tmp_tcor_max by inversely filling from the lsb by the values from msb of tmp2_td_abs.
    // We assume 2^28 cycles for correcting the r_td, and r_td is 2^25bits. Therefore, we offset the filling position 28-25=3bits left from the lsb.   
    assign tmp_tcor_max[2:0] = 3'b000;
    generate 
        for(i = 0; i < 7; i=i+1) begin: g_tmp_tcor_max
            assign tmp_tcor_max[i+3] = tmp2_td_abs[25-i]; 
        end
    endgenerate
    assign tmp_tcor_max[10] = (tmp1_td_abs[20] & !tmp2_td_abs[20] ? 1'b0 : 1'b1); 
    /////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            r_pps <= 1'b0;
            r_awspps <= 1'b0;
            r_pps_lock <= 1'b0;
            
            r_tcyc <= 27'd0;
            r_td <= 27'd0;
            r_tcor <= 11'd0;
            r_tcor_max <= 11'd1024;
            
            r_awstm <= 31'd0;
            r_tmev_next <= 31'd0;
            r_set_tmev <= 31'd0;
        end else begin
            r_pps <= pps;
            r_tcyc <= r_tcyc + 1;
            r_tcor_max <= tmp_tcor_max;
             
            if(r_tcor >= r_tcor_max) begin
                r_tcor <= 10'd0;
            end else begin
                r_tcor <= r_tcor + 1;
            end
            
            if(r_tcyc == p_cyc_per_sec) begin
                r_awspps <= 1'b1;
            end else begin
                r_awspps <= 1'b0;
            end
                        
            if(evt_pps) begin
                r_pps_lock <= 1'b1;
                r_tcyc <= 27'd0;
                r_td <= r_td + p_cyc_per_sec + ~r_tcyc + 27'd1;
            end else begin
                if(r_tcyc == p_pps_to) begin // pps time out, we regard this as gps is not locked the time
                    r_pps_lock <= 1'b0;
                    r_tcyc <= (p_pps_to - p_cyc_per_sec);     
                end                
            end
            
            if(r_awstm >= p_awstm_max) begin
                r_awstm <= 31'd0;
            end else begin
                if(r_tcor == r_tcor_max) begin
                    if(r_td[26]) begin // negative delay
                        r_awstm <= r_awstm;
                        r_td <= r_td + 27'd1;
                    end else begin // positive delay
                        r_awstm <= r_awstm + 31'd2;
                        r_td <= r_td - 27'd1;
                    end
                end else begin
                    r_awstm <= r_awstm + 31'd1;
                end
            end
            
            // event sent to the gpio tmev. (Note that the r_awstm value can exceed r_tmev_next by 1 because of the time correction.)
            if(r_tmev_next == r_awstm || (r_tmev_next + 31'd1) == r_awstm) begin
                r_set_tmev <= {r_pps_lock, r_awstm};
                r_tmev_next <= r_tmev_next + tevt;
            end

            // corrects the next event time if the r_tmev_next is larger than the maximum.            
            if(r_tmev_next > p_awstm_max) begin
                r_tmev_next <= r_tmev_next + ~p_awstm_max + 31'd1;
            end             
        end
    end
    
endmodule
