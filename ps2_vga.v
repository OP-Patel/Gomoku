module ps2_vga (
    // Clock and Reset
    input CLOCK_50,
    input [3:0] KEY, // KEY[0] used as reset

    // PS/2 Interface
    inout PS2_CLK,
    inout PS2_DAT,

    // LEDs
    output [4:0] LEDR,

    // VGA Interface
    output [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
    output [7:0] VGA_R, VGA_G, VGA_B,
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
);
    // Movement signals from keyboard
    wire move_up_pulse, move_down_pulse, move_left_pulse, move_right_pulse, draw_pulse;

    // Instantiate the PS2_WASD module
    PS2_WASD ps2_wasd_inst (
        .CLOCK_50(CLOCK_50),
        .resetn(KEY[0]),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .move_up_pulse(move_up_pulse),
        .move_down_pulse(move_down_pulse),
        .move_left_pulse(move_left_pulse),
        .move_right_pulse(move_right_pulse),
        .draw_pulse(draw_pulse)
    );

    // LEDs for debugging
    assign LEDR[0] = move_up_pulse;
    assign LEDR[1] = move_left_pulse;
    assign LEDR[2] = move_down_pulse;
    assign LEDR[3] = move_right_pulse;
    assign LEDR[4] = draw_pulse;

    // Instantiate the VGA module with both hover and reset functionality
    vga_demo vga_demo_inst (
        .CLOCK_50(CLOCK_50),
        .resetn(KEY[0]),
        .move_up_pulse(move_up_pulse),
        .move_down_pulse(move_down_pulse),
        .move_left_pulse(move_left_pulse),
        .move_right_pulse(move_right_pulse),
        .draw_pulse(draw_pulse),
        .HEX5(HEX5),
        .HEX4(HEX4),
        .HEX3(HEX3),
        .HEX2(HEX2),
        .HEX1(HEX1),
        .HEX0(HEX0),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );
endmodule


module PS2_WASD (
    input CLOCK_50,
    input resetn,
    inout PS2_CLK,
    inout PS2_DAT,

    output reg move_up_pulse,
    output reg move_down_pulse,
    output reg move_left_pulse,
    output reg move_right_pulse,
    output reg draw_pulse
);

    wire [7:0] ps2_key_data;
    wire ps2_key_pressed;

    reg [1:0] state;
    parameter STATE_IDLE = 2'b00;
    parameter STATE_BREAK = 2'b01;

    // Instantiate the PS2 controller
    PS2_Controller PS2 (
        .CLOCK_50(CLOCK_50),
        .reset(~resetn),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .received_data(ps2_key_data),
        .received_data_en(ps2_key_pressed)
    );

    // State machine to handle make and break codes
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            state <= STATE_IDLE;
            move_up_pulse <= 0;
            move_down_pulse <= 0;
            move_left_pulse <= 0;
            move_right_pulse <= 0;
            draw_pulse <= 0;
        end else begin
            // Reset pulses
            move_up_pulse <= 0;
            move_down_pulse <= 0;
            move_left_pulse <= 0;
            move_right_pulse <= 0;
            draw_pulse <= 0;

            if (ps2_key_pressed) begin
                case (state)
                    STATE_IDLE: begin
                        if (ps2_key_data == 8'hF0) begin
                            state <= STATE_BREAK;
                        end else begin
                            // Key pressed
                            case (ps2_key_data)
                                8'h1D: move_up_pulse <= 1;      // W key
                                8'h1B: move_down_pulse <= 1;    // S key
                                8'h1C: move_left_pulse <= 1;    // A key
                                8'h23: move_right_pulse <= 1;   // D key
                                8'h5A: draw_pulse <= 1;         // Enter key
                            endcase
                        end
                    end
                    STATE_BREAK: begin
                        state <= STATE_IDLE;
                        // Do nothing on key release
                    end
                endcase
            end
        end
    end
endmodule

module vga_demo(
    input CLOCK_50,
    input resetn,
    input move_up_pulse,
    input move_down_pulse,
    input move_left_pulse,
    input move_right_pulse,
    input draw_pulse,
    output [6:0] HEX5,
    output [6:0] HEX4,
    output [6:0] HEX3,
    output [6:0] HEX2,
    output [6:0] HEX1,
    output [6:0] HEX0,
    output [7:0] VGA_R,
    output [7:0] VGA_G,
    output [7:0] VGA_B,
    output VGA_HS,
    output VGA_VS,
    output VGA_BLANK_N,
    output VGA_SYNC_N,
    output VGA_CLK
);
    // Player turn: 0 - Red (Player 1), 1 - Blue (Player 2)
    reg player;
    wire [1:0] curr_player_code;
    assign curr_player_code = (player == 0) ? 2'b01 : 2'b11; // 01 for player 1 (Red), 11 for player 2 (Blue)

    // State machine states
    reg [2:0] state;
    parameter IDLE = 3'd0,
              ERASE_HOVER = 3'd1,
              DRAW_HOVER = 3'd2,
              CHECK_POSITION = 3'd3,
              DRAW_PIECE = 3'd4,
              RESTORE_BACKGROUND = 3'd5,
              GAME_OVER = 3'd6;

    // Coordinates
    reg [7:0] X;
    reg [6:0] Y;
    reg signed [8:0] VGA_X;
    reg signed [7:0] VGA_Y;
    reg [2:0] VGA_COLOR;

    // Drawing counters
    reg [2:0] XC, YC; // 0 to 4 for up to 5x5 square

    // Previous hover position
    reg [7:0] prev_X;
    reg [6:0] prev_Y;

    // Background restoration counters
    reg [14:0] bg_address;
    reg [7:0] restore_X;
    reg [6:0] restore_Y;

    // Control signals
    reg plot;

    // Define arrays for x and y values
    reg [7:0] x_array [0:12];
    reg [6:0] y_array [0:12];

    reg [3:0] i; // x index (0 to 12)
    reg [3:0] j; // y index (0 to 12)

    integer n, m;

    // Instantiate gomoku_mem module
    wire win_found;
    wire position_occupied;
    reg write_enable;
    reg game_reset; // Signal to reset the game

    gomoku_mem gomoku_mem_inst(
        .curr_player(curr_player_code),
        .board_x(i),
        .board_y(j),
        .clk(CLOCK_50),
        .write_enable(write_enable),
        .game_reset(game_reset),
        .win_found(win_found),
        .position_occupied(position_occupied)
    );

    // Game Over variables
    reg [7:0] go_X;
    reg [6:0] go_Y;
    wire [2:0] go_color;
    reg winner; // 0 for Player 1, 1 for Player 2

    // Instantiate the single Game Over ROM
    game_over_rom GameOverROM (
        .address((go_Y * 160) + go_X),
        .clock(CLOCK_50),
        .q(go_color)
    );

    // Initialize arrays and indices
    initial begin
        // Populate x_array
        for (n = 0; n <= 12; n = n + 1) begin
            x_array[n] = 8'd47 + 8'd6 * n; // X positions starting from 47, incremented by 6
        end
        // Populate y_array
        for (m = 0; m <= 12; m = m + 1) begin
            y_array[m] = 7'd31 + 7'd6 * m; // Y positions starting from 31, incremented by 6
        end
    end

    // Seven-segment display for coordinates or winner
    reg [3:0] hex_char5, hex_char4, hex_char3, hex_char2, hex_char1, hex_char0;

    always @(*) begin
        if (state == GAME_OVER) begin
            // Display "P1" or "P2" on HEX5 and HEX4
            hex_char5 = 4'd0; // 'P'
            hex_char4 = (winner == 1'b0) ? 4'd1 : 4'd2; // '1' or '2' depending on winner
            // Set other HEX displays to blank
            hex_char3 = 4'd7; // ' ' (space)
            hex_char2 = 4'd7; // ' ' (space)
            hex_char1 = 4'd7; // ' ' (space)
            hex_char0 = 4'd7; // ' ' (space)
        end else begin
            // Display current position coordinates on HEX3 to HEX0
            hex_char5 = 4'd7; // ' ' (space)
            hex_char4 = 4'd7; // ' ' (space)
            hex_char3 = X[7:4];
            hex_char2 = X[3:0];
            hex_char1 = {1'b0, Y[6:4]};
            hex_char0 = Y[3:0];
        end
    end

    // Use the hex7seg_alpha module for letters and numbers
    hex7seg_alpha H5 (hex_char5, HEX5);
    hex7seg_alpha H4 (hex_char4, HEX4);
    hex7seg H3 (hex_char3, HEX3);
    hex7seg H2 (hex_char2, HEX2);
    hex7seg H1 (hex_char1, HEX1);
    hex7seg H0 (hex_char0, HEX0);

    // Background ROM instantiation
    wire [2:0] bg_color;

    background_rom BG_ROM (
        .address(bg_address),
        .clock(CLOCK_50),
        .q(bg_color)
    );

    // Initialize player and state
    always @(posedge CLOCK_50 or negedge resetn) begin
        if (!resetn) begin
            player <= 1'b0; // Start with player 0 (Player 1)
            state <= RESTORE_BACKGROUND;
            bg_address <= 15'd0;
            plot <= 1'b0;
            XC <= 3'd0;
            YC <= 3'd0;
            restore_X <= 8'd0;
            restore_Y <= 7'd0;
            // Initialize indices and X, Y
            i <= 0;
            j <= 0;
            X <= x_array[0];
            Y <= y_array[0];
            prev_X <= X;
            prev_Y <= Y;
            write_enable <= 0;
            game_reset <= 1'b0; // Initialize game_reset
            winner <= 1'b0;
            go_X <= 0;
            go_Y <= 0;
        end else begin
            // Update X and Y based on indices
            X <= x_array[i];
            Y <= y_array[j];
            case (state)
                IDLE: begin
                    plot <= 1'b0;
                    write_enable <= 0;
                    game_reset <= 1'b0; // Ensure game_reset is low in IDLE
                    if (move_up_pulse && j > 0) begin
                        prev_X <= X;
                        prev_Y <= Y;
                        j <= j - 1;
                        state <= ERASE_HOVER;
                        XC <= 0;
                        YC <= 0;
                    end else if (move_down_pulse && j < 12) begin
                        prev_X <= X;
                        prev_Y <= Y;
                        j <= j + 1;
                        state <= ERASE_HOVER;
                        XC <= 0;
                        YC <= 0;
                    end else if (move_left_pulse && i > 0) begin
                        prev_X <= X;
                        prev_Y <= Y;
                        i <= i - 1;
                        state <= ERASE_HOVER;
                        XC <= 0;
                        YC <= 0;
                    end else if (move_right_pulse && i < 12) begin
                        prev_X <= X;
                        prev_Y <= Y;
                        i <= i + 1;
                        state <= ERASE_HOVER;
                        XC <= 0;
                        YC <= 0;
                    end else if (draw_pulse) begin
                        state <= CHECK_POSITION;
                    end
                end
                ERASE_HOVER: begin
                    plot <= 1'b1;
                    // Calculate position (centered)
                    VGA_X <= $signed({1'b0, prev_X}) + $signed({1'b0, XC}) - 2'sd1;
                    VGA_Y <= $signed({1'b0, prev_Y}) + $signed({1'b0, YC}) - 2'sd1;
                    // Set VGA_COLOR to white
                    VGA_COLOR <= 3'b111; // White color for background
                    // Update counters
                    if (XC == 2'd2) begin
                        XC <= 0;
                        if (YC == 2'd2) begin
                            YC <= 0;
                            state <= DRAW_HOVER;
                        end else begin
                            YC <= YC + 1;
                        end
                    end else begin
                        XC <= XC + 1;
                    end
                end
                DRAW_HOVER: begin
                    plot <= 1'b1;
                    // Calculate position (centered)
                    VGA_X <= $signed({1'b0, X}) + $signed({1'b0, XC}) - 2'sd1;
                    VGA_Y <= $signed({1'b0, Y}) + $signed({1'b0, YC}) - 2'sd1;
                    // Set VGA_COLOR to green
                    VGA_COLOR <= 3'b010; // Green color for hover
                    // Update counters
                    if (XC == 2'd2) begin
                        XC <= 0;
                        if (YC == 2'd2) begin
                            YC <= 0;
                            state <= IDLE;
                        end else begin
                            YC <= YC + 1;
                        end
                    end else begin
                        XC <= XC + 1;
                    end
                end
                CHECK_POSITION: begin
                    // Check if position is occupied
                    if (position_occupied == 0) begin
                        // Position is free, proceed to draw
                        write_enable <= 1; // Enable writing to game_board
                        state <= DRAW_PIECE;
                        XC <= 0;
                        YC <= 0;
                    end else begin
                        // Position is occupied, do nothing
                        write_enable <= 0;
                        state <= IDLE;
                    end
                end
                DRAW_PIECE: begin
                    plot <= 1'b1;
                    write_enable <= 0; // Disable write after updating
                    // Calculate position (centered)
                    VGA_X <= $signed({1'b0, X}) + $signed({1'b0, XC}) - 3'sd2;
                    VGA_Y <= $signed({1'b0, Y}) + $signed({1'b0, YC}) - 3'sd2;
                    // Set VGA_COLOR based on player
                    VGA_COLOR <= (player == 1'b0) ? 3'b100 : 3'b001; // Red or Blue
                    // Update counters
                    if (XC == 3'd4) begin
                        XC <= 0;
                        if (YC == 3'd4) begin
                            YC <= 0;
                            // After drawing, check for win condition
                            if (win_found) begin
                                // Handle win condition
                                state <= GAME_OVER;
                                go_X <= 0;
                                go_Y <= 0;
                                winner <= player; // Store the winning player
                            end else begin
                                // No win, switch player
                                player <= ~player; // Switch player
                                state <= DRAW_HOVER; // Draw hover at the current position
                            end
                        end else begin
                            YC <= YC + 1;
                        end
                    end else begin
                        XC <= XC + 1;
                    end
                end
                GAME_OVER: begin
                    plot <= 1'b1;
                    // Set VGA_X and VGA_Y
                    VGA_X <= go_X;
                    VGA_Y <= go_Y;
                    // Set VGA_COLOR from game over ROM
                    VGA_COLOR <= go_color;
                    // Update counters
                    if (go_X == 8'd159) begin
                        go_X <= 0;
                        if (go_Y == 7'd119) begin
                            go_Y <= 0;
                            // Continue displaying the image
                        end else begin
                            go_Y <= go_Y + 1;
                        end
                    end else begin
                        go_X <= go_X + 1;
                    end
                    // Continuously check for Enter key to restart
                    if (draw_pulse) begin
                        game_reset <= 1'b1; // Reset the game
                        state <= RESTORE_BACKGROUND;
                        restore_X <= 0;
                        restore_Y <= 0;
                    end
                end
                RESTORE_BACKGROUND: begin
                    plot <= 1'b1;
                    VGA_X <= restore_X;
                    VGA_Y <= restore_Y;
                    VGA_COLOR <= bg_color;
                    // Calculate bg_address from restore_X and restore_Y
                    bg_address <= (restore_Y * 160) + restore_X;
                    // Update counters
                    if (restore_X == 8'd159) begin
                        restore_X <= 0;
                        if (restore_Y == 7'd119) begin
                            restore_Y <= 0;
                            state <= DRAW_HOVER;
                            game_reset <= 1'b0; // Deassert game_reset after resetting
                            player <= 1'b0; // Reset to player 0 (Player 1)
                            // Reset indices and X, Y
                            i <= 0;
                            j <= 0;
                            X <= x_array[0];
                            Y <= y_array[0];
                            prev_X <= X;
                            prev_Y <= Y;
                        end else begin
                            restore_Y <= restore_Y + 1;
                        end
                    end else begin
                        restore_X <= restore_X + 1;
                    end
                end
                default: state <= state; // Hold state
            endcase
        end
    end

    // VGA Adapter instance
    vga_adapter VGA (
        .resetn(resetn),
        .clock(CLOCK_50),
        .colour(VGA_COLOR),
        .x(VGA_X_unsigned),
        .y(VGA_Y_unsigned),
        .plot(plot),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK)
    );
    defparam VGA.RESOLUTION = "160x120";
    defparam VGA.MONOCHROME = "FALSE";
    defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
    defparam VGA.BACKGROUND_IMAGE = "image.mif"; // Your background MIF file

    // Convert signed VGA_X and VGA_Y to unsigned for VGA adapter
    wire [7:0] VGA_X_unsigned;
    wire [6:0] VGA_Y_unsigned;
    assign VGA_X_unsigned = (VGA_X >= 0) ? VGA_X[7:0] : 8'd0;
    assign VGA_Y_unsigned = (VGA_Y >= 0) ? VGA_Y[6:0] : 7'd0;
endmodule


module hex7seg_alpha (
    input [3:0] char,
    output reg [6:0] display
);
    /*
     * Map:
     * 0: 'P'
     * 1: '1'
     * 2: '2'
     * 3: '-'
     * 4: 'W'
     * 5: 'L'
     * 6: 'N'
     * 7: ' ' (space)
     */
    always @(*) begin
        case (char)
            4'd0: display = 7'b0001100; // 'P'
            4'd1: display = 7'b1111001; // '1'
            4'd2: display = 7'b0100100; // '2'
            4'd3: display = 7'b0111111; // '-'
            4'd4: display = 7'b1000001; // 'W'
            4'd5: display = 7'b1100011; // 'L'
            4'd6: display = 7'b1001000; // 'N'
            4'd7: display = 7'b1111111; // ' ' (space)
            default: display = 7'b1111111; // Blank
        endcase
    end
endmodule


module game_over_rom (
    input [14:0] address,
    input clock,
    output reg [2:0] q
);
    // ROM implementation using altsyncram
    altsyncram GameOverROM (
        .address_a(address),
        .clock0(clock),
        .q_a(q),
        .wren_a(1'b0), // Read-only
        .data_a(3'b0)  // Unused
    );
    defparam
        GameOverROM.operation_mode = "ROM",
        GameOverROM.width_a = 3,
        GameOverROM.widthad_a = 15,
        GameOverROM.numwords_a = 19200, // 160 x 120 resolution
        GameOverROM.init_file = "game_over.mif", // Your single Game Over MIF file
        GameOverROM.outdata_reg_a = "CLOCK0",
        GameOverROM.address_reg_a = "CLOCK0",
        GameOverROM.clock_enable_input_a = "BYPASS",
        GameOverROM.clock_enable_output_a = "BYPASS",
        GameOverROM.intended_device_family = "Cyclone II";
endmodule


module regn(R, Resetn, E, Clock, Q);
    parameter n = 8;
    input [n-1:0] R;
    input Resetn, E, Clock;
    output reg [n-1:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= 0;
        else if (E)
            Q <= R;
endmodule

module count (Clock, Resetn, E, Q);
    parameter n = 8;
    input Clock, Resetn, E;
    output reg [n-1:0] Q;

    always @ (posedge Clock)
        if (Resetn == 0)
            Q <= 0;
        else if (E)
            Q <= Q + 1;
endmodule

module hex7seg (hex, display);
    input [3:0] hex;
    output reg [6:0] display;

    /*
     *       0  
     *      ---  
     *     |   |
     *    5|   |1
     *     | 6 |
     *      ---  
     *     |   |
     *    4|   |2
     *     |   |
     *      ---  
     *       3  
     */
    always @(*) begin
        case (hex)
            4'h0: display = 7'b1000000;
            4'h1: display = 7'b1111001;
            4'h2: display = 7'b0100100;
            4'h3: display = 7'b0110000;
            4'h4: display = 7'b0011001;
            4'h5: display = 7'b0010010;
            4'h6: display = 7'b0000010;
            4'h7: display = 7'b1111000;
            4'h8: display = 7'b0000000;
            4'h9: display = 7'b0011000;
            4'hA: display = 7'b0001000;
            4'hB: display = 7'b0000011;
            4'hC: display = 7'b1000110;
            4'hD: display = 7'b0100001;
            4'hE: display = 7'b0000110;
            4'hF: display = 7'b0001110;
            default: display = 7'b1111111; // Blank
        endcase
    end
endmodule

module background_rom (
    input [14:0] address,
    input clock,
    output reg [2:0] q
);
    // ROM implementation using altsyncram
    altsyncram BackgroundROM (
        .address_a(address),
        .clock0(clock),
        .q_a(q),
        .wren_a(1'b0), // Read-only
        .data_a(3'b0)  // Unused
    );
    defparam
        BackgroundROM.operation_mode = "ROM",
        BackgroundROM.width_a = 3,
        BackgroundROM.widthad_a = 15,
        BackgroundROM.numwords_a = 19200, // 160 x 120 resolution
        BackgroundROM.init_file = "image.mif", // Your background MIF file
        BackgroundROM.outdata_reg_a = "CLOCK0",
        BackgroundROM.address_reg_a = "CLOCK0",
        BackgroundROM.clock_enable_input_a = "BYPASS",
        BackgroundROM.clock_enable_output_a = "BYPASS",
        BackgroundROM.intended_device_family = "Cyclone II";
endmodule


module gomoku_mem(
    input [1:0] curr_player,    // 2 bits: 01 for P1, 11 for P2
    input [3:0] board_x,        // X coordinate on the board (0-12)
    input [3:0] board_y,        // Y coordinate on the board (0-12)
    input clk,                  // Clock signal
    input write_enable,         // Signal to update the board
    input game_reset,           // Signal to reset the game board
    output reg win_found,       // Win signal (1 if a win is detected)
    output reg position_occupied // 1 if the position is occupied
);
    // Flattened game board: 13 x 13 = 169 positions
    reg [1:0] game_board [0:168];  // Single-dimensional array

    integer i, j;

    // Helper function to calculate index
    function integer index;
        input integer row;
        input integer col;
        begin
            if (row >= 0 && row <= 12 && col >= 0 && col <= 12)
                index = row * 13 + col;
            else
                index = -1; // Invalid index
        end
    endfunction

    // Initialize the board or write to it
    always @(posedge clk or posedge game_reset) begin
        if (game_reset) begin
            for (i = 0; i < 169; i = i + 1) begin
                game_board[i] <= 2'b00;  // Empty cells
            end
        end else if (write_enable) begin
            game_board[index(board_x, board_y)] <= curr_player;
        end
    end

    // Update position_occupied
    always @(*) begin
        if (index(board_x, board_y) != -1 && game_board[index(board_x, board_y)] != 2'b00)
            position_occupied = 1;
        else
            position_occupied = 0;
    end

    // Check for win conditions
    integer row, col;
    integer idx0, idx1, idx2, idx3, idx4;
    always @(*) begin
        win_found = 0; // Reset win signal
        for (row = 0; row < 13; row = row + 1) begin
            for (col = 0; col < 13; col = col + 1) begin
                idx0 = index(row, col);
                if (idx0 != -1 && game_board[idx0] == curr_player) begin
                    // Horizontal check
                    if (col <= 8) begin
                        idx1 = index(row, col+1);
                        idx2 = index(row, col+2);
                        idx3 = index(row, col+3);
                        idx4 = index(row, col+4);
                        if (idx1 != -1 && idx2 != -1 && idx3 != -1 && idx4 != -1 &&
                            game_board[idx1] == curr_player &&
                            game_board[idx2] == curr_player &&
                            game_board[idx3] == curr_player &&
                            game_board[idx4] == curr_player)
                            win_found = 1;
                    end

                    // Vertical check
                    if (row <= 8) begin
                        idx1 = index(row+1, col);
                        idx2 = index(row+2, col);
                        idx3 = index(row+3, col);
                        idx4 = index(row+4, col);
                        if (idx1 != -1 && idx2 != -1 && idx3 != -1 && idx4 != -1 &&
                            game_board[idx1] == curr_player &&
                            game_board[idx2] == curr_player &&
                            game_board[idx3] == curr_player &&
                            game_board[idx4] == curr_player)
                            win_found = 1;
                    end

                    // Diagonal (\) check
                    if (row <= 8 && col <= 8) begin
                        idx1 = index(row+1, col+1);
                        idx2 = index(row+2, col+2);
                        idx3 = index(row+3, col+3);
                        idx4 = index(row+4, col+4);
                        if (idx1 != -1 && idx2 != -1 && idx3 != -1 && idx4 != -1 &&
                            game_board[idx1] == curr_player &&
                            game_board[idx2] == curr_player &&
                            game_board[idx3] == curr_player &&
                            game_board[idx4] == curr_player)
                            win_found = 1;
                    end

                    // Diagonal (/) check
                    if (row >= 4 && col <= 8) begin
                        idx1 = index(row-1, col+1);
                        idx2 = index(row-2, col+2);
                        idx3 = index(row-3, col+3);
                        idx4 = index(row-4, col+4);
                        if (idx1 != -1 && idx2 != -1 && idx3 != -1 && idx4 != -1 &&
                            game_board[idx1] == curr_player &&
                            game_board[idx2] == curr_player &&
                            game_board[idx3] == curr_player &&
                            game_board[idx4] == curr_player)
                            win_found = 1;
                    end
                end
            end
        end
    end
endmodule
