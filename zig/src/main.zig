// raylib-zig (c) Nikolas Wipper 2023

const std = @import("std");

// 35 opcodes, all two bytes long.
var opcode: u16 = undefined;

// NOTE: Data can be organized into an array later.

// 4KB memory.
// Memory mapping.
// 0x000-0x1FF Reserved for interpreter.
// 0x200-0xFFF ROM & RAM.
var memory: [4096]u8 = undefined;

// 16 8-bit data registers (V0-VF).
// VF is used as flag for some instructions, should be avoided.
var V: [16]u8 = undefined;

// Address register.
var I: u16 = undefined;

// Program counter.
var PC: u16 = undefined;

// Timers.
var delay_timer: u8 = undefined;
var sound_timer: u8 = undefined;

// Stack for subroutine jumping.
var stack: [16]u16 = undefined;
var sp: u16 = undefined;

// Keypad keys.
var key: [16]u16 = undefined;

// Screen bitmap.
var screen: [64 * 32]bool = undefined;

pub fn initialize_chip_8() void {
    I = 0; // Address.
    opcode = 0; // Current opcode.

    // Programs are expected to be loaded in, starting from 0x200, therefore
    // the initial value of the program counter should be pointing there.
    PC = 0x200;

    // Initialize registers.
    V = [_]u8{0} ** 16;

    // Initialize memory.
    memory = [_]u8{0} ** 4096;

    // Initialize stack.
    stack = [_]u16{0} ** 16;
    sp = 0;

    // Initialize key states.
    key = [_]u16{0} ** 16;

    // Initialize screen bitmap.
    screen = [_]bool{false} ** (64 * 32);

    // Initialize timers.
    delay_timer = 0;
    sound_timer = 0;
}

pub fn fetch() void {
    opcode = (memory[PC] << 8) | memory[PC + 1];
}

pub fn play_sound() void {}

pub fn update_timers() void {
    if (delay_timer > 0) {
        delay_timer -= 1;
    }

    if (sound_timer > 0) {
        if (sound_timer == 1) {
            play_sound();
        }
        sound_timer -= 1;
    }
}

pub fn decode_and_execute() void {
    switch (opcode & 0xF000) {
        _ => {
            std.debug.print("Unknown opcode {x}", .{opcode});
        },
    }
}

pub fn cycle() void {
    fetch();
    decode_and_execute();
    update_timers();
}

const rl = @import("raylib");

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    initialize_chip_8();
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        rl.drawText("Congrats! You created your first window!", 190, 200, 20, rl.Color.light_gray);
        //----------------------------------------------------------------------------------
    }
}
