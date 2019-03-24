`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/10/02 12:31:16
// Design Name: 
// Module Name: top
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


module top(
    DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,    
    ahrs_rx,
    ahrs_tx,
    ais_rx,
    ais_tx,
    ap_rx,
    ap_tx,
    gff_rx,
    gff_tx,
    gps_rx,
    gps_tx,
    mlb_rx,
    mlb_tx,
    vsen_rx,
    vsen_tx,    
    sclk,
    sdo,
    csn,
    ahrs_off,
    jon,
    jtxon,
    pps
    );   
      
    inout [14:0]DDR_addr;
    inout [2:0]DDR_ba;
    inout DDR_cas_n;
    inout DDR_ck_n;
    inout DDR_ck_p;
    inout DDR_cke;
    inout DDR_cs_n;
    inout [3:0]DDR_dm;
    inout [31:0]DDR_dq;
    inout [3:0]DDR_dqs_n;
    inout [3:0]DDR_dqs_p;
    inout DDR_odt;
    inout DDR_ras_n;
    inout DDR_reset_n;
    inout DDR_we_n;
    inout FIXED_IO_ddr_vrn;
    inout FIXED_IO_ddr_vrp;
    inout [53:0]FIXED_IO_mio;
    inout FIXED_IO_ps_clk;
    inout FIXED_IO_ps_porb;
    inout FIXED_IO_ps_srstb;
    input ahrs_rx;
    output ahrs_tx;
    input ais_rx;
    output ais_tx;
    input ap_rx;
    output ap_tx;
    input gff_rx;
    output gff_tx;
    input gps_rx;
    output gps_tx;
    input mlb_rx;
    output mlb_tx;
    input vsen_rx;
    output vsen_tx;
    output ahrs_off;
    output jon;
    output jtxon;
    input pps;
    
    output sclk;
    output sdo;
    output [2:0] csn;

    wire [31:0]w_ctrl_i;
    wire [31:0]w_ctrl_o;
    
    wire w_rstn;
    wire w_clk;
    wire w_sclk;
    reg [9:0] cc;
    
    assign w_sclk = cc[9];
    assign sclk = w_sclk;
    always @(posedge w_clk or negedge w_rstn)
    begin
        if(w_rstn == 1'b0) begin
            cc <= 10'd0;
        end
        else 
        begin
            cc <= cc + 1;
        end
    end
    
    wire [23:0] w_ctrl_val;
    wire w_sdi, w_sdo;
    wire [2:0] w_csn;
    assign w_ctrl_val = w_ctrl_o[23:0];
    awsctrl awsctrl_i(.ctrl_val(w_ctrl_val), 
                        .sclk(w_sclk),
                        .sdi(w_sdi),
                        .sdo(w_sdo),
                        .cs_n(w_csn),
                        .rst_n(w_rstn)
                        );
//    assign csn = w_csn;
    assign csn = (w_csn == 3'b011 ? 3'b011 : (w_csn == 3'b101 ? 3'b010 : (w_csn == 3'b110 ? 3'b001 : 3'b111)));
    assign sdo = w_sdo;     
             
//    wire w_pps;
//    wire [31:0] w_tevt;
//    wire [31:0] w_evt;                    
//    awstm aws_tm_i(.pps(w_pps), 
//                   .tevt(w_tevt),
//                   .evt(w_evt),
//                   .rst_n(w_rstn),
//                   .clk(clk));
        
    assign w_ctrl_i = w_ctrl_o;
    wire w_ahrs_rx;
    wire w_ahrs_tx;
    wire w_ais_rx;
    wire w_ais_tx;
    wire w_ap_rx;
    wire w_ap_tx;
    wire w_gff_rx;
    wire w_gff_tx;
    wire w_gps_rx;
    wire w_gps_tx;
    wire w_mlb_rx;
    wire w_mlb_tx;
    wire w_vsen_rx;
    wire w_vsen_tx;                   
    wire [31:0] w_sys_i;
    wire [31:0] w_sys_o;
    cpu cpu_i
            (.DDR_addr(DDR_addr),
             .DDR_ba(DDR_ba),
             .DDR_cas_n(DDR_cas_n),
             .DDR_ck_n(DDR_ck_n),
             .DDR_ck_p(DDR_ck_p),
             .DDR_cke(DDR_cke),
             .DDR_cs_n(DDR_cs_n),
             .DDR_dm(DDR_dm),
             .DDR_dq(DDR_dq),
             .DDR_dqs_n(DDR_dqs_n),
             .DDR_dqs_p(DDR_dqs_p),
             .DDR_odt(DDR_odt),
             .DDR_ras_n(DDR_ras_n),
             .DDR_reset_n(DDR_reset_n),
             .DDR_we_n(DDR_we_n),
             .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
             .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
             .FIXED_IO_mio(FIXED_IO_mio),
             .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
             .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
             .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
             .ctrl_i(w_ctrl_i),
             .ctrl_o(w_ctrl_o),
             .ahrs_rx(w_ahrs_rx),
             .ahrs_tx(w_ahrs_tx),
             .ais_rx(w_ais_rx),
             .ais_tx(w_ais_tx),
             .ap_rx(w_ap_rx),
             .ap_tx(w_ap_tx),
             .gff_rx(w_gff_rx),
             .gff_tx(w_gff_tx),
             .gps_rx(w_gps_rx),
             .gps_tx(w_gps_tx),
             .mlb_rx(w_mlb_rx),
             .mlb_tx(w_mlb_tx),
             .vsen_rx(w_vsen_rx),
             .vsen_tx(w_vsen_tx),             
             .sys_i(w_sys_i),
             .sys_o(w_sys_o),             
             .clk(w_clk),
             .rstn(w_rstn));
             
    assign w_gff_rx = ~gff_rx;
    assign gff_tx = ~w_gff_tx;
    assign w_ais_rx = ~ais_rx;
    assign ais_tx = ~w_ais_tx;
    assign w_ap_rx = ~ap_rx;
    assign ap_tx = ~w_ap_tx;
    assign w_gps_rx = gps_rx;
    assign gps_tx = w_gps_tx;
    assign w_ahrs_rx = ahrs_rx;
    assign ahrs_tx = w_ahrs_tx;
    assign w_mlb_rx = mlb_rx;
    assign mlb_tx = w_mlb_tx;
    assign w_vsen_rx = vsen_rx;
    assign vsen_tx = w_vsen_tx;   
    
    assign ahrs_off = w_sys_o[29];
    assign jon = w_sys_o[30];
    assign jtx_on = w_sys_o[28];
    assign w_sys_i[30:0] = w_sys_o[30:0];
    assign w_sys_i[31] = pps;
endmodule
