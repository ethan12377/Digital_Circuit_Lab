module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;
localparam CHANGE_KEY_SIGNAL = {256{1'b1}};

// Feel free to design your own FSM!
localparam S_QUERY_GET_N = 0;
localparam S_GET_N = 1;
localparam S_QUERY_GET_D = 2;
localparam S_GET_D = 3;
localparam S_QUERY_GET_DATA = 4;
localparam S_GET_DATA = 5;
localparam S_WAIT_CALCULATE = 6;
localparam S_QUERY_SEND_DATA = 7;
localparam S_SEND_DATA = 8;

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
logic [3:0] state_r, state_w;
logic [6:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8]; //dec_r[247:240]

Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r), //cipher text y
    .i_d(d_r),   //private key 
    .i_n(n_r),   //mod N
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
);

task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask
task StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask

always_comb begin
    // TODO
    n_w = n_r;
    d_w = d_r;
    enc_w = enc_r;
    dec_w = dec_r;
    avm_address_w = avm_address_r;
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    state_w = state_r;
    bytes_counter_w = bytes_counter_r;
    rsa_start_w = rsa_start_r;
    case (state_r)
        S_QUERY_GET_N: begin
            if (~avm_waitrequest & avm_readdata[RX_OK_BIT]) begin
                state_w = S_GET_N;
                bytes_counter_w = bytes_counter_r - 1;
                StartRead(RX_BASE);
            end
            else begin
                state_w = S_QUERY_GET_N;
                bytes_counter_w = bytes_counter_r;
                StartRead(STATUS_BASE);
            end
        end
        S_GET_N: begin
            if (~avm_waitrequest) begin
                n_w[(8 * bytes_counter_r + 7) -: 8] = avm_readdata[7:0];
                StartRead(STATUS_BASE);
                if (bytes_counter_r) begin
                    state_w = S_QUERY_GET_N;
                    bytes_counter_w = bytes_counter_r;
                end
                else begin
                    state_w = S_QUERY_GET_D;
                    bytes_counter_w = 32;
                end
            end
            else begin
                n_w = n_r;
                avm_address_w = avm_address_r;
                avm_read_w = avm_read_r;
                avm_write_w = avm_write_r;
                state_w = state_r;
                bytes_counter_w = bytes_counter_r;
            end
        end
        S_QUERY_GET_D: begin
            if (~avm_waitrequest & avm_readdata[RX_OK_BIT]) begin
                state_w = S_GET_D;
                bytes_counter_w = bytes_counter_r - 1;
                StartRead(RX_BASE);
            end
            else begin
                state_w = S_QUERY_GET_D;
                bytes_counter_w = bytes_counter_r;
                StartRead(STATUS_BASE);
            end
        end
        S_GET_D: begin
            d_w = d_r;
            if (~avm_waitrequest) begin
                d_w[(8 * bytes_counter_r + 7) -: 8] = avm_readdata[7:0];
                StartRead(STATUS_BASE);
                if (bytes_counter_r) begin
                    state_w = S_QUERY_GET_D;
                    bytes_counter_w = bytes_counter_r;
                end
                else begin
                    state_w = S_QUERY_GET_DATA;
                    bytes_counter_w = 32;
                end
            end
            else begin
                d_w = d_r;
                avm_address_w = avm_address_r;
                avm_read_w = avm_read_r;
                avm_write_w = avm_write_r;
                state_w = state_r;
                bytes_counter_w = bytes_counter_r;
            end
        end
        S_QUERY_GET_DATA: begin
            if (~avm_waitrequest & avm_readdata[RX_OK_BIT]) begin
                state_w = S_GET_DATA;
                bytes_counter_w = bytes_counter_r - 1;
                StartRead(RX_BASE);
            end
            else begin
                state_w = S_QUERY_GET_DATA;
                bytes_counter_w = bytes_counter_r;
                StartRead(STATUS_BASE);
            end
	    end
        S_GET_DATA: begin
            if (~avm_waitrequest) begin
                enc_w[(8 * bytes_counter_r + 7) -: 8] = avm_readdata[7:0];
                StartRead(STATUS_BASE);
                if (bytes_counter_r) begin
                    state_w = S_QUERY_GET_DATA;
                    rsa_start_w = 0;
                end
                else begin
		            if ({enc_r[255:8], avm_readdata[7:0]} == CHANGE_KEY_SIGNAL) begin
                        state_w = S_QUERY_GET_N;
                        rsa_start_w = 0;
                        bytes_counter_w = 32;
                    end
                    else begin
                        state_w = S_WAIT_CALCULATE;
                        rsa_start_w = 1;
                        bytes_counter_w = 31;
                    end
                end
            end
            else begin
                enc_w = enc_r;
                avm_address_w = avm_address_r;
                avm_read_w = avm_read_r;
                avm_write_w = avm_write_r;
                state_w = state_r;
                rsa_start_w = rsa_start_r;
            end
        end
        S_WAIT_CALCULATE: begin
            rsa_start_w = 0;
            if (rsa_finished) begin
                state_w = S_QUERY_SEND_DATA;
                dec_w = rsa_dec; 
            end
            else begin
                state_w = S_WAIT_CALCULATE;
                dec_w = dec_r;
            end
        end
        S_QUERY_SEND_DATA: begin
            if (~avm_waitrequest & avm_readdata[TX_OK_BIT]) begin
                state_w = S_SEND_DATA;
                bytes_counter_w = bytes_counter_r - 1;
                StartWrite(TX_BASE);
            end
            else begin
                state_w = S_QUERY_SEND_DATA;
                bytes_counter_w = bytes_counter_r;
                StartRead(STATUS_BASE);
            end
	    end
        S_SEND_DATA: begin
            if (~avm_waitrequest) begin
                dec_w = dec_r << 8;
                StartRead(STATUS_BASE);
                if (bytes_counter_r) begin
                    state_w = S_QUERY_SEND_DATA;
                    bytes_counter_w = bytes_counter_r;
                end
                else begin
                    state_w = S_QUERY_GET_DATA;
                    bytes_counter_w = 32;
                end
            end
            else begin
                dec_w = dec_r;
                avm_address_w = avm_address_r;
                avm_read_w = avm_read_r;
                avm_write_w = avm_write_r;
                state_w = state_r;
                bytes_counter_w = bytes_counter_r;
            end
        end
    endcase
end

always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_QUERY_GET_N;
        bytes_counter_r <= 32;
        rsa_start_r <= 0;
    end else begin
        n_r <= n_w;
        d_r <= d_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        bytes_counter_r <= bytes_counter_w;
        rsa_start_r <= rsa_start_w;
    end
end

endmodule
