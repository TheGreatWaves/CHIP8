// raylib-zig (c) Nikolas Wipper 2023

// 35 opcodes, all two bytes long.
const Opcode = enum(u16) {};

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

const rl = @import("raylib");

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
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
