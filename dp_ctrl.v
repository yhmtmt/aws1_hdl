`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yohei Matsumoto
// 
// Create Date: 2015/12/16 11:10:47
// Design Name: 
// Module Name: dp_ctrl
// Project Name: 
// Target Devices: 
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

module dp_ctrl(
    input rst_n,
    input sclk,
    input sdi,
    output sdo,
    output [2:0] cs_n,
    input eoc,
    input dor_n,
    input aws_ctrl, 
    output [7:0] ap_rud_inst,
    output [7:0] ap_rud_stat,
    output [7:0] ap_eng_r_inst,
    output [7:0] ap_eng_l_inst,
    input [7:0] aws_rud_inst,
    input [7:0] aws_eng_r_inst,
    input [7:0] aws_eng_l_inst
    );
          
    // Chip Select
    parameter cs_none       = 3'b111;
    parameter cs_adc        = 3'b000;
    parameter cs_rud_inst   = 3'b001;
    parameter cs_rud_stat   = 3'b010;
    parameter cs_eng_r_inst = 3'b011;
    parameter cs_eng_l_inst = 3'b100;
    reg [2:0] r_cs_n;
    assign cs_n = r_cs_n;
    
    // Control source (true -> aws, false -> analog potentiometer) 
    reg r_aws_ctrl;
    
    // States and the register. 
    parameter s_init_0  = 5'b00001;
    parameter s_init_1  = 5'b00010;
    parameter s_rstat   = 5'b00100;
    parameter s_conv    = 5'b01000;
    parameter s_wdp     = 5'b10000;
    reg [4:0] r_stat;
    
    // Counter and parameter for determining timeout.
    parameter p_init_to = 13'd5000; 
    reg [12:0] r_cnt_init_to; 

    // init_0 related variables    
    reg r_adc_auto_cal_inst;    // Asserted when AutoCal instruction is released to the SPI output buffer.
    
    // init_1 related variables
    reg r_dp_init;              // Asserted when all the DPs initialized.
    reg [1:0] r_dp_idx;         // Index of the currently selected DP. (This is also used in wdp state)
    
    // rstat related variable
    reg r_adc_stat_inst;
    reg [7:0] r_adc_stat;
    
    // SPI sending/recieving 
//    parameter i_adc_auto_cal    = 8'b00010000;
//    parameter i_adc_stat        = 8'b00110000;
//    parameter i_cnv_ch0         = 8'b00000000;
//    parameter i_cnv_ch1         = 8'b00000011;
//    parameter i_cnv_ch2         = 8'b00001001;
//    parameter i_cnv_ch3         = 8'b00001011;
    parameter i_adc_auto_cal    = 8'b00001000;
    parameter i_adc_stat        = 8'b00001100;
    parameter i_cnv_ch0         = 8'b10000000;
    parameter i_cnv_ch1         = 8'b11000000;
    parameter i_cnv_ch2         = 8'b10010000;
    parameter i_cnv_ch3         = 8'b11010000;
    reg [7:0] r_sdo_word;
    reg [12:0] r_sdi_word;
    reg [3:0] r_sdi_cnt;
    reg [3:0] r_sdo_cnt;
    reg [3:0] r_inst_intvl;
    reg r_adc_cnv_inst;
    
    // Potentiometer's neutral values (default 128)
    parameter rud_neutral = 8'hfe;
    parameter eng_neutral = 8'hfe;
   
    // register for storing positions of four analog potentiometers through ADC 
    reg [7:0] r_ap_rud_inst;    // instructed rudder angle 
    reg [7:0] r_ap_rud_stat;    // rudder status
    reg [7:0] r_ap_eng_r_inst;  // instructed throttle/crutch for sub engine
    reg [7:0] r_ap_eng_l_inst;  // instructed throttle/crutch for main engine
         
    assign ap_rud_inst = r_ap_rud_inst;
    assign ap_rud_stat = r_ap_rud_stat;
    assign ap_eng_l_inst = r_ap_eng_l_inst;
    assign ap_eng_r_inst = r_ap_eng_r_inst;
    
    
    // loading ADC 
    // note that the ADC's value is MSB first 13bit signed value. (below) 
    //   12  .....   1      0
    // |LSB| .... | MSB | Sign |
    // 
    // We only use 8bit from its MSB. So the next adc_val is defined in LSD first manner.  
    wire [7:0] adc_val;
    assign adc_val = r_sdi_word[8:1];
    
    reg r_wdp_set;
    always @(negedge sclk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
            r_stat <= s_init_0;
            r_adc_auto_cal_inst <= 1'b0;
            r_dp_init <= 1'b0;
            r_dp_idx <= 2'd0;
            r_adc_stat_inst <= 1'b0;
            r_adc_cnv_inst <= 1'b0;
            r_inst_intvl <= 4'd0;
            r_cnt_init_to <= 13'd0;
            r_ap_rud_inst <= rud_neutral;
            r_ap_rud_stat <= rud_neutral;
            r_ap_eng_r_inst <= eng_neutral;
            r_ap_eng_l_inst <= eng_neutral;
            r_wdp_set <= 1'b0;
        end else begin
        
            case (r_stat)
            //////////////////////////////////////////// init_0
            // The state send an instruction AutoCal to ADC.
            // Few cycles later, EOC is deasserted and the state is transitted into init_1.
            s_init_0:
            begin
                if(r_adc_auto_cal_inst == 1'b0) begin
                   // sending AutoCal instruction
                   r_adc_auto_cal_inst <= 1'b1;
                end else begin
                   if(eoc == 1'b0) begin
                       r_stat <= s_init_1;
                       r_cnt_init_to <= 13'd0;
                       r_dp_idx <= 3'd0;
                   end else if(r_cnt_init_to >= p_init_to) begin
                        // time out, again init_0 
                        r_stat <= s_init_0;
                        r_cnt_init_to <= 13'd0;
                        r_adc_auto_cal_inst <= 1'b0;
                   end else begin
                        r_cnt_init_to <= r_cnt_init_to + 1;
                   end
                end 
            end     
                 
            //////////////////////////////////////////// init_1
            // Basically, the state continues until the AutoCal is finished.
            // Since the duration could be 4944 cycles, 4 DPs are initialized as neutral
            // during the state.
            s_init_1:
            begin
                if(eoc == 1'b1 && r_dp_init) begin
                    // initialization finished
                    r_stat <= s_rstat;
                    r_cnt_init_to <= 13'd0;
                end else if (r_cnt_init_to > p_init_to) begin
                    // time out, return to init_0
                    r_stat <= s_init_0;
                    r_cnt_init_to <= 13'd0;
                    r_adc_auto_cal_inst <= 1'b0;
                    r_dp_init <= 1'b0;
                end else if (r_dp_init == 1'b0) begin
                  if(r_sdo_cnt == 4'd0) begin
                    // Maybe, all the DPs are initialized as neutral when the device start up.
                    // The codes below do the same, it might be a redundant treatment. 
                    
                    if(r_dp_idx == 2'd3) begin
                        r_dp_init <= 1'b1;
                        r_dp_idx <= 2'd0;
                    end else begin
                        r_dp_idx <= r_dp_idx + 1;
                    end
                  end  
                end
                
                r_cnt_init_to <= r_cnt_init_to + 1;
            end
            
            //////////////////////////////////////////// rstat
            // The state sends an instruction read status to ADC.
            // After sending, the state transits to conv.
            s_rstat:
            begin 
                if(r_adc_stat_inst == 1'b0) begin
                    r_adc_stat_inst <= 1'b1;
                end else if(r_sdo_cnt == 4'd0) begin
                    if(r_inst_intvl < 4'd4) begin
                        r_inst_intvl <= r_inst_intvl + 1;
                    end else begin
                        r_stat <= s_conv;
                        r_adc_stat_inst <= 1'b0;
                        r_inst_intvl <= 4'd0;
                    end
                end
            end
            
            //////////////////////////////////////////// conv
            s_conv:
            begin
                if(r_adc_cnv_inst == 1'b0) begin
                    r_adc_cnv_inst <= 1'b1;
                end else if(r_sdo_cnt == 4'd0) begin                    
                    if(r_inst_intvl < 4'd4) begin
                        r_inst_intvl <= r_inst_intvl + 1;
                    end else begin
                        r_stat <= s_wdp;
                        r_adc_cnv_inst <= 1'b0;
                        r_inst_intvl <= 4'd0;
                    end
                end 
            end
            
            //////////////////////////////////////////// wdp
            s_wdp:
            begin
                // setting values loaded in the previous cycle to the corresponding DPs
                        // store loaded data to the register.
                    if(r_wdp_set == 1'b0) begin
                        if(eoc == 1'b0) begin
                        if(r_init_cnv == 1'b0) begin // initial data is status, discarded.
                            r_adc_stat <= r_sdi_word[12:5];
                        end else begin
                            case(r_dp_idx)
                            2'd0: 
                            begin
                                r_ap_eng_l_inst <= adc_val;
                            end
                            2'd1:
                            begin
                                r_ap_rud_inst <= adc_val;
                            end
                            2'd2:
                            begin
                                r_ap_rud_stat <= adc_val;
                            end
                            2'd3:
                            begin
                                r_ap_eng_r_inst <= adc_val;
                            end
                            endcase   
                        end
                        r_wdp_set <= 1'b1;
                        end                   
                    end else begin
                        if(eoc == 1'b1 && r_sdo_cnt == 4'd0) begin
                            r_stat <= s_conv;
                            r_wdp_set <= 1'b0;
                            r_dp_idx <= r_dp_idx + 1;
                        end
                    end
            end
            endcase
        end
    end

    // r_aws_ctrl is inverted when the aws_ctrl's rising edge is detected.
    // The value is initially set as zero, manual control.
    reg r_aws_ctrl_0, r_aws_ctrl_1;
    always @(negedge sclk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            r_aws_ctrl <= 1'b0;
        end else begin
            r_aws_ctrl_0 <= aws_ctrl;
            r_aws_ctrl_1 <= r_aws_ctrl_0;
            
            if(r_aws_ctrl_0 != r_aws_ctrl_1) begin
                r_aws_ctrl <= (r_aws_ctrl == 1'b1 ? 1'b0 : 1'b1);
            end
            
            if(r_stat == s_wdp && r_init_cnv == 1'b1 && r_wdp_set == 1'b0) begin
                case(r_dp_idx)
                2'd0: 
                begin
                    r_aws_ctrl <= (r_aws_ctrl && adc_val != r_ap_eng_l_inst ? 1'b0 : r_aws_ctrl);
                end
                2'd1:
                begin
                    r_aws_ctrl <= (r_aws_ctrl && adc_val != r_ap_rud_inst ? 1'b0 : r_aws_ctrl);                    
                end
                2'd2:
                begin
                    r_aws_ctrl <= (r_aws_ctrl && adc_val != r_ap_rud_stat? 1'b0 : r_aws_ctrl);                   
                end
                2'd3:
                begin
                    r_aws_ctrl <= (r_aws_ctrl && adc_val != r_ap_eng_r_inst ? 1'b0 : r_aws_ctrl);                    
                end
                endcase   
            end
        end
    end
      
    // Sending SPI word
    assign sdo = r_sdo_word[7];
    always @(negedge sclk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            r_sdo_cnt <= 4'b0000;
            r_sdo_word <= 8'd0;
            r_cs_n <= cs_none;            
        end else begin
            // send
            if (r_sdo_cnt > 0) begin 
                r_sdo_cnt <= r_sdo_cnt - 1;
                r_sdo_word[7:1] <= r_sdo_word[6:0];
                r_sdo_word[0] <= 1'b0;
            end  
            
            if(r_sdi_cnt <= 4'd1 && r_sdo_cnt <= 4'd1) begin
                r_cs_n <= cs_none;
            end
            
            case (r_stat)
            //////////////////////////////////////////// init_0
            
            // The state send an instruction AutoCal to ADC.
            // Few cycles later, EOC is deasserted and the state is transitted into init_1.
            s_init_0:
            begin
                if(r_adc_auto_cal_inst == 1'b0) begin
                   // sending AutoCal instruction
                   r_cs_n <= cs_adc;
                   r_sdo_cnt <= 4'd8;
                   r_sdo_word <= i_adc_auto_cal;
                end
            end     
                 
            //////////////////////////////////////////// init_1
            // Basically, the state continues until the AutoCal is finished.
            // Since the duration could be 4944 cycles, 4 DPs are initialized as neutral
            // during the state.
            s_init_1:
            begin
                if (r_cnt_init_to < p_init_to && r_dp_init == 1'b0 && r_sdo_cnt == 4'd0) begin
                    // Maybe, all the DPs are initialized as neutral when the device start up.
                    // The codes below do the same, it might be a redundant treatment. 
                    r_sdo_cnt <= 4'd8;                    
                    r_sdo_word <= rud_neutral;
                    
                    case(r_dp_idx)
                    2'd0: r_cs_n <= cs_rud_inst;
                    2'd1: r_cs_n <= cs_rud_stat;
                    2'd2: r_cs_n <= cs_eng_r_inst;
                    2'd3: r_cs_n <= cs_eng_l_inst;
                    default: r_cs_n <= cs_none;
                    endcase                     
                end                                
            end
            
            //////////////////////////////////////////// rstat
            // The state sends an instruction read status to ADC.
            // After sending, the state transits to conv.
            s_rstat:
            begin 
                if(r_adc_stat_inst == 1'b0) begin
                    r_cs_n <= cs_adc;
                    r_sdo_cnt <= 4'd8;
                    r_sdo_word <= i_adc_stat;
                end
            end
            
            //////////////////////////////////////////// conv
            s_conv:
            begin
                if(r_adc_cnv_inst == 1'b0) begin
                    r_cs_n <= cs_adc;
                    r_sdo_cnt <= 4'd8;                   
                    case(r_dp_idx)
                    2'd0: r_sdo_word <= i_cnv_ch0;
                    2'd1: r_sdo_word <= i_cnv_ch1;
                    2'd2: r_sdo_word <= i_cnv_ch2;
                    2'd3: r_sdo_word <= i_cnv_ch3;
                    endcase         
                end 
            end
            
            //////////////////////////////////////////// wdp
            s_wdp:
            begin
                // setting values loaded in the previous cycle to the corresponding DPs
                if(r_wdp_set == 1'b0 && eoc == 1'b0) begin
                    r_sdo_cnt <= 4'd8;
                        
                    case(r_dp_idx)
                    2'd0:
                    begin
                        r_cs_n <= cs_eng_l_inst;
                        r_sdo_word <= r_aws_ctrl ? aws_eng_l_inst : adc_val;
                    end
                    2'd1:
                    begin
                        r_cs_n <= cs_rud_inst;
                        r_sdo_word <= r_aws_ctrl ? aws_rud_inst : adc_val;
                    end
                    2'd2:
                    begin
                        r_cs_n <= cs_rud_stat;
                        r_sdo_word <= adc_val;
                    end
                    2'd3:
                    begin
                        r_cs_n <= cs_eng_r_inst;
                        r_sdo_word <= r_aws_ctrl ? aws_eng_r_inst : adc_val;
                    end
                    endcase           
                    
                end
            end
            endcase
                      
        end
    end
    
    // Recieving SPI word
    reg r_init_cnv;
    always @(posedge sclk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            r_sdi_cnt <= 4'b0000;
            r_sdi_word <= 13'd0;
            r_init_cnv <= 1'b0;
        end else begin
            // recieve
                if (r_sdi_cnt > 4'd0) begin
                    r_sdi_cnt <= r_sdi_cnt - 1;
                    r_sdi_word[12:1] <= r_sdi_word[11:0];
                    r_sdi_word[0] <= sdi;
                end 
                        
            case (r_stat)
            //////////////////////////////////////////// conv
            s_conv:
            if(r_adc_cnv_inst == 1'b0) begin
                begin
                    if(r_init_cnv == 1'b0) begin
                        r_sdi_cnt <= 4'd8;
                    end else begin
                        r_sdi_cnt <= 4'd13;
                    end
                end
            end
            s_wdp:
                if(r_wdp_set == 1'b1 && r_init_cnv == 1'b0) begin
                    r_init_cnv <= 1'b1;
                end
            endcase
            
        end
    end    
endmodule


