module Top (
	input        i_clk,
	input        i_rst_n,
	input        i_start,
	output [3:0] o_random_out0,
	output [3:0] o_random_out1,
	output [3:0] o_random_out2,
	output [3:0] o_random_out3
);

// please check out the working example in lab1 README (or Top_exmaple.sv) first

	logic [3:0] random_out0_w, random_out1_w, random_out2_w, random_out3_w;
	logic gen_random_w;
	assign o_random_out0 = random_out0_w;
	assign o_random_out1 = random_out1_w;
	assign o_random_out2 = random_out2_w;
	assign o_random_out3 = random_out3_w;

	Control crtl(
		.i_clk(i_clk),
		.i_rst_n(i_rst_n),
		.i_start(i_start),
		.o_gen_random(gen_random_w)
	);

	LFSR LFSR(
		.i_clk(i_clk),
		.i_rst_n(i_rst_n),
		.i_gen_random(gen_random_w),
		.o_random_out(random_out0_w)
	);

	Memory mem0(
		.i_clk(i_clk),
		.i_rst_n(i_rst_n),
		.i_start(i_start),
		.i_random_out(random_out0_w),
		.o_random_out(random_out1_w)
	);

	Memory mem1(
		.i_clk(i_clk),
		.i_rst_n(i_rst_n),
		.i_start(i_start),
		.i_random_out(random_out1_w),
		.o_random_out(random_out2_w)
	);

	Memory mem2(
		.i_clk(i_clk),
		.i_rst_n(i_rst_n),
		.i_start(i_start),
		.i_random_out(random_out2_w),
		.o_random_out(random_out3_w)
	);

endmodule


module Memory(
	input		 i_clk,
	input		 i_rst_n,
	input		 i_start,
	input [3:0]  i_random_out,
	output [3:0] o_random_out
);

	logic [3:0] register_r, register_nxt_w;
	assign register_nxt_w = i_start ? i_random_out : register_r;
	assign o_random_out = register_r;
	always_ff @(posedge i_clk) begin
		if(~i_rst_n) begin
			register_r <= 0;
		end 
		else begin
			register_r <= register_nxt_w;
		end
	end

endmodule


module LFSR (
	input		 i_clk,
	input		 i_rst_n,
	input		 i_gen_random,
	output [3:0] o_random_out
);

	logic [14:0] register_r, register_nxt_w;
	assign register_nxt_w[13:0] = i_gen_random ? register_r[14:1] : register_r[13:0];
	assign register_nxt_w[14] = i_gen_random ? register_r[0] ^ register_r[14] : register_r[14];
	assign o_random_out = {register_r[9], register_r[8], register_r[1], register_r[0]};

	always_ff @(posedge i_clk) begin 
		if(~i_rst_n) begin
			register_r <= 15'b101_1000_1011_1100;
		end else begin
			register_r <= register_nxt_w;
		end
	end

endmodule


module Control (
	input		i_clk,
	input       i_rst_n,
	input       i_start,
	output		o_gen_random
);

	logic [26:0] counter_r, counter_nxt_w;
	logic state_r, state_nxt_w, o_gen_random_w;

	assign o_gen_random = o_gen_random_w;

	always_ff @(posedge i_clk) begin
		if(~i_rst_n) begin
			counter_r <= 0;
			state_r <= 1'b0;
		end 
		else begin
			counter_r <= counter_nxt_w;
			state_r <= state_nxt_w;
		end
	end

	always_comb begin

		// state and counter
		if(i_start) begin // key0 pushed
			counter_nxt_w = 0;
			state_nxt_w = 1'b1;
		end
		else if(&counter_r) begin // random num generated
			counter_nxt_w = 0;
			state_nxt_w = 1'b0;
		end
		else if(state_r) begin // state proc
			counter_nxt_w = counter_r +1;
			state_nxt_w = state_r;
		end
		else begin // state idle
			counter_nxt_w = 0;
			state_nxt_w = state_r;
		end

		// o_gen_random
		case(counter_r)
			27'b111_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b101_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b011_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b011_0111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b010_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b010_0111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_1101_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_1011_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_1001_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_0111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_0101_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_0011_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_0001_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_1101_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_1011_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_1001_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0101_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0011_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0001_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			/*27'b010_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b001_0111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_1111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_1011_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0111_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0101_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0011_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0010_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0001_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0001_0111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end*/
			27'b000_0000_1111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0000_1011_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0000_0111_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0000_0101_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0000_0011_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0000_0010_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			27'b000_0000_0001_1111_1111_1111_1111: begin
				o_gen_random_w = 1'b1;
			end
			default: begin
				o_gen_random_w = 1'b0;
			end
		endcase // counter_r

	end

endmodule
