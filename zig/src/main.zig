// raylib-zig (c) Nikolas Wipper 2023

const std = @import("std");
const time = @cImport(@cInclude("time.h"));
const cstd = @cImport(@cInclude("stdlib.h"));

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
var sp: u8 = undefined;

// Keypad keys.
var key: [16]bool = undefined;

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
    key = [_]bool{false} ** 16;

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
        0x0000 => {
            switch (opcode & 0x0FFF) {
                0x0E0 => {
                    // Form: 00E0 - CLS.
                    // Clear the screen.
                    screen = [_]bool{false} ** (64 * 32);
                    PC += 2;
                },
                0x0EE => {
                    // Form: 00EE - RET.
                    // Return from subroutine.
                    // Set program counter to the value popped from the stack.
                    PC = stack[sp];
                    sp -= 1;
                },
                _ => {
                    // Form: 0nnn - SYS addr
                    // This instruction only used on old computers on which CHIP8 was implemented,
                    // it is ignored by modern interpreters.
                    PC += 2;
                },
            }
        },
        0x1000 => {
            // Form: 1nnn - JP addr.
            // Jump to the location nnn.
            const nnn = opcode & 0x0FFF;

            PC = nnn;
        },
        0x2000 => {
            // Form: 2nnn - CALL nnn.
            // Call subroutine at nnn, save current PC onto the stack.
            const nnn = opcode & 0x0FFF;

            sp += 1;
            stack[sp] = PC;
            PC = nnn;
        },
        0x3000 => {
            // Form: 3xkk - SE Vx, byte.
            // Skip the next instruction if Vx = kk.
            const kk: u8 = @intCast(opcode & 0x00FF);
            const vx = V[(opcode & 0x0F00) >> 8];

            if (kk == vx) {
                PC += 2;
            }
            PC += 2;
        },
        0x4000 => {
            // Form: 4xkk - SNE, Vx, byte.
            // Skip the next instruction if Vx != kk.
            const kk: u8 = @intCast(opcode & 0x00FF);
            const vx = V[(opcode & 0x0F00) >> 8];

            if (kk != vx) {
                PC += 2;
            }
            PC += 2;
        },
        0x5000 => {
            // Form: 5xy0 - SE Vx, Vy.
            // Skip next instruction if Vx == Vy.
            const vx = V[(opcode & 0x0F00) >> 8];
            const vy = V[(opcode & 0x00F0) >> 4];

            if (vx == vy) {
                PC += 2;
            }
            PC += 2;
        },
        0x6000 => {
            // Form: 6xkk - LD Vx, byte.
            // Set Vx = kk.
            const vx = (opcode & 0x0F00) >> 8;
            const byte: u8 = @intCast(opcode & 0x00FF);

            V[vx] = byte;
            PC += 2;
        },
        0x7000 => {
            // Form: 7xkk - ADD Vx, byte.
            // Set Vx = Vx + kk.
            const vx = (opcode & 0x0F00) >> 8;
            const byte: u8 = @intCast(opcode & 0x00FF);

            V[vx] += byte;
            PC += 2;
        },
        0x8000 => {
            switch (opcode & 0x000F) {
                0x0 => {
                    // Form: 8xy0 - LD Vx, Vy.
                    // Set Vx = Vy.
                    const vx = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;

                    V[vx] = V[vy];
                    PC += 2;
                },
                0x1 => {
                    // Form: 8xy1 - OR Vx, Vy.
                    // Set Vx = Vx | Vy.
                    const v = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;

                    V[v] |= V[vy];
                    PC += 2;
                },
                0x2 => {
                    // Form: 8xy2 - AND Vx, Vy.
                    // Set Vx = Vx & Vy.
                    const vx = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;

                    V[vx] &= V[vy];
                    PC += 2;
                },
                0x3 => {
                    // Form: 8xy3 - XOR Vx, Vy.
                    // Set Vx = Vx ^ Vy.
                    const vx = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;

                    V[vx] ^= V[vy];
                    PC += 2;
                },
                0x4 => {
                    // Form: 8xy4 - ADD Vx, Vy.
                    // Set Vx = Vx + Vy.
                    const vx = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;
                    const result: u16 = @intCast(V[vx] + V[vy]);

                    V[0xF] = @intCast(@intFromBool(result > 255));
                    V[vx] = result & 0x00FF;
                    PC += 2;
                },
                0x5 => {
                    // Form: 8xy5 - SUB Vx, Vy.
                    // Set Vx = Vx - Vy, VF = not borrow.
                    const vx = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;

                    // If Vx > Vy, VF = 1.
                    V[0xF] = @intCast(@intFromBool(V[vx] > V[vy]));
                    V[vx] -= V[vy];
                    PC += 2;
                },
                0x6 => {
                    // Form: 8xy6 - SHR Vx, {, Vy}
                    // Set Vx = Vx SHR 1.
                    // If the least significant bit of Vx is 1, VF = 1.
                    const vx = (opcode & 0x0F00);
                    const leastsigbit = V[vx] & 0x01;

                    V[0xF] = leastsigbit;
                    V[vx] >>= 1;
                    PC += 2;
                },
                0x7 => {
                    // Form: 8xy7 - SUBN Vx, Vy.
                    // Set Vx = Vy - Vx.
                    // Set VF = not borrow.
                    // If Vy > Vx, then VF is set to 1.
                    const vx = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;

                    // If Vy > Vx, VF = 1.
                    V[0xF] = @intCast(@intFromBool(V[vy] > V[vx]));
                    V[vx] = V[vy] - V[vx];
                    PC += 2;
                },
                0xE => {
                    // Form: 8xyE - SHLVx {, Vy}
                    // Set Vx = Vx SHL 1.
                    // If the most significant bit of Vx is 1, VF is set to 1.
                    const vx = (opcode & 0x0F00) >> 8;
                    const sigbit = (V[vx] & 0x80) >> 7;

                    V[0xF] = sigbit;
                    V[vx] <<= 1;
                    PC += 2;
                },
                _ => {
                    std.debug.print("Unknown opcode {x}", .{opcode});
                    PC += 2;
                },
            }
        },
        0x9000 => {
            // Form: 9xy0 - SNE Vx, Vy.
            // Skip the next instruction if Vx != Vy.
            const vx = V[(opcode & 0x0F00) >> 8];
            const vy = V[(opcode & 0x00F0) >> 4];

            if (vx != vy) {
                PC += 2;
            }
            PC += 2;
        },
        0xA000 => {
            // Form: Annn.
            // Set the address to nnn.
            I = opcode & 0x0FFF;
            PC += 2;
        },
        0xB000 => {
            // Form: Bnnn.
            // Set the program counter to nnn + V0.
            PC = (opcode & 0x0FFF) + V[0x0];
        },
        0xC000 => {
            // Form: Cxkk.
            // Generate a random number and perform AND with the value of kk.
            // Results are then stored in Vx.
            const rbyte: u8 = @intCast(@rem(cstd.rand(), 256));
            const result = rbyte & (opcode & 0x00FF);
            const dest = (opcode & 0x0F00) >> 8;

            V[dest] = result;
            PC += 2;
        },
        0xD000 => {
            // Form: Dxyn.
            // Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.

            // Read n bytes from memory, starting from address in I.

            // Display bytes at (Vx, Vy).

            // Sprites are XORed onto the existing screen.
            // If any pixels were erased (1 -> 0), VF is set to 1, otherwise 0.
            // If the sprite is positioned in such a way that part of it is outside the screen space, it must wrap around to the
            // opposite side of the screen.
        },
        0xE000 => {},
        0xF000 => {},
        _ => {
            std.debug.print("Unknown opcode {x}", .{opcode});
            PC += 2;
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
    cstd.srand(@intCast(time.time(0)));

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
