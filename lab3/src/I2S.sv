module AudPlayer (
    input i_rst_n,
    input i_bclk,
    input i_daclrck,
    input i_en,
    input [15:0] i_dac_data,
    output o_aud_dacdat
);

localparam S_IDLE = 0;
localparam S_WAITH = 1;
localparam S_WAITL = 2;
localparam S_PLAY = 3;

logic [1:0] state_r, state_w;
logic [4:0] counter_r, counter_w;
logic dacdat_w, dacdat_r;

assign o_aud_dacdat = dacdat_r;

always_comb begin
    case (state_r)
        S_IDLE: begin
            if (i_en) state_w = (i_daclrck) ? S_WAITL : S_WAITH;
            else state_w = S_IDLE;
            counter_w = 15;
            dacdat_w = 0;
        end
        S_WAITH: begin //stay at LOW
            if (~i_en) state_w = S_IDLE;
            else if (i_daclrck) state_w = S_PLAY;
            else state_w = S_WAITH;
            counter_w = 15;
            dacdat_w = i_dac_data[15];
        end
        S_WAITL: begin //stay at HIGH
            if (~i_en) state_w = S_IDLE;
            else if (~i_daclrck) state_w = S_PLAY;
            else state_w = S_WAITL;
            counter_w = 15;
            dacdat_w = i_dac_data[15];
        end
        S_PLAY: begin
            if (~i_en) state_w = S_IDLE;
            else if (!counter_r) state_w = (i_daclrck) ? S_WAITL : S_WAITH;
            else state_w = S_PLAY;
            counter_w = counter_r - 1;
            dacdat_w = i_dac_data[counter_r-1];
        end
    endcase
end

always_ff @(posedge i_bclk or negedge i_rst_n) begin
    if (~i_rst_n) begin
        state_r <= S_IDLE;
        counter_r <= 15;
        dacdat_r <= 0;
    end
    else begin
        state_r <= state_w;
        counter_r <= counter_w;
        dacdat_r <= dacdat_w;
    end
end

endmodule

module AudRecorder (
    input i_rst_n,
    input i_clk,
    input i_lrc,
    input i_start,
    input i_pause,
    input i_stop,
    input i_data,
    output [19:0] o_address,
    output [15:0] o_data,
    output o_finish
);

localparam S_IDLE = 0;
localparam S_WAITH = 1;
localparam S_WAITL = 2;
localparam S_RECORD = 3;

logic [1:0] state_r, state_w;
logic [4:0] counter_r, counter_w;
logic [19:0] address_r, address_w;
logic [15:0] data_r, data_w;

assign o_address = address_r;
assign o_data = data_r;

always_comb begin
    o_finish = 0;
    case (state_r)
        S_IDLE: begin
            if (i_start) state_w = (i_lrc) ? S_WAITL : S_WAITH; //Since i_start may not trigger at anytime, we have to wait until the negedge of i_lrc to record 
            else state_w = S_IDLE;
            counter_w = 0;
            if (i_stop) address_w = 0;
            else address_w = address_r;
            data_w = 0;
        end
        S_WAITH: begin //stay at LOW
            if (i_pause) begin
                state_w = S_IDLE;
                address_w = address_r;
            end
            else if (i_stop) begin
                state_w = S_IDLE;
                address_w = 0;
            end
            else begin
                if (i_lrc) state_w = S_WAITL;
                else state_w = S_WAITH;
                address_w = address_r;
            end
            counter_w = 0;
            data_w = data_r;
        end
        S_WAITL: begin //stay at HIGH
            if (i_pause) begin
                state_w = S_IDLE;
                address_w = address_r;
            end
            else if (i_stop) begin
                state_w = S_IDLE;
                address_w = 0;
            end
            else begin
                if (~i_lrc) begin 
                    state_w = S_RECORD;
                    address_w = address_r+1;
                end
                else begin 
                    state_w = S_WAITL;
                    address_w = address_r;
                end
            end
            counter_w = 0;
            data_w = data_r;
        end
        S_RECORD: begin //only record left channel
            if (i_pause) begin
                state_w = S_IDLE;
                address_w = address_r;
            end
            else if (i_stop | address_r == 20'b11111111111111111111) begin
                state_w = S_IDLE;
                address_w = 0;
                o_finish = 1;
            end
            else begin
                if (counter_r == 15) begin
                    state_w = S_WAITH;
                    address_w = address_r;
                end
                else begin
                    state_w = S_RECORD;
                    address_w = address_r;
                end
            end
            counter_w = counter_r + 1;
            data_w = {data_r[14:0], i_data};
        end
    endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
        state_r <= S_IDLE;
        counter_r <= 0;
        address_r <= 0-1;
        data_r <= 0;
    end
    else begin
        state_r <= state_w;
        counter_r <= counter_w;
        address_r <= address_w;
        data_r <= data_w;
    end
end

endmodule
