module AudDSP (
	input 			i_rst_n,
	input 			i_clk,
	input 			i_start,
	input 			i_pause,
	input 			i_stop,
	input	[2:0]	i_speed,
	input 			i_fast,
	input 			i_slow_0, // constant interpolation
	input 			i_slow_1, // linear interpolation
	input 			i_daclrck,
	input 	[15:0]	i_sram_data,
	output 	[15:0]	o_dac_data,
	output 	[19:0]	o_sram_addr,
	output			o_finish_play,
	output	[1:0]	state
);
localparam S_IDLE = 2'd0;
localparam S_PLAY = 2'd1;
localparam S_PAUSE = 2'd2;

logic 	[19:0]	o_sram_addr_r, o_sram_addr_w;
logic signed  [16:0]  data_diff, data_step, data_inc;
logic 	[15:0]	o_dac_data_r, o_dac_data_w, prev_sram_data_r, prev_sram_data_w;
logic 	[1:0]	state_r, state_w;
logic			o_valid_r, o_valid_w, new_data_r, new_data_w, finish_r, finish_w, almost_finish_r, almost_finish_w;
logic 	[3:0]	data_counter_r, data_counter_w;

assign o_sram_addr = o_sram_addr_r;
assign o_dac_data = o_dac_data_r;
assign o_finish_play = finish_r;
assign state = state_r;

always_comb begin
	state_w = state_r;
	o_sram_addr_w = o_sram_addr_r;
	o_dac_data_w = o_dac_data_r;
	prev_sram_data_w = prev_sram_data_r;
	o_valid_w = o_valid_r;
	new_data_w = !i_daclrck;
	data_counter_w = data_counter_r;
	finish_w = finish_r;
	almost_finish_w = almost_finish_r;
	data_diff = $signed(i_sram_data)-$signed(prev_sram_data_r);
    case(i_speed)
        3'b000: data_step = data_diff;
        3'b001: data_step = data_diff>>>1;
        3'b010: data_step = (data_diff>>>2) + (data_diff>>>4) + (data_diff>>>6) + (data_diff>>>8) + (data_diff>>>10) + (data_diff>>>12);
        3'b011: data_step = data_diff>>>2;
        3'b100: data_step = (data_diff>>>3) + (data_diff>>>4) + (data_diff>>>7) + (data_diff>>>8) + (data_diff>>>11) + (data_diff>>>12);
        3'b101: data_step = (data_diff>>>3) + (data_diff>>>5) + (data_diff>>>7) + (data_diff>>>9) + (data_diff>>>11) + (data_diff>>>13);
        3'b110: data_step = (data_diff>>>3) + (data_diff>>>6) + (data_diff>>>9) + (data_diff>>>12) + (data_diff>>>15);
        3'b111: data_step = data_diff>>>3;
        default:data_step = data_diff;
    endcase
    data_inc = data_step*data_counter_r;
	case(state_r)
		S_IDLE: begin
			state_w = i_start ? S_PLAY : S_IDLE; 
			o_sram_addr_w = 20'b0;
			o_dac_data_w = 16'b0;
			prev_sram_data_w = 16'b0;
			o_valid_w = 1'b0;
			data_counter_w = 4'b0;
			finish_w = 1'b0;
			almost_finish_w = 1'b0;
		end
		S_PLAY: begin
			state_w = i_stop || finish_r ? S_IDLE : 
					  i_pause ? S_PAUSE : S_PLAY;
			if (i_speed==3'b0 || i_fast) begin
				if (!new_data_r && new_data_w) begin
					o_dac_data_w = i_sram_data;
					o_valid_w = 1'b1;
				end else if (new_data_r && !new_data_w) begin
					// o_dac_data_w = 16'b0;
					o_dac_data_w = o_dac_data_r;
					o_valid_w = 1'b0;
				end else begin
					o_dac_data_w = o_dac_data_r;
					o_valid_w = o_valid_r;
				end

				if (!o_valid_r && o_valid_w) begin
					if (o_sram_addr_r > {{19{1'b1}}, 1'b0}-i_speed) begin
						o_sram_addr_w = 20'b0;
						almost_finish_w = 1'b1;
					end else begin
						o_sram_addr_w = o_sram_addr_r+1'b1+i_speed;
						almost_finish_w = 1'b0;
					end 
				end else begin
					o_sram_addr_w = o_sram_addr_r;
					almost_finish_w = almost_finish_r;
				end
                if(!o_valid_r && o_valid_w && almost_finish_r) begin
                    finish_w = 1'b1;
                end else begin
                    finish_w = 1'b0;
                end
			end else begin
				if (!new_data_r && new_data_w) begin
                    o_dac_data_w = data_counter_r==0 ? i_sram_data :
									i_slow_0 ? prev_sram_data_r : 
									prev_sram_data_r + data_inc;
					o_valid_w = 1'b1;
				end else if (new_data_r && !new_data_w) begin
					// o_dac_data_w = 16'b0;
					o_dac_data_w = o_dac_data_r;
					o_valid_w = 1'b0;
				end else begin
					o_dac_data_w = o_dac_data_r;
					o_valid_w = o_valid_r;
				end

				if (!o_valid_r && o_valid_w) begin
					if (data_counter_r==4'b0) begin
						if (o_sram_addr_r == {20{1'b1}}) begin
							almost_finish_w = 1'b1;
							o_sram_addr_w = 20'b0;
						end else o_sram_addr_w = o_sram_addr_r+1'b1;
						prev_sram_data_w = i_sram_data;
					end else begin
						o_sram_addr_w = o_sram_addr_r;
						prev_sram_data_w = prev_sram_data_r;
					end

					if (data_counter_r==i_speed) begin
						data_counter_w = 4'b0;
					end else begin
						data_counter_w = data_counter_r + 1;
					end
				end else begin
					prev_sram_data_w = prev_sram_data_r;
					o_sram_addr_w = o_sram_addr_r;
					data_counter_w = data_counter_r;
				end
                if(!o_valid_r && o_valid_w && almost_finish_r) begin
                    finish_w = 1'b1;
                end else begin
                    finish_w = 1'b0;
                end
			end

		end
		S_PAUSE: begin
			state_w = i_stop || finish_r ? S_IDLE : 
					  i_start ? S_PLAY : S_PAUSE;
			o_sram_addr_w = o_sram_addr_r;
			o_dac_data_w = 16'b0;
			prev_sram_data_w = prev_sram_data_r;
			o_valid_w = 1'b0;
			data_counter_w = data_counter_r;
			finish_w = 1'b0;
		end
	endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		o_sram_addr_r <= 20'b0;
		o_dac_data_r <= 16'b0;
		prev_sram_data_r <= 16'b0;
		state_r <= 2'b0;
		o_valid_r <= 1'b0;
		new_data_r <= 1'b1;
		data_counter_r <= 4'b0;
		finish_r <= 1'b0;
		almost_finish_r <= 1'b0;
	end
	else begin
		o_sram_addr_r <= o_sram_addr_w;
		o_dac_data_r <= o_dac_data_w;
		prev_sram_data_r <= prev_sram_data_w;
		state_r <= state_w;
		o_valid_r <= o_valid_w;
		new_data_r <= new_data_w;
		data_counter_r <= data_counter_w;
		finish_r <= finish_w;
		almost_finish_r <= almost_finish_w;
	end
end

endmodule