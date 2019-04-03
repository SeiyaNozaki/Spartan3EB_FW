`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:18:27 10/18/2016 
// Design Name: 
// Module Name:    clock10M 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Spartan3EB_main(
    input RST,
    input CLK_50MHZ,
	 input Ext_TRIGGER,
	 input L1_CAMERA_T_P,
	 input L1_CAMERA_T_N,
	 input BUSY_P,
	 input BUSY_N,
	 input [3:0] SW,
	 input ROT_A,
	 input ROT_B,
    output CLK10M_P,
    output CLK10M_N,
    output PPS_P,
    output PPS_N,
	 output [2:0] LED,
	 output EVT_TRG_P,
	 output EVT_TRG_N
    );

	wire clk;
	wire clk10M;
	wire clk250M;
	wire trg_selected;
	wire clk_lck;
	reg pps = 0;
	reg trg_int = 0;
	reg trg_L1 = 0;
	reg [22:0] counter = 0;
	reg [13:0] counter_trg = 0;
	reg [13:0] counter_4us = 0;
	parameter INIT_4US = 14'd1024 ;
	reg [13:0] C_4us = INIT_4US;
	reg L1_flag = 0;
	reg deflag = 0;

	assign LED[2] = pps;
	assign LED[1] = ~clk_lck;
	assign LED[0] = 1;


	DCM_50M dcm_50m (
    .CLKIN_IN(CLK_50MHZ), 
    .RST_IN(RST), 
    .CLKDV_OUT(clk10M), 
    .CLKFX_OUT(clk250M), 
    .CLKIN_IBUFG_OUT(), 
    .CLK0_OUT(clk), 
    .LOCKED_OUT(clk_lck)
    );
	 
	wire L1_camera_t;
	wire busy;
	
	IBUFDS #(
		.DIFF_TERM("TRUE"),
		.IOSTANDARD("LVDS_25")
	)IBUFDS_L1_CAMERA_T(
		.O  (L1_camera_t),
		.I  (L1_CAMERA_T_P),
		.IB (L1_CAMERA_T_N)
	);
	IBUFDS #(
		.DIFF_TERM("TRUE"),
		.IOSTANDARD("LVDS_25")
	)IBUFGS_BUSY(
		.O  (busy),
		.I  (BUSY_P),
		.IB (BUSY_N)
	);
	
  wire        sync_rot_b;
  synchro #(.INITIALIZE("LOGIC1"))
  synchro_rot_b (.async(ROT_B),.sync(sync_rot_b),.clk(clk));

  wire        sync_rot_a;
  synchro #(.INITIALIZE("LOGIC1"))
  synchro_rot_a (.async(ROT_A),.sync(sync_rot_a),.clk(clk));

  wire        event_rot_l_one;
  wire        event_rot_r_one;

  spinner spinner_inst (
    .sync_rot_a(sync_rot_a),
    .sync_rot_b(sync_rot_b),
    .event_rot_l(event_rot_l_one),
    .event_rot_r(event_rot_r_one),
    .clk(clk));
	 
	always @(posedge clk or posedge RST) begin
		if(RST) C_4us <= INIT_4US;
		else if(event_rot_l_one) C_4us <= C_4us - 14'd1;
		else if(event_rot_r_one) C_4us <= C_4us + 14'd1;
	end

	assign trg_selected = SW[1] ? trg_L1 : ( SW[0] ? trg_int : Ext_TRIGGER) ;
	// trg_int : 1 kHz , width 100 ns
	
	wire w_deflag;
	assign w_deflag = deflag | RST | busy;
	
	always@(posedge L1_camera_t or posedge w_deflag) begin
		if(w_deflag) begin
			L1_flag <= 0 ;
		end else begin
			L1_flag <= 1;
		end
	end
	
	
	// trg_L1
	always@(posedge clk250M or posedge RST) begin
		if(RST) begin
			counter_4us <= 14'd0;
			trg_L1 <= 0;
			deflag <= 0;
		end else 
		if(L1_flag) begin
			if(counter_4us == C_4us ) begin
				trg_L1 <= 1;
				counter_4us <= counter_4us + 14'd1;
				deflag <= 0;
			end else
			if(counter_4us == C_4us + 14'd13 ) begin
				trg_L1 <= 0;
				counter_4us <= 14'd0;
				deflag <= 1;
			end else begin
				counter_4us <= counter_4us + 14'd1;
				deflag <= 0;
			end
		end else begin
			deflag <= 0;
		end
	end
	
	// trig_int(1kHz)
	always@(posedge clk10M or posedge RST) begin
		if(RST) begin
			counter <= 23'd0;
			counter_trg <= 14'd0;
			trg_int <= 0;
			pps <= 1'b0;
		end else begin
			if(counter == 23'd4999999) begin
				pps <= ~pps;
				counter <= 23'd0;
			end else begin
				counter <= counter + 23'd1;
			end
			
			if(trg_int == 0  &&  counter_trg == 14'd9999) begin
				trg_int <= 1;
				counter_trg <= 14'd0;
			end else begin
				trg_int <= 0;
				counter_trg <= counter_trg + 14'd1;
			end
		end
	end

	
	//wire clk10M_tmp;
	//ODDR2	ODDR2_CLK10M (.Q(clk10M_tmp), .C0(clk10M), .C1(~clk10M), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

	OBUFDS #(
		.IOSTANDARD("LVDS_25")
	) OBUFDS_CLK10M (
		.O(CLK10M_P),
		.OB(CLK10M_N),
		.I(clk10M)
	);
	
	OBUFDS #(
		.IOSTANDARD("LVDS_25")
	) OBUFDS_PPS (
		.O(PPS_P),
		.OB(PPS_N),
		.I(pps)
	);

	OBUFDS #(
		.IOSTANDARD("LVDS_25")
	) OBUFDS_TRIGGER (
		.O(EVT_TRG_P),
		.OB(EVT_TRG_N),
		.I(trg_selected)
	);


endmodule
