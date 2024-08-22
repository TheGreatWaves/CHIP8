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

const f = @embedFile("4-flags.ch8");

const fontset = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

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

    // Initialize fontset.
    for (0..80) |i| {
        memory[0x50 + i] = fontset[i];
    }
}

pub fn fetch() void {
    opcode = (@as(u16, @intCast(memory[PC])) << 8) | memory[PC + 1];
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
                    sp -= 1;
                    PC = stack[sp] + 2;
                },
                else => {
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

            stack[sp] = PC;
            sp += 1;
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

            V[vx] = V[vx] +% byte;
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
                    const result: u16 = @as(u16, V[vx]) + @as(u16, V[vy]);
                    V[vx] = V[vx] +% V[vy];
                    V[0xF] = @intCast(@intFromBool(V[vx] < result));
                    PC += 2;
                },
                0x5 => {
                    // Form: 8xy5 - SUB Vx, Vy.
                    // Set Vx = Vx - Vy, VF = not borrow.
                    const vx = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;

                    // If Vx > Vy, VF = 1.
                    const toggle: u8 = if (V[vx] >= V[vy]) 1 else 0;

                    V[vx] -%= V[vy];
                    V[0xF] = toggle;

                    PC += 2;
                },
                0x6 => {
                    // Form: 8xy6 - SHR Vx, {, Vy}
                    // Set Vx = Vx SHR 1.
                    // If the least significant bit of Vx is 1, VF = 1.
                    const vx = (opcode & 0x0F00) >> 8;
                    const leastsigbit = V[vx] & 0x1;

                    V[vx] >>= 1;
                    V[0xF] = leastsigbit;
                    PC += 2;
                },
                0x7 => {
                    // Form: 8xy7 - SUBN Vx, Vy.
                    // Set Vx = Vy - Vx.
                    // Set VF = not borrow.
                    // If Vy > Vx, then VF is set to 1.
                    const vx = (opcode & 0x0F00) >> 8;
                    const vy = (opcode & 0x00F0) >> 4;

                    // If Vy >= Vx,  VF = 1 (no borrow).
                    const toggle: u8 = if (V[vy] >= V[vx]) 1 else 0;
                    V[vx] = V[vy] -% V[vx];

                    V[0xF] = toggle;
                    PC += 2;
                },
                0xE => {
                    // Form: 8xyE - SHLVx {, Vy}
                    // Set Vx = Vx SHL 1.
                    // If the most significant bit of Vx is 1, VF is set to 1.
                    const vx = (opcode & 0x0F00) >> 8;
                    const sigbit = V[vx] >> 7;

                    V[vx] <<= 1;
                    V[0xF] = sigbit;
                    PC += 2;
                },
                else => {
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
            const result: u8 = @intCast(rbyte & (opcode & 0x00FF));
            const dest = (opcode & 0x0F00) >> 8;

            V[dest] = result;
            PC += 2;
        },
        0xD000 => {
            // Form: Dxyn - DRW Vx, Vy, nibble.
            // Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.

            // Read n bytes from memory, starting from address in I.

            // Display bytes at (Vx, Vy).

            // Sprites are XORed onto the existing screen.
            // If any pixels were erased (1 -> 0), VF is set to 1, otherwise 0.

            // TODO: If the sprite is positioned in such a way that part of it is
            // outside the screen space, it must wrap around to the opposite side of the screen.
            const x = V[(opcode & 0x0F00) >> 8];
            const y = V[(opcode & 0x00F0) >> 4];
            const n = opcode & 0x000F;

            // Reset flag state.
            V[0xF] = 0;

            for (0..n) |yline| {
                const bitmap = memory[I + yline];
                for (0..8) |xline| {
                    if ((bitmap & (@as(u8, 0x80) >> @intCast(xline))) != 0) {
                        const coord = (x + xline) + ((y + yline) * 64);
                        // Check if the pixel is already set.
                        if (screen[coord]) {
                            V[0xF] = 1;
                        }
                        screen[coord] = screen[coord] != true;
                    }
                }
            }

            PC += 2;
        },
        0xE000 => {
            switch (opcode & 0x00FF) {
                0x9E => {
                    // Form: Ex9E - SKP Vx.
                    // Skip the next instruction if key with the value of Vx is being pressed.
                    const x = V[(opcode & 0x0F00) >> 8];

                    if (key[x]) {
                        PC += 2;
                    }
                    PC += 2;
                },
                0xA1 => {
                    // Form: ExA1 - SKNP Vx.
                    // Skip the next instruction if key with the value of Vx is NOT being pressed.
                    const x = V[(opcode & 0x0F00) >> 8];

                    if (!key[x]) {
                        PC += 2;
                    }
                    PC += 2;
                },
                else => {
                    std.debug.print("Unknown opcode {x}", .{opcode});
                    PC += 2;
                },
            }
            // Form: Ex9E - SKP Vx
        },
        0xF000 => {
            switch (opcode & 0x00FF) {
                0x07 => {
                    // Form: Fx07 - LD Vx, DT.
                    // Set Vx = value of delayer timer.
                    const vx = (opcode & 0x0F00) >> 8;

                    V[vx] = delay_timer;
                    PC += 2;
                },
                0x0A => {
                    // Form: Fx0A - LD Vx, K.
                    // Wait for a key press, store the value of the key in Vx.
                    var found: i32 = -1;
                    for (key, 0..) |k, key_code| {
                        if (k) {
                            const vx = (opcode & 0x0F00) >> 8;
                            V[vx] = @intCast(key_code);
                            found = @intCast(key_code);
                            break;
                        }
                    }

                    if (found != -1) {
                        while (key[@intCast(found)]) {}
                        PC += 2;
                    }
                },
                0x15 => {
                    // Form: Fx15 - LD DT, Vx.
                    // Set delay timer = Vx.
                    const vx = (opcode & 0x0F00) >> 8;

                    delay_timer = V[vx];
                    PC += 2;
                },
                0x18 => {
                    // Form: Fx18 - LD ST, Vx.
                    // Set sound timer = Vx.
                    const vx = (opcode & 0x0F00) >> 8;

                    sound_timer = V[vx];
                    PC += 2;
                },
                0x1E => {
                    // Form: Fx1E - ADD I, Vx.
                    // Set I = I + Vx.
                    const vx = (opcode & 0x0F00) >> 8;

                    I += V[vx];
                    PC += 2;
                },
                0x29 => {
                    // Form: Fx29 - LD F, Vx.
                    // Set I = location of sprite for digit Vx.
                    const vx = (opcode & 0x0F00) >> 8;

                    I = 0x0050 + (5 * @as(u16, @intCast(V[vx])));
                    PC += 2;
                },
                0x33 => {
                    // Form: Fx33 - LD B, Vx.
                    const vx = (opcode & 0x0F00) >> 8;
                    const x = V[vx];

                    memory[I + 2] = x % 10;
                    memory[I + 1] = (x / 10) % 10;
                    memory[I] = (x / 100) % 10;

                    PC += 2;
                },
                0x55 => {
                    // Form: Fx55 - LD [I], Vx.
                    // Stores registers V0 through Vx in memory, starting at location I.
                    const vx = (opcode & 0x0F00) >> 8;

                    for (0..(vx + 1)) |reg| {
                        memory[I + reg] = V[reg];
                    }

                    PC += 2;
                },
                0x65 => {
                    // Form: Fx65 - LD Vx, [I].
                    // Read registers V0 through Vx from memory starting at location I.
                    const vx = (opcode & 0x0F00) >> 8;

                    for (0..(vx + 1)) |reg| {
                        V[reg] = memory[I + reg];
                    }

                    PC += 2;
                },
                else => {
                    std.debug.print("Unknown opcode {x}", .{opcode});
                    PC += 2;
                },
            }
        },
        else => {
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

pub fn draw_screen() void {
    for (0..32) |y| {
        for (0..64) |x| {
            rl.drawRectangle(@intCast(x * 10), @intCast(y * 10), 10, 10, if (screen[x + (y * 64)]) rl.Color.black else rl.Color.white);
        }
    }
}

const rl = @import("raylib");

pub fn handle_input() void {
    // First row
    key[0x1] = (rl.isKeyDown(rl.KeyboardKey.key_one));
    key[0x2] = (rl.isKeyDown(rl.KeyboardKey.key_two));
    key[0x3] = (rl.isKeyDown(rl.KeyboardKey.key_three));
    key[0xC] = (rl.isKeyDown(rl.KeyboardKey.key_four));

    // Second row
    key[0x4] = (rl.isKeyDown(rl.KeyboardKey.key_q));
    key[0x5] = (rl.isKeyDown(rl.KeyboardKey.key_w));
    key[0x6] = (rl.isKeyDown(rl.KeyboardKey.key_e));
    key[0xD] = (rl.isKeyDown(rl.KeyboardKey.key_r));

    // Third row
    key[0x7] = (rl.isKeyDown(rl.KeyboardKey.key_a));
    key[0x8] = (rl.isKeyDown(rl.KeyboardKey.key_s));
    key[0x9] = (rl.isKeyDown(rl.KeyboardKey.key_d));
    key[0xE] = (rl.isKeyDown(rl.KeyboardKey.key_f));

    // Fourth row
    key[0xA] = (rl.isKeyDown(rl.KeyboardKey.key_z));
    key[0x0] = (rl.isKeyDown(rl.KeyboardKey.key_x));
    key[0xB] = (rl.isKeyDown(rl.KeyboardKey.key_c));
    key[0xF] = (rl.isKeyDown(rl.KeyboardKey.key_v));
}

pub fn run_chip8() void {
    while (true) {
        cycle();
    }

    // Note: Uncomment below for fixed timestep.

    // var time_since_last_update: f64 = 0.0;
    // var time0: f64 = 0;
    // while (true) {
    //     while (time_since_last_update > timestep) {
    //         time_since_last_update -= timestep;
    //         cycle();
    //     }
    //     const time1: f64 = rl.getTime();
    //     time_since_last_update += (time1 - time0);
    //     time0 = time1;
    // }
}

pub fn main() anyerror!void {
    cstd.srand(@intCast(time.time(0)));

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 640;
    const screenHeight = 320;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    initialize_chip_8();
    //--------------------------------------------------------------------------------------

    var i: u32 = 0;
    while (i < f.len) : (i += 2) {
        memory[0x200 + i] = f[i];
        memory[0x200 + i + 1] = f[i + 1];
    }

    _ = try std.Thread.spawn(.{}, run_chip8, .{});

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------
        handle_input();

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        draw_screen();

        rl.clearBackground(rl.Color.white);
        //----------------------------------------------------------------------------------
    }
}
