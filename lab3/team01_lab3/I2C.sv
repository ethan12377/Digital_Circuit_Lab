module I2cInitializer(
	input  i_rst_n,
	input  i_clk,
	input  i_start,
	output o_finished,
	output o_sclk,
	output o_sdat,
	output o_oen // you are outputing (you are not outputing only when you are "ack"ing.)
	//output [2:0] state
);

	//assign state = state_r;

	localparam LLINEIN = 24'b0011_0100_000_0000_0_1001_0111;
	localparam RLINEIN = 24'b0011_0100_000_0001_0_1001_0111;
	localparam LHPOUT = 24'b0011_0100_000_0010_0_0111_1001;
	localparam RHPOUT = 24'b0011_0100_000_0011_0_0111_1001;
	localparam AAPCTRL = 24'b0011_0100_000_0100_0_0001_0101;
	localparam DAPCTRL = 24'b0011_0100_000_0101_0_0000_0000;
	localparam PDCTRL = 24'b0011_0100_000_0110_0_0000_0000;
	localparam DAIFMT = 24'b0011_0100_000_0111_0_0100_0010;
	localparam SCTRL = 24'b0011_0100_000_1000_0_0001_1001;
	localparam ACTRL = 24'b0011_0100_000_1001_0_0000_0001;

	localparam S_IDLE = 0;
	localparam S_SEND = 1;
	localparam S_SWITCH = 2;
	localparam S_ACK = 3;
	localparam S_FINISH = 4;

	logic [3:0]  counter_r, counter_w;
	logic [3:0]  setting_r, setting_w;
	logic [4:0]  pos_r, pos_w;
	logic [2:0]  state_r, state_w;
	logic        finished_r, finished_w;
	logic        sclk_r, sclk_w;
	logic        sdat_r, sdat_w;
	logic        oen_r, oen_w;
	logic [0:23] config_data[0:9];
	//wire         sdat;

	assign config_data[9] = LLINEIN;
	assign config_data[8] = RLINEIN;
	assign config_data[7] = LHPOUT;
	assign config_data[6] = RHPOUT;
	assign config_data[5] = AAPCTRL;
	assign config_data[4] = DAPCTRL;
	assign config_data[3] = PDCTRL;
	assign config_data[2] = DAIFMT;
	assign config_data[1] = SCTRL;
	assign config_data[0] = ACTRL;

	assign o_finished = finished_r;
	assign o_sclk = sclk_r;
	assign o_sdat = sdat_r;
	//assign sdat = oen_r ? sdat_r : 1'bz;
	assign o_oen = oen_r;

	always_comb begin
		counter_w = counter_r;
		setting_w = setting_r;
		pos_w = pos_r;
		state_w = state_r;
		finished_w = finished_r;
		sclk_w = sclk_r;
		sdat_w = sdat_r;
		oen_w = oen_r;
		case (state_r)
			S_IDLE : begin
				//finished_w = 0;
				if (i_start) begin
					state_w = S_SWITCH;
					sdat_w = 0;
				end
			end
			S_SEND : begin
				counter_w = counter_r + 1;
				pos_w = pos_r + 1;
				state_w = S_SWITCH;
				sclk_w = 1;				
				// if(pos_r == 23) begin
				// 	pos_w = 0;
				// 	setting_w = setting_r + 1;
				// end
				// if (counter_r == 7) begin
				// 	counter_w = 0;
				// 	state_w = S_ACK;
				// end
			end
			S_SWITCH : begin
				sclk_w = 0;
				if (~sclk_r) begin
					oen_w = 1;
					state_w = S_SEND;
					sdat_w = config_data[setting_r][pos_r];
					if(counter_r == 8) begin
						state_w = S_ACK;
						sdat_w = 1'b0;
						oen_w = 0;
					end
					else if (pos_r == 24) begin
						state_w = S_FINISH;
						sdat_w = 1'b0;
					end
					// if (setting_r == 8) begin
					// 	sdat_w = 0;
					// 	state_w = S_FINISH;
					// end
				end
			end
			S_ACK : begin
				counter_w = 0;
				state_w = S_SWITCH;
				sclk_w = 1;
				//oen_w = 0;
				// if(pos_r == 24) begin
				//  	pos_w = 0;
				// 	setting_w = setting_r + 1;
				// end
				// sclk_w = 0;
				// oen_w = 0;
				// if(~oen_r & ~o_sdat) begin
				// 	state_w = S_SWITCH;
				// 	oen_w = 1;
				// 	if(setting_r == 10) begin
				// 		state_w = S_FINISH;
				// 		sdat_w = 0;
				// 	end
				// end
			end
			S_FINISH : begin
				sclk_w = 1;
				if (sclk_r) begin
					sdat_w = 1;
					if (setting_r < 9) begin
						if(sdat_r) begin
							sdat_w = 0;
							setting_w = setting_r + 1;
							state_w = S_SWITCH;
							pos_w = 0;
						end
					end
					else begin
						finished_w = 1;
					end
				end
			end
			default : /* default */;
		endcase
	end

	always_ff @(posedge i_clk or negedge i_rst_n) begin
		if(~i_rst_n) begin
			counter_r <= 0;
			setting_r <= 0;
			pos_r <= 0;
			state_r <= S_IDLE;
			finished_r <= 0;
			sclk_r <= 1;
			sdat_r <= 1;
			oen_r <= 1;
		end else begin
			counter_r <= counter_w;
			setting_r <= setting_w;
			pos_r <= pos_w;
			state_r <= state_w;
			finished_r <= finished_w;
			sclk_r <= sclk_w;
			sdat_r <= sdat_w;
			oen_r <= oen_w;
		end
	end

endmodule