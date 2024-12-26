# Gomoku on DE1-SoC Board (FPGA) 

This project interfaces a PS/2 keyboard with a VGA display to play a Gomoku-like board game. Players alternate turns placing pieces on a grid using W, A, S, D keys to move a hover cursor, and Enter to place a piece. The board and game state are visually rendered on a VGA output. When a player manages to place five pieces in a row, the game displays a "Game Over" screen with the winning player. Watch the demo video [**here**](https://youtu.be/EJexmlcnT-0)!

## Features

- **Keyboard Control (W, A, S, D, Enter)**:  
  - **W**: Move the hover cursor up  
  - **A**: Move left  
  - **S**: Move down  
  - **D**: Move right  
  - **Enter**: Place a piece at the current hover location (if empty)
- **Two-Player Gameplay**:  
  - Player 1’s pieces are rendered in red, Player 2’s in blue.  
  - Turn-taking is automatically handled.
- **Automatic Win Detection**:  
  - Checks horizontally, vertically, and diagonally for five-in-a-row.
  - Displays a "Game Over" screen when a player wins.
- **Reset and Background**:  
  - Pressing Enter during the "Game Over" screen resets the game and restores the background.
- **VGA Output**:  
  - Renders a 160x120 background image, hover cursor, placed pieces, and "Game Over" screen.
  
## File Overview

- **`ps2_vga.v`**: Top-level module connecting the keyboard interface and VGA logic.
- **`PS2_WASD.v`**: Handles PS/2 keyboard input and generates movement pulses.
- **`vga_demo.v`**: Core VGA rendering logic including drawing the board, pieces, hover cursor, and contains the main-game FSM.
- **`gomoku_mem.v`**: Memory and logic for the game board, checking occupancy, and detecting player wins.
- **ROM/Adapter Modules (`background_rom.v`, `game_over_rom.v`, `vga_adapter.v`, etc.)**:  
  - Provide background and game-over image data.
  - Handle VGA/keyboard signal generation and communication.
- **Memory Initialization Files (`image.mif`, `game_over.mif`, `object_mem.mif`)**:  
  - Contain the pixel data for background and game-over screens or other objects.

## Block Diagrams
Block diagrams for **`gomoku_mem.v`**, **`PS2_WASD.v`**, the main-game FSM found within **`vga_demo.v`**, and a high-level project block diagram can be found [**here**](https://docs.google.com/document/d/16CnQp3Ij9zuvQUb1nEHMCtwqfIvziVVkCQLgNkoHS74/edit?usp=sharing)! 


## Getting Started

1. **Open the Project in Quartus**:  
   Use `DE1_SoC.qsf` (or the appropriate QSF file) to load pin assignments and project settings.

2. **Compile**:  
   Run the Quartus compilation flow. Ensure that the `image.mif` and `game_over.mif` files are present to generate the correct ROM contents.

3. **Program the FPGA**:  
   Once compiled, load the resulting `.sof` onto the DE1-SoC board.

4. **Connect Peripherals**:  
   - Connect a PS/2 keyboard to the board’s PS/2 port.
   - Connect a VGA monitor to the VGA output.

5. **Play the Game**:  
   - Use W, A, S, D to move the hover cursor.
   - Press Enter to place your piece.
   - Attempt to get 5 in a row to win!
