module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // cipher text y
	input  [255:0] i_d,
	input  [255:0] i_n,
	output [255:0] o_a_pow_d, // plain text x
	output         o_finished
);

    // operations for RSA256 decryption
    // namely, the Montgomery algorithm

    logic [1:0]   state_r, state_nxt_w;
    logic [255:0] t_r, m_r, t_nxt_w, m_nxt_w, a_r, a_w;
    logic [255:0] t_modulo_out_w, t_montgomary_out_w, m_montgomary_out_w;
    logic [15:0]  counter_r, counter_nxt_w;
    logic         finished_r, finished_nxt_w;

    assign o_a_pow_d = m_r;
    assign o_finished = finished_r;
    assign a_w = i_start ? i_a : a_r;

    ModuloProduct modulo(
	    .i_n(i_n),
	    .i_a(a_r),
	    .i_count(counter_r[7:0]),
	    .i_rst(i_rst),
	    .i_clk(i_clk),
	    .o_t(t_modulo_out_w)
    );

    MontAlgo mont_m(
	    .i_clk(i_clk),
	    .i_rst(i_rst),
	    .i_count(counter_r[7:0]),
	    .i_a(m_r), 
	    .i_b(t_r),
	    .i_n(i_n),
	    .o_ab(m_montgomary_out_w)
    );

    MontAlgo mont_t(
	    .i_clk(i_clk),
	    .i_rst(i_rst),
	    .i_count(counter_r[7:0]),
	    .i_a(t_r), 
	    .i_b(t_r),
	    .i_n(i_n),
	    .o_ab(t_montgomary_out_w)
    );

    //==============Seq part===========
    always_ff @(posedge i_clk) begin
	    if(i_rst) begin
		    state_r <= 2'b00;
		    t_r <= 0;
		    m_r <= 1;
		    counter_r <= 0;
		    finished_r <= 0;
            a_r <= 0;
	    end else begin
	    	state_r <= state_nxt_w;
		    t_r <= t_nxt_w;
		    m_r <= m_nxt_w;
		    counter_r <= counter_nxt_w;
		    finished_r <= finished_nxt_w;
            a_r <= a_w;
	    end 
    end

    //============Nxt state logic=====
    always_comb begin
    	case (state_r)
    		2'b00: begin
    			finished_nxt_w = 0;
    			if(i_start) begin
    				state_nxt_w = 2'b10;
    				t_nxt_w = 0;
    				m_nxt_w = 1;
    				counter_nxt_w = 0;
    			end
    			else begin
    				state_nxt_w = state_r;
    				t_nxt_w = t_r;
    				m_nxt_w = m_r;
    				counter_nxt_w = counter_r;
    			end
    		end

    		2'b10: begin
    			finished_nxt_w = finished_r;
    			if (counter_r == 16'b0000_0000_1111_1111) begin
    				state_nxt_w = 2'b11;
    				t_nxt_w = t_modulo_out_w;
    				m_nxt_w = 1;
    				counter_nxt_w = 0;
    			end
    			else begin
    				state_nxt_w = state_r;
    				t_nxt_w = t_r;
    				m_nxt_w = m_r;
    				counter_nxt_w = counter_r + 1;
    			end
    		end

    		2'b11: begin
    			counter_nxt_w = counter_r + 1;
    			if (counter_r == 16'b1111_1111_1111_1111) begin
    				state_nxt_w = 2'b00;
    				finished_nxt_w = 1;
    			end
    			else begin
    				state_nxt_w = state_r;
    				finished_nxt_w = finished_r;
    			end
    			 
    			if (counter_r[7:0] == 8'b1111_1111) begin
    				t_nxt_w = t_montgomary_out_w;
    				if (i_d[counter_r[15:8]]) begin
    					m_nxt_w = m_montgomary_out_w;
    				end
    				else begin
    					m_nxt_w = m_r;
    				end
    			end
    			else begin
    				t_nxt_w = t_r;
    				m_nxt_w = m_r;
    			end
    		end

    		default : begin
    			state_nxt_w = 2'b00;
    			t_nxt_w = t_r;
    			m_nxt_w = m_r;
    			counter_nxt_w = counter_r;
    			finished_nxt_w = finished_r;
    		end
    	endcase
    end

endmodule



module ModuloProduct(
	input  [255:0] i_n,
	input  [255:0] i_a,
	input  [7:0]   i_count,
	input          i_rst,
	input          i_clk,
	output [255:0] o_t
);

    logic [255:0] t_r, t_nxt_w;

    assign o_t = t_nxt_w;

    //===============Seq part============
    always_ff @(posedge i_clk) begin
	    if(i_rst) begin
		    t_r <= 0;
	    end else begin
		    t_r <= t_nxt_w;
	    end
    end

    //==============Nxt state=============
    always_comb begin
    	if (i_count==0) begin
    		if ({i_a, 1'b0} >= {1'b0, i_n}) begin
    			t_nxt_w = {i_a, 1'b0} - i_n;
    		end
    		else begin
    			t_nxt_w = {i_a[254:0], 1'b0};
    		end
    	end
    	else begin
    		if ({t_r, 1'b0} >= {1'b0, i_n}) begin
    			t_nxt_w = {t_r, 1'b0} - i_n;
    		end
    		else begin
    			t_nxt_w = {t_r[254:0], 1'b0};
    		end
    	end
    end

endmodule

module MontAlgo (
	input          i_clk,
	input          i_rst,
	input    [7:0] i_count,
	input  [255:0] i_a, 
	input  [255:0] i_b,
	input  [255:0] i_n,
	output [255:0] o_ab

);

	logic [256:0] m_w, m_w_1, m_w_2, m_w_3, m_w_4, m_w_5;
    logic [255:0] m_r;
	assign m_w_1 = (i_count == 8'b0)? 0: m_r;
	assign m_w_2 = (i_a[i_count] == 1'b1)? m_w_1 + i_b: m_w_1;
    assign m_w_3 = (m_w_2>=i_n)? m_w_2 - i_n: m_w_2;
	assign m_w_4 = (m_w_3[0] == 1'b1)? m_w_3 + i_n: m_w_3;
	// assign m_w_3 = (m_w_2[0] == 1'b0)? m_w_2: (m_w_2 < i_n)? m_w_2 + i_n: m_w_2 - i_n;
	assign m_w_5 = m_w_4 >> 1;
	assign m_w = (m_w_5>=i_n)? m_w_5 - i_n: m_w_5; 
	assign o_ab = m_w;


	always_ff @(posedge i_clk) begin 
		if(i_rst) begin
			m_r <= 256'b0;
		end else begin
			m_r <= m_w;
		end
	end

endmodule
