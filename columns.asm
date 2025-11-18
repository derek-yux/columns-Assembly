######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

##############################################################################
# Mutable Data
##############################################################################
fall_speed:
    .word 1000  # milliseconds between automatic falls
blocks_placed:
    .word 0  # Counter for blocks placed
game_paused:
    .word 0
pause_time_elapsed:
    .word 0
colors:
    .word 0xFF0000 # red
    .word 0x00FF00 # green
    .word 0x339FFF # blue
    .word 0xCC00FF # purple
    .word 0xFFFF00 # yellow
    .word 0xFFA500 # orange
    .word 0x777777 # grey for the playing field boundaries
saved_block:
    .word 0, 0, 0 # colors for the saved block
saved_block_exists:
    .word 0 # to check if the player can save another one or load
saved_block_activated:
    .word 0  # whether we will use the saved block on the next spawn
preview_addr:
    .word 0  # stores address of last-drawn preview
next_block:
    .word 0, 0, 0   # color1, color2, color3 for the next block
##############################################################################
# Code
##############################################################################
	.text
	.globl main

# Run the game.
main:
    jal display_difficulty_select
    
difficulty_wait:
    lw $t7, ADDR_KBRD
    lw $t9, 0($t7)
    beq $t9, 1, check_difficulty_key
    
    li $v0, 32
    li $a0, 50
    syscall
    j difficulty_wait

check_difficulty_key:
    lw $t2, 4($t7)
    beq $t2, 0x65, set_easy      # 'e'
    beq $t2, 0x6d, set_medium    # 'm'
    beq $t2, 0x68, set_hard      # 'h'
    j difficulty_wait

set_easy:
    la $t0, fall_speed
    li $t1, 1000  # 1 second
    sw $t1, 0($t0)
    j start_game

set_medium:
    la $t0, fall_speed
    li $t1, 600  # 0.6 seconds
    sw $t1, 0($t0)
    j start_game

set_hard:
    la $t0, fall_speed
    li $t1, 300  # 0.3 seconds
    sw $t1, 0($t0)
    j start_game

start_game:
    # Clear the screen first
    lw $t8, ADDR_DSPL
    li $t0, 0
    li $t1, 4096
    li $t6, 0x000000
clear_screen_start:
    beq $t0, $t1, init_game
    sw $t6, 0($t8)
    addi $t8, $t8, 4
    addi $t0, $t0, 1
    j clear_screen_start

init_game:
    lw $t0, ADDR_DSPL
    addi $t0, $t0, 552
    la $t1, colors
    jal boundary_generation

    jal new_block
    la $t0, next_block
    lw $s3, 0($t0)
    lw $s4, 4($t0)
    lw $s5, 8($t0)

    lw $s2, ADDR_DSPL
    addi $s2, $s2, 692
    jal new_block
    
    # Initialize timer for automatic falling
    li $v0, 30
    syscall
    move $s7, $a0  # Store last fall time in $s7
    
    jal game_loop

boundary_generation:
    li $t6, 6
    sll $t2, $t6, 2
    add $t3, $t1, $t2
    lw $t7, 0($t3)

    li $t6, 0
    li $t5, 8
    move $t8, $t0

horizontal_loop_top:
    beq $t6, $t5, draw_left
    sw $t7, 0($t0)
    addi $t0, $t0, 4
    addi $t6, $t6, 1
    j horizontal_loop_top

draw_left:
    move $t0, $t8
    li $t6, 0
    li $t5, 18

vertical_loop_left:
    beq $t6, $t5, draw_bottom
    sw $t7, 0($t0)
    addi $t0, $t0, 128
    addi $t6, $t6, 1
    j vertical_loop_left

draw_bottom:
    addi $t0, $t8, 2176
    li $t6, 0
    li $t5, 8

horizontal_loop_bottom:
    beq $t6, $t5, draw_right
    sw $t7, 0($t0)
    addi $t0, $t0, 4
    addi $t6, $t6, 1
    j horizontal_loop_bottom

draw_right:
    addi $t0, $t8, 28
    li $t6, 0
    li $t5, 18

vertical_loop_right:
    beq $t6, $t5, exit
    sw $t7, 0($t0)
    addi $t0, $t0, 128
    addi $t6, $t6, 1
    j vertical_loop_right

exit:
    jr $ra

new_block:
    la $t1, colors

    # color 1
    li $v0, 42
    li $a1, 6
    li $a0, 0
    syscall
    move $t7, $a0
    sll $t2, $t7, 2
    add $t3, $t1, $t2
    lw $t4, 0($t3)
    la $t0, next_block
    sw $t4, 0($t0)

    # color 2
    li $v0, 42
    li $a0, 0
    syscall
    move $t7, $a0
    sll $t2, $t7, 2
    add $t3, $t1, $t2
    lw $t4, 0($t3)
    la $t0, next_block
    sw $t4, 4($t0)

    # color 3
    li $v0, 42
    li $a0, 0
    syscall
    move $t7, $a0
    sll $t2, $t7, 2
    add $t3, $t1, $t2
    lw $t4, 0($t3)
    la $t0, next_block
    sw $t4, 8($t0)

    jr $ra

game_loop:
    move $s6, $s2
    
    # Check if game is paused
    la $t0, game_paused
    lw $t1, 0($t0)
    beq $t1, 1, pause_loop
    
    # Check current time
    li $v0, 30
    syscall
    move $t8, $a0
    
    # Calculate elapsed time since last fall
    sub $t9, $t8, $s7
    
    la $t6, fall_speed
    lw $t7, 0($t6)
    
    blt $t9, $t7, check_keyboard
    
    # Time to fall automatically
    move $s7, $t8
    jal clear_previous_preview
    jal check_collision
    beq $v0, 1, spawn_new_block
    addi $s2, $s2, 128
    j update_screen

check_keyboard:
    lw $t7, ADDR_KBRD
    lw $t9, 0($t7)
    beq $t9, 1, keyboard_input

update_screen:
    li $s1, 0x000000 
    sw $s1, 0($s6)
    sw $s1, 128($s6)
    sw $s1, 256($s6)
    
    jal compute_and_draw_preview
    jal display_next_preview
    
    sw $s3, 0($s2)
    sw $s4, 128($s2)
    sw $s5, 256($s2)
    
    li $v0, 32
    li $a0, 17
    syscall

    j game_loop

check_game_over:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 552
    addi $t8, $t8, 4
    
    li $t0, 0
check_top_row_loop:
    li $t1, 6
    beq $t0, $t1, no_game_over
    
    lw $t2, 0($t8)
    li $t3, 0x000000
    bne $t2, $t3, game_over_detected
    
    addi $t8, $t8, 4
    addi $t0, $t0, 1
    j check_top_row_loop

game_over_detected:
    li $v0, 1
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

no_game_over:
    li $v0, 0
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
# 1b. Check which key has been pressed
keyboard_input:
    lw $t2, 4($t7)
    beq $t2, 0x77, rotate
    beq $t2, 0x61, shift_left 
    beq $t2, 0x73, slam_down 
    beq $t2, 0x64, shift_right
    beq $t2, 0x70, toggle_pause
    beq $t2, 0x74, retrieve_saved  # 't' key to retrieve saved block
    beq $t2, 0x79, save_current    # 'y' key to save current block
    beq $t2, 0x71, exit_game
    j update_screen

rotate:
    move $t3, $s3
    move $t4, $s4
    move $t5, $s5
    move $s3, $t5
    move $s4, $t3
    move $s5, $t4
    j update_screen

shift_left:
    jal clear_previous_preview
    # Check if at left boundary
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 552
    sub $t9, $s2, $t8
    li $t6, 128
    div $t9, $t6
    mfhi $t9
    # If remainder is 4, we're at the left boundary (first playable column)
    li $t6, 4
    beq $t9, $t6, early_return
    
    addi $t7, $s2, -4
    lw $t6, 0($t7)
    li $t8, 0x000000
    bne $t6, $t8, early_return  # Block to the left of top pixel
    
    addi $t7, $s2, 124
    lw $t6, 0($t7)
    bne $t6, $t8, early_return  # Block to the left of middle pixel
    
    addi $t7, $s2, 252
    lw $t6, 0($t7)
    bne $t6, $t8, early_return  # Block to the left of bottom pixel
    
    # Otherwise, shift left
    addi $s2, $s2, -4
    j update_screen

shift_right:
    jal clear_previous_preview
    # Check if at right boundary
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 552
    sub $t9, $s2, $t8
    li $t6, 128
    div $t9, $t6
    mfhi $t9
    # If remainder is 24, we're at the right boundary (last playable column)
    li $t6, 24
    beq $t9, $t6, early_return
    
    addi $t7, $s2, 4
    lw $t6, 0($t7)
    li $t8, 0x000000
    bne $t6, $t8, early_return  # Block to the right of top pixel
    
    addi $t7, $s2, 132
    lw $t6, 0($t7)
    bne $t6, $t8, early_return  # Block to the right of middle pixel
    
    addi $t7, $s2, 260
    lw $t6, 0($t7)
    bne $t6, $t8, early_return  # Block to the right of bottom pixel
    
    # Otherwise, shift right
    addi $s2, $s2, 4
    j update_screen

slam_down:
    jal clear_previous_preview
    jal check_collision
    beq $v0, 1, spawn_new_block  # If collision detected, spawn new block instead
    
    # Reset timer when manually moving down
    li $v0, 30
    syscall
    move $s7, $a0
    
    addi $s2, $s2, 128
    j update_screen

check_collision:
    # Check if the bottom of the current block would hit the bottom boundary or another block
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 552
    addi $t9, $t8, 2176

    sub $t6, $s2, $t8
    addi $t6, $t6, 256
    li $v0, 128
    div $t6, $v0
    mflo $t6
    
    li $v0, 16
    beq $t6, $v0, collision_detected
    
    addi $t9, $s2, 384
    lw $t6, 0($t9)
    li $t8, 0x000000
    bne $t6, $t8, collision_detected
    
    # No collision
    li $v0, 0
    jr $ra
    
collision_detected:
    li $v0, 1
    jr $ra

spawn_new_block:
    # Reset paused/not paused when spawning new block
    la $t0, game_paused
    li $t1, 0
    sw $t1, 0($t0)
    
    la $t0, blocks_placed
    lw $t1, 0($t0)
    addi $t1, $t1, 1
    sw $t1, 0($t0)
    
    # Every 5 blocks, increase speed by 10%
    li $t2, 5
    div $t1, $t2
    mflo $t3
    
    beqz $t3, skip_speed_increase
    
    # Calculate new speed: speed = speed * 0.9 (faster)
    la $t0, fall_speed
    lw $t4, 0($t0)
    li $t5, 9
    mult $t4, $t5
    mflo $t4
    li $t5, 10
    div $t4, $t5
    mflo $t4
    
    # Minimum speed of 100ms
    li $t5, 100
    blt $t4, $t5, set_min_speed
    sw $t4, 0($t0)
    j skip_speed_increase

set_min_speed:
    li $t4, 100
    sw $t4, 0($t0)

skip_speed_increase:
    jal check_and_eliminate_matches
    
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 692
    
    lw $t9, 0($t8)
    li $t6, 0x000000
    bne $t9, $t6, game_over
    
    lw $t9, 128($t8)
    bne $t9, $t6, game_over
    
    lw $t9, 256($t8)
    bne $t9, $t6, game_over
    
    la $t0, saved_block_exists
    lw $t1, 0($t0)
    beq $t1, 0, spawn_random_block
    
    # Only use saved block if player activated it (pressed 't')
    la $t0, saved_block_activated
    lw $t2, 0($t0)
    beq $t2, 0, spawn_random_block

    la $t0, saved_block
    lw $s3, 0($t0)
    lw $s4, 4($t0)
    lw $s5, 8($t0)

    la $t0, saved_block_exists
    li $t1, 0
    sw $t1, 0($t0)
    la $t0, saved_block_activated
    sw $t1, 0($t0)    # t1 == 0

    lw  $t8, ADDR_DSPL
    addi $t8, $t8, 1364
    li  $t9, 0x000000
    sw  $t9, 8($t8)
    sw  $t9, 136($t8)
    sw  $t9, 264($t8)

    jal display_saved_preview

    # Generate a new next_block now that we've consumed the saved one.
    jal new_block
    lw $s2, ADDR_DSPL
    addi $s2, $s2, 692

    j continue_spawn

spawn_random_block:
    la $t0, next_block
    lw $s3, 0($t0)
    lw $s4, 4($t0)
    lw $s5, 8($t0)
    lw $s2, ADDR_DSPL
    addi $s2, $s2, 692
    jal new_block

    j continue_spawn

continue_spawn:
    
    # Reset timer for new block
    li $v0, 30
    syscall
    move $s7, $a0
    
    jal clear_previous_preview
    
    sw $s3, 0($s2)
    sw $s4, 128($s2)
    sw $s5, 256($s2)
    
    li $v0, 32
    li $a0, 17
    syscall
    j game_loop

game_over:
    jal display_game_over
    
game_over_wait:
    # Wait for 'r' key to restart or 'q' to quit
    lw $t7, ADDR_KBRD
    lw $t9, 0($t7)
    beq $t9, 1, check_restart_key
    
    li $v0, 32
    li $a0, 50
    syscall
    j game_over_wait

check_restart_key:
    lw $t2, 4($t7)
    beq $t2, 0x72, restart_game  # 'r'
    beq $t2, 0x71, exit_game     # 'q'
    j game_over_wait

restart_game:
    # Clear the ENTIRE screen (all pixels, not just playable area), then I will redraw
    lw $t8, ADDR_DSPL
    li $t0, 0
    li $t1, 4096
    li $t6, 0x000000
clear_screen_loop:
    beq $t0, $t1, redraw_boundary
    sw $t6, 0($t8)
    addi $t8, $t8, 4
    addi $t0, $t0, 1
    j clear_screen_loop

redraw_boundary:
    lw $t0, ADDR_DSPL
    addi $t0, $t0, 552
    la $t1, colors
    jal boundary_generation
    
    # Restart the game from the beginning
    lw $s2, ADDR_DSPL
    addi $s2, $s2, 692
    # Reset blocks counter
    la $t0, blocks_placed
    li $t1, 0
    sw $t1, 0($t0)
    
    la $t0, saved_block_exists
    li $t1, 0
    sw $t1, 0($t0)
    
    la $t0, saved_block_activated
    li $t1, 0
    sw $t1, 0($t0)
    
    # Show difficulty selection again
    j main

display_difficulty_select:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 1288
    
    li $t9, 0x00FF00  # Green
    
    # These letters are for "EASY" (user presses 'e' to select)
    # E
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # A
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # S
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # Y
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 260($t8)
    sw $t9, 388($t8)
    sw $t9, 516($t8)
    
    # These letters are for "MEDIUM" (user presses 'm' to select)
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 2056
    li $t9, 0xFFFF00  # Yellow
    
    # M
    sw $t9, 0($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 132($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # E
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # D
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    
    # Finally, these letters are for "HARD" (user presses 'h' to select)
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 2824
    li $t9, 0xFF0000  # Red
    
    # H
    sw $t9, 0($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # A
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # R
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 388($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # D
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

display_game_over:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 1288
    
    # Use red color for "GAME OVER"
    li $t9, 0xFF0000
    
    # These letters are for the word "GAME"
    # G
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 268($t8)
    sw $t9, 384($t8)
    sw $t9, 396($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # A
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # M
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 132($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # E
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # These letters are for the word "OVER"
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 2184
    
    # O
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # V
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 516($t8)
    
    # E
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # R
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 388($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # "PRESS R" text
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 3080
    li $t9, 0xFFFF00  # Yellow color
    
    # P
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    
    # R
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 388($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # E
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # S
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # S
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    addi $t8, $t8, 24
    
    # R
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 388($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

check_and_eliminate_matches:
    addi $sp, $sp, -8
    sw   $ra, 0($sp)
    sw   $s7, 4($sp)
    
    # Keep checking for matches until none are found (after gravity iterates!)
check_matches_loop:
    li $s7, 0  # Flag to track if any matches found this iteration
    
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 552
    
    li $t0, 0  # Row counter from 0-16
check_row_loop:
    li $t9, 17
    beq $t0, $t9, check_if_matches_found
    
    li $t1, 0  # Column counter from 0-5
check_col_loop:
    li $t9, 6
    beq $t1, $t9, next_row
    
    # Calculate address: base + row*128 + (col+1)*4
    move $t2, $t0
    li $t3, 128
    mult $t2, $t3
    mflo $t2
    addi $t4, $t1, 1
    sll $t4, $t4, 2
    add $t2, $t2, $t4
    add $t2, $t8, $t2  # Actual address
    
    # Get color at this position
    lw $t5, 0($t2)
    li $t6, 0x000000
    beq $t5, $t6, skip_position  # Skip if black (i.e., we don't care)
    li $t6, 0x777777  # Check for grey boundary
    beq $t5, $t6, skip_position
    
    jal check_horizontal_match
    jal check_vertical_match
    jal check_diagonal_right_match
    jal check_diagonal_left_match
    
skip_position:
    addi $t1, $t1, 1
    j check_col_loop
    
next_row:
    addi $t0, $t0, 1
    j check_row_loop

check_if_matches_found:
    # If we found matches this iteration, apply gravity and check again
    beq $s7, 1, apply_gravity_and_recheck
    # Otherwise, we're done
    j finish_elimination

apply_gravity_and_recheck:
    jal apply_gravity_internal
    j check_matches_loop

apply_gravity_internal:
    # Apply gravity repeatedly until no blocks can fall further
gravity_outer_loop:
    li $s1, 0  # Flag to track if any block moved this pass
    
    # Apply one pass of gravity: move all non-black, non-grey pixels down one step
    li $t0, 15
gravity_row_loop:
    bltz $t0, check_gravity_complete
    
    li $t1, 0  # Column counter
gravity_col_loop:
    li $t9, 6
    beq $t1, $t9, next_gravity_row
    
    # Calculate address for current position
    move $t2, $t0
    li $t3, 128
    mult $t2, $t3
    mflo $t2
    addi $t4, $t1, 1
    sll $t4, $t4, 2
    add $t2, $t2, $t4
    add $t2, $t8, $t2
    
    # Get color at this position
    lw $t5, 0($t2)
    li $t6, 0x000000
    beq $t5, $t6, next_gravity_col  # Skip if black (we don't care)
    li $t6, 0x777777
    beq $t5, $t6, next_gravity_col  # Skip if grey (it's the boundary)
    
    addi $t7, $t2, 128

    addi $t6, $t0, 1
    li $t9, 17
    bge $t6, $t9, next_gravity_col  # At bottom, can't fall
    
    lw $t9, 0($t7)
    li $t6, 0x000000
    bne $t9, $t6, next_gravity_col  # Not empty below, can't fall
    
    # Move block down one row
    sw $t5, 0($t7)
    li $t6, 0x000000
    sw $t6, 0($t2)
    li $s1, 1

next_gravity_col:
    addi $t1, $t1, 1
    j gravity_col_loop

next_gravity_row:
    addi $t0, $t0, -1
    j gravity_row_loop

check_gravity_complete:
    # If any block moved this pass, do another pass
    beq $s1, 1, gravity_outer_loop
    # Otherwise, gravity is complete
    jr $ra

finish_elimination:
    lw $s7, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

check_horizontal_match:
    # Check if 3+ same colors to the right
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    li $t9, 1  # Counter (includes current pixel)
    move $t7, $t2
    move $t6, $t1
horiz_check_loop:
    addi $t6, $t6, 1
    li $a0, 6
    bge $t6, $a0, horiz_done  # Out of bounds
    
    addi $t7, $t7, 4
    lw $a1, 0($t7)
    bne $a1, $t5, horiz_done  # Different color
    
    addi $t9, $t9, 1
    j horiz_check_loop

horiz_done:
    li $a0, 3
    blt $t9, $a0, horiz_no_match
    
    # Set flag that we found a match
    li $s7, 1
    
    # Eliminate the matching pixels
    move $t7, $t2
    li $a0, 0x000000
horiz_eliminate_loop:
    sw $a0, 0($t7)
    addi $t7, $t7, 4
    addi $t9, $t9, -1
    bgtz $t9, horiz_eliminate_loop

horiz_no_match:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

check_vertical_match:
    # Check if 3+ same colors downward
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    li $t9, 1
    move $t7, $t2
    move $t6, $t0
vert_check_loop:
    addi $t6, $t6, 1
    li $a0, 17
    bge $t6, $a0, vert_done
    
    addi $t7, $t7, 128
    lw $a1, 0($t7)
    bne $a1, $t5, vert_done
    
    addi $t9, $t9, 1
    j vert_check_loop

vert_done:
    li $a0, 3
    blt $t9, $a0, vert_no_match
    
    # Set flag that we found a match
    li $s7, 1
    
    move $t7, $t2
    li $a0, 0x000000
vert_eliminate_loop:
    sw $a0, 0($t7)
    addi $t7, $t7, 128
    addi $t9, $t9, -1
    bgtz $t9, vert_eliminate_loop

vert_no_match:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

check_diagonal_right_match:
    # Check diagonal down-right
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)  # Save match count for elimination
    
    li $t9, 1
    move $t7, $t2
    move $t6, $t0
    move $a2, $t1
diag_r_check_loop:
    addi $t6, $t6, 1
    addi $a2, $a2, 1
    li $a0, 17
    bge $t6, $a0, diag_r_done
    li $a0, 6
    bge $a2, $a0, diag_r_done
    
    addi $t7, $t7, 132
    lw $a1, 0($t7)
    bne $a1, $t5, diag_r_done
    
    addi $t9, $t9, 1
    j diag_r_check_loop

diag_r_done:
    li $a0, 3
    blt $t9, $a0, diag_r_no_match
    
    # Set flag that we found a match
    li $s7, 1
    move $s0, $t9
    
    # Eliminate the matching pixels
    move $t7, $t2
    move $t6, $t0  # Row counter
    move $a2, $t1  # Column counter
    li $a0, 0x000000
diag_r_eliminate_loop:
    li $a1, 17
    bge $t6, $a1, diag_r_no_match
    li $a1, 6
    bge $a2, $a1, diag_r_no_match
    
    sw $a0, 0($t7)
    addi $t7, $t7, 132
    addi $t6, $t6, 1  # Next row
    addi $a2, $a2, 1  # Next col
    addi $s0, $s0, -1
    bgtz $s0, diag_r_eliminate_loop

diag_r_no_match:
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra

check_diagonal_left_match:
    # Check diagonal down-left
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)  # Save match count for elimination
    
    li $t9, 1
    move $t7, $t2
    move $t6, $t0
    move $a2, $t1
diag_l_check_loop:
    addi $t6, $t6, 1
    addi $a2, $a2, -1
    li $a0, 17
    bge $t6, $a0, diag_l_done
    bltz $a2, diag_l_done
    
    addi $t7, $t7, 124
    lw $a1, 0($t7)
    bne $a1, $t5, diag_l_done
    
    addi $t9, $t9, 1
    j diag_l_check_loop

diag_l_done:
    li $a0, 3
    blt $t9, $a0, diag_l_no_match
    
    # Set flag that we found a match
    li $s7, 1
    move $s0, $t9
    
    # Eliminate the matching pixels
    move $t7, $t2
    move $t6, $t0  # Row counter
    move $a2, $t1  # Col counter
    li $a0, 0x000000
diag_l_eliminate_loop:
    li $a1, 17
    bge $t6, $a1, diag_l_no_match
    bltz $a2, diag_l_no_match
    
    sw $a0, 0($t7)
    addi $t7, $t7, 124
    addi $t6, $t6, 1  # Next row down
    addi $a2, $a2, -1  # Next col left
    addi $s0, $s0, -1
    bgtz $s0, diag_l_eliminate_loop

diag_l_no_match:
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra

save_current:
    # Check if a block is already saved
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    la $t0, saved_block_exists
    lw $t1, 0($t0)
    bne $t1, $zero, sc_done   # If there's already a saved block, ignore

    # Save current block colors
    la $t0, saved_block
    sw $s3, 0($t0)
    sw $s4, 4($t0)
    sw $s5, 8($t0)

    la $t0, saved_block_exists
    li $t1, 1
    sw $t1, 0($t0)

    la $t0, saved_block_activated
    li $t1, 0
    sw $t1, 0($t0)

    # Clear current block from screen
    li $s1, 0x000000
    sw $s1, 0($s2)
    sw $s1, 128($s2)
    sw $s1, 256($s2)

    jal display_saved_preview

    la $t0, next_block
    lw $s3, 0($t0)
    lw $s4, 4($t0)
    lw $s5, 8($t0)

    # Reset states for the next block to be spawned in
    lw $s2, ADDR_DSPL
    addi $s2, $s2, 692

    jal new_block

    li $v0, 30
    syscall
    move $s7, $a0

sc_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j update_screen

retrieve_saved:
    # Check if we have a saved block
    la $t0, saved_block_exists
    lw $t1, 0($t0)
    beq $t1, 0, update_screen  # No saved block, ignore

    # Activate saved block for next spawn (i.e., player pressed 't')
    la $t0, saved_block_activated
    li $t1, 1
    sw $t1, 0($t0)

    # For the side preview
    la $t0, saved_block
    lw $t2, 0($t0)
    lw $t3, 4($t0)
    lw $t4, 8($t0)
    la $t0, next_block
    sw $t2, 0($t0)
    sw $t3, 4($t0)
    sw $t4, 8($t0)

    jal display_next_preview

    lw $t8, ADDR_DSPL
    addi $t8, $t8, 1364

    la $t0, saved_block
    lw $t2, 0($t0)
    lw $t3, 4($t0)
    lw $t4, 8($t0)

    sw $t2, 8($t8)
    sw $t3, 136($t8)
    sw $t4, 264($t8)

    j update_screen

display_next_preview:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t8, ADDR_DSPL
    addi $t8, $t8, 1300

    move $t9, $t8
    addi $t9, $t9, -776

    # Draw "N" for the "next" column preview
    li $t1, 0xFFFF00     # color (yellow)

    sw $t1, 0($t9)
    sw $t1, 16($t9)
    sw $t1, 128($t9)
    sw $t1, 132($t9)
    sw $t1, 144($t9)
    sw $t1, 256($t9)
    sw $t1, 264($t9)
    sw $t1, 272($t9)
    sw $t1, 384($t9)
    sw $t1, 396($t9)
    sw $t1, 400($t9)
    sw $t1, 512($t9)
    sw $t1, 528($t9)

    # Draw the next_block preview
    la $t0, next_block
    lw $t2, 0($t0)
    lw $t3, 4($t0)
    lw $t4, 8($t0)

    li $t5, 0x000000
    sw $t5, 0($t8)
    sw $t5, 128($t8)
    sw $t5, 256($t8)

    sw $t2, 0($t8)
    sw $t3, 128($t8)
    sw $t4, 256($t8)

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

display_saved_preview:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t8, ADDR_DSPL
    addi $t8, $t8, 1364

    move $t9, $t8
    addi $t9, $t9, -768

    # Draw "S" to indicate that it's the "saved" column
    li $t1, 0x00FFFF     # color (cyan)

    sw $t1, 0($t9)
    sw $t1, 4($t9)
    sw $t1, 8($t9)
    sw $t1, 12($t9)
    sw $t1, 16($t9)
    sw $t1, 128($t9)
    sw $t1, 256($t9)
    sw $t1, 260($t9)
    sw $t1, 264($t9)
    sw $t1, 268($t9)
    sw $t1, 272($t9)
    sw $t1, 400($t9)
    sw $t1, 512($t9)
    sw $t1, 516($t9)
    sw $t1, 520($t9)
    sw $t1, 524($t9)
    sw $t1, 528($t9)

    la $t0, saved_block_exists
    lw $t1, 0($t0)
    beq $t1, 0, sp_clear_area

    la $t0, saved_block
    lw $t2, 0($t0)
    lw $t3, 4($t0)
    lw $t4, 8($t0)

    # shade the colours
    srl $t2, $t2, 1
    andi $t2, $t2, 0x7F7F7F
    srl $t3, $t3, 1
    andi $t3, $t3, 0x7F7F7F
    srl $t4, $t4, 1
    andi $t4, $t4, 0x7F7F7F

    li $t5, 0x000000
    sw $t5, 8($t8)
    sw $t5, 136($t8)
    sw $t5, 264($t8)

    sw $t2, 8($t8)
    sw $t3, 136($t8)
    sw $t4, 264($t8)

    j sp_done

sp_clear_area:
    li $t5, 0x000000
    sw $t5, 8($t8)
    sw $t5, 136($t8)
    sw $t5, 264($t8)

sp_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

clear_previous_preview:
    addi $sp, $sp, -8
    sw $ra, 0($sp)

    la $t0, preview_addr
    lw $t1, 0($t0)
    beq $t1, $zero, cp_done

    li $t2, 0x000000
    sw $t2, 0($t1)
    addi $t1, $t1, 128
    sw $t2, 0($t1)
    addi $t1, $t1, 128
    sw $t2, 0($t1)

    li $t1, 0
    sw $t1, 0($t0)

cp_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra

compute_and_draw_preview:
    addi $sp, $sp, -12
    sw $ra, 0($sp)
    
    jal clear_previous_preview
    # If the next immediate fall would collide, don't show preview.
    jal check_collision
    beq $v0, 1, preview_skip_draw

    move $t2, $s2

preview_drop_loop:
    addi $t3, $t2, 384
    lw $t4, 0($t3)
    li $t5, 0x000000
    beq $t4, $t5, preview_move_down  # if the block below is black, can move down
    j preview_draw_done

preview_move_down:
    addi $t2, $t2, 128
    j preview_drop_loop

preview_draw_done:
    # shade the if-dropped preview so it looks cool and not confusing
    move $t6, $s3
    srl $t6, $t6, 1
    andi $t6, $t6, 0x7F7F7F

    move $t7, $s4
    srl $t7, $t7, 1
    andi $t7, $t7, 0x7F7F7F

    move $t8, $s5
    srl $t8, $t8, 1
    andi $t8, $t8, 0x7F7F7F

    sw $t6, 0($t2)
    sw $t7, 128($t2)
    sw $t8, 256($t2)

    la $t9, preview_addr
    sw $t2, 0($t9)

    j preview_done

preview_skip_draw:
    jal clear_previous_preview

preview_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 12
    jr $ra

toggle_pause:
    la $t0, game_paused
    lw $t1, 0($t0)
    
    beq $t1, 1, unpause_game
    
    li $t1, 1
    sw $t1, 0($t0)
    
    # Record the time we paused
    li $v0, 30
    syscall
    la $t0, pause_time_elapsed
    sw $a0, 0($t0)
    
    jal display_paused
    
    j pause_loop

unpause_game:
    jal clear_paused
    
    # Redraw boundary to fix any overlap
    lw $t0, ADDR_DSPL
    addi $t0, $t0, 552
    la $t1, colors
    jal boundary_generation
    
    li $v0, 30
    syscall
    move $t2, $a0
    
    # Calculate how long we were paused
    la $t0, pause_time_elapsed
    lw $t1, 0($t0)
    sub $t3, $t2, $t1  # Time paused = current - pause_start
    
    # Adjust the last fall time by adding the paused duration
    add $s7, $s7, $t3
    
    la $t0, game_paused
    li $t1, 0
    sw $t1, 0($t0)
    
    j update_screen

pause_loop:
    lw $t7, ADDR_KBRD
    lw $t9, 0($t7)
    beq $t9, 1, check_unpause_key
    
    li $v0, 32
    li $a0, 50
    syscall
    j pause_loop

check_unpause_key:
    lw $t2, 4($t7)
    beq $t2, 0x70, toggle_pause  # 'p' to unpause
    beq $t2, 0x71, exit_game     # 'q' to quit
    j pause_loop

display_paused:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 3080 
    
    li $t9, 0xFFFF00  # Yellow
  
    # These letters are for the "PAUSED" that shows up
    # P
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    
    # A
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # U
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # S
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # E
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # D
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

clear_paused:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    lw $t8, ADDR_DSPL
    addi $t8, $t8, 3080
    
    li $t9, 0x000000  # Black to clear
    
    # Clear P
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    
    # Clear A
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 520($t8)
    
    # Clear U
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # Clear S
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # Clear E
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 8($t8)
    sw $t9, 128($t8)
    sw $t9, 256($t8)
    sw $t9, 260($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    sw $t9, 520($t8)
    
    # Clear D
    addi $t8, $t8, 16
    sw $t9, 0($t8)
    sw $t9, 4($t8)
    sw $t9, 128($t8)
    sw $t9, 136($t8)
    sw $t9, 256($t8)
    sw $t9, 264($t8)
    sw $t9, 384($t8)
    sw $t9, 392($t8)
    sw $t9, 512($t8)
    sw $t9, 516($t8)
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

early_return:
    j update_screen
    
exit_game:
    li $v0, 10
    syscall
