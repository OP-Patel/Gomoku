module vga_controller(
    vga_clock, resetn, pixel_colour, memory_address,
    VGA_R, VGA_G, VGA_B,
    VGA_HS, VGA_VS, VGA_BLANK_N,
    VGA_SYNC_N, VGA_CLK
);

    parameter BITS_PER_COLOUR_CHANNEL = 1;
    parameter MONOCHROME = "FALSE";
    parameter RESOLUTION = "160x120";

    /* VGA timing parameters */
    parameter C_VERT_NUM_PIXELS  = 11'd480;
    parameter C_VERT_SYNC_START  = 11'd493;
    parameter C_VERT_SYNC_END    = 11'd494;
    parameter C_VERT_TOTAL_COUNT = 11'd525;

    parameter C_HORZ_NUM_PIXELS  = 11'd640;
    parameter C_HORZ_SYNC_START  = 11'd659;
    parameter C_HORZ_SYNC_END    = 11'd754;
    parameter C_HORZ_TOTAL_COUNT = 11'd800;

    /*****************************************************************************/
    /* Declare inputs and outputs.                                               */
    /*****************************************************************************/
    input vga_clock, resetn;
    input [((MONOCHROME == "TRUE") ? (0) : (BITS_PER_COLOUR_CHANNEL*3-1)):0] pixel_colour;
    output [((RESOLUTION == "320x240") ? (16) : (14)):0] memory_address;
    output reg [7:0] VGA_R;
    output reg [7:0] VGA_G;
    output reg [7:0] VGA_B;
    output reg VGA_HS;
    output reg VGA_VS;
    output reg VGA_BLANK_N;
    output VGA_SYNC_N, VGA_CLK;

    /*****************************************************************************/
    /* Internal wires and registers.                                             */
    /*****************************************************************************/
    reg VGA_HS1;
    reg VGA_VS1;
    reg VGA_BLANK1;
    reg [9:0] xCounter, yCounter;
    wire xCounter_clear;
    wire yCounter_clear;
    wire vcc;

    reg [((RESOLUTION == "320x240") ? (8) : (7)):0] x;
    reg [((RESOLUTION == "320x240") ? (7) : (6)):0] y;

    /*****************************************************************************/
    /* Controller implementation.                                                */
    /*****************************************************************************/
    assign vcc = 1'b1;

    /* Horizontal counter */
    always @(posedge vga_clock or negedge resetn) begin
        if (!resetn)
            xCounter <= 10'd0;
        else if (xCounter_clear)
            xCounter <= 10'd0;
        else
            xCounter <= xCounter + 1'b1;
    end
    assign xCounter_clear = (xCounter == (C_HORZ_TOTAL_COUNT-1));

    /* Vertical counter */
    always @(posedge vga_clock or negedge resetn) begin
        if (!resetn)
            yCounter <= 10'd0;
        else if (xCounter_clear) begin
            if (yCounter_clear)
                yCounter <= 10'd0;
            else
                yCounter <= yCounter + 1'b1;
        end
    end
    assign yCounter_clear = (yCounter == (C_VERT_TOTAL_COUNT-1));

    /* Coordinate calculation */
    always @(*) begin
        if (RESOLUTION == "320x240") begin
            x = xCounter[9:1];
            y = yCounter[8:1];
        end else begin
            x = xCounter[9:2];
            y = yCounter[8:2];
        end
    end

    /* Adjust x coordinate to fix offset */
    wire [((RESOLUTION == "320x240") ? 8 : 7):0] adjusted_x;
    assign adjusted_x = x + 8'd2; // Adding 2 to shift image to the left

    /* Address translation */
    vga_address_translator controller_translator(
        .x(adjusted_x), .y(y), .mem_address(memory_address)
    );
    defparam controller_translator.RESOLUTION = RESOLUTION;

    /* Synchronization signals */
    always @(posedge vga_clock) begin
        VGA_HS1 <= ~((xCounter >= C_HORZ_SYNC_START) && (xCounter <= C_HORZ_SYNC_END));
        VGA_VS1 <= ~((yCounter >= C_VERT_SYNC_START) && (yCounter <= C_VERT_SYNC_END));

        VGA_BLANK1 <= ((xCounter < C_HORZ_NUM_PIXELS) && (yCounter < C_VERT_NUM_PIXELS));

        VGA_HS <= VGA_HS1;
        VGA_VS <= VGA_VS1;
        VGA_BLANK_N <= VGA_BLANK1;
    end

    /* VGA sync should be 1 at all times */
    assign VGA_SYNC_N = vcc;

    /* VGA clock signal */
    assign VGA_CLK = vga_clock;

    /* Colour output */
    integer index;
    integer sub_index;
    wire on_screen;
    assign on_screen = (({1'b0, xCounter} < C_HORZ_NUM_PIXELS) & ({1'b0, yCounter} < C_VERT_NUM_PIXELS));

    always @(pixel_colour or on_screen) begin
        VGA_R <= 8'b0;
        VGA_G <= 8'b0;
        VGA_B <= 8'b0;
        if (MONOCHROME == "FALSE") begin
            for (index = 8 - BITS_PER_COLOUR_CHANNEL; index >= 0; index = index - BITS_PER_COLOUR_CHANNEL) begin
                for (sub_index = BITS_PER_COLOUR_CHANNEL - 1; sub_index >= 0; sub_index = sub_index - 1) begin
                    VGA_R[sub_index+index] <= on_screen & pixel_colour[sub_index + BITS_PER_COLOUR_CHANNEL*2];
                    VGA_G[sub_index+index] <= on_screen & pixel_colour[sub_index + BITS_PER_COLOUR_CHANNEL];
                    VGA_B[sub_index+index] <= on_screen & pixel_colour[sub_index];
                end
            end
        end else begin
            for (index = 0; index < 8; index = index + 1) begin
                VGA_R[index] <= on_screen & pixel_colour[0];
                VGA_G[index] <= on_screen & pixel_colour[0];
                VGA_B[index] <= on_screen & pixel_colour[0];
            end
        end
    end

endmodule
