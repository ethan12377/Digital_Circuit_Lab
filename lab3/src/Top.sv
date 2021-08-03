module Top (
	input i_rst_n,
	input i_clk,
	input i_key_0, // record/pause
	input i_key_1, // play/pause
	input i_key_2, // stop
	input [4:0] i_speed, // design how user can decide mode on your own
	
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,

	// SEVENDECODER (optional display)
	output [5:0] o_record_time,
	output [5:0] o_play_time,

	// LCD (optional display)
	// input        i_clk_800k,
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON,

	// LED
	output  [8:0] o_ledg,
	output [17:0] o_ledr
);

assign o_record_time = state_r;
assign o_play_time = state;
assign o_ledg = {4'b0, i_speed};
assign o_ledr = addr_record[19:2];
logic [1:0] state;

// design the FSM and states as you like
parameter S_IDLE       = 0;
parameter S_I2C        = 1;
parameter S_RECD       = 2;
parameter S_RECD_PAUSE = 3;
parameter S_PLAY       = 4;
parameter S_PLAY_PAUSE = 5;
parameter S_CLEAR      = 6;

logic [2:0] state_r, state_w;
logic i2c_oen;
logic [19:0] addr_record, addr_play;
logic [15:0] data_record, data_play, dac_data;
logic [19:0] clear_counter_r, clear_counter_w;
logic o_finish_init;
logic [2:0] speed;
logic fast_or_slow;
logic interpolation;
logic finish_play, finish_rec;
wire i2c_sdat;

assign io_I2C_SDAT = i2c_sdat;
// assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

// assign o_SRAM_ADDR = (state_r == S_RECD) ? addr_record : addr_play[19:0];
assign o_SRAM_ADDR = (state_r == S_RECD) ? addr_record : ( (state_r == S_CLEAR) ? clear_counter_r : addr_play[19:0] );
assign io_SRAM_DQ  = (state_r == S_RECD) ? data_record : ( (state_r == S_CLEAR) ? 16'd0 : 16'dz ); // sram_dq as output
assign data_play   = (state_r != S_RECD) ? io_SRAM_DQ : 16'd0; // sram_dq as input

assign o_SRAM_WE_N = (state_r == S_RECD || state_r == S_CLEAR) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;

assign speed = i_speed[2:0];
assign fast_or_slow = i_speed[3];
assign interpolation = i_speed[4];

// below is a simple example for module division
// you can design these as you like

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(1'b1),
	.o_finished(o_finish_init),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
	// .state()
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk),
	.i_start(i_key_1 & (state_r == S_IDLE || state_r==S_PLAY_PAUSE) ),
	.i_pause(i_key_1 & state_r == S_PLAY),
	.i_stop(i_key_2 & state_r != S_IDLE),
	.i_speed(speed),
	.i_fast(fast_or_slow),
	.i_slow_0(~interpolation), // constant interpolation
	.i_slow_1(interpolation), // linear interpolation
	.i_daclrck(i_AUD_DACLRCK),
	.i_sram_data(data_play),
	.o_dac_data(dac_data),
	.o_sram_addr(addr_play),
	.o_finish_play(finish_play),
	.state(state)
);

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n(i_rst_n),
	.i_bclk(i_AUD_BCLK),
	.i_daclrck(i_AUD_DACLRCK),
	.i_en(state_r == S_PLAY), // enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data(dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM
AudRecorder recorder0(
	.i_rst_n(i_rst_n), 
	.i_clk(i_AUD_BCLK),
	.i_lrc(i_AUD_ADCLRCK),
	.i_start(i_key_0 & (state_r == S_IDLE || state_r==S_RECD_PAUSE)),
	.i_pause(i_key_0 & state_r == S_RECD),
	.i_stop(i_key_2 & state_r != S_IDLE),
	.i_data(i_AUD_ADCDAT),
	.o_address(addr_record),
	.o_data(data_record),
	.o_finish(finish_rec)
);

always_comb begin
	// design your control here
	clear_counter_w = 16'd0;
	case (state_r)
		S_IDLE: begin
			if (~o_finish_init) begin
				state_w = S_I2C;
			end
			else if (i_key_0) begin
				state_w = S_CLEAR;
			end
			else if (i_key_1) begin
				state_w = S_PLAY;
			end
			else begin
				state_w = S_IDLE;
			end
		end
		S_I2C: begin
			if (o_finish_init) begin
				state_w = S_IDLE;
			end
			else if (i_key_2) begin
				state_w = S_IDLE;
			end
			else begin
				state_w = S_I2C;
			end
		end
		S_RECD: begin
			if (i_key_0) state_w = S_RECD_PAUSE;
			else if (i_key_2 || finish_rec) state_w = S_IDLE;
			else state_w = S_RECD;
		end
		S_RECD_PAUSE: begin
			if (i_key_0) state_w = S_RECD;
			else if (i_key_2 || finish_rec) state_w = S_IDLE;
			else state_w = S_RECD_PAUSE;
		end
		S_PLAY: begin
			if (i_key_1) state_w = S_PLAY_PAUSE;
			else if (i_key_2 || finish_play) state_w = S_IDLE;
			else state_w = S_PLAY;
		end
		S_PLAY_PAUSE: begin
			if (i_key_1) state_w = S_PLAY;
			else if (i_key_2 || finish_play) state_w = S_IDLE;
			else state_w = S_PLAY_PAUSE;
		end
		S_CLEAR: begin
			if (clear_counter_r == 20'b11111111111111111111) state_w = S_RECD;
			else state_w = S_CLEAR;
			clear_counter_w = clear_counter_r + 1;
		end
	endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (~i_rst_n) begin
		state_r <= S_IDLE;
		clear_counter_r <= 0;
	end
	else begin
		state_r <= state_w;
		clear_counter_r <= clear_counter_w;
	end
end

endmodule
