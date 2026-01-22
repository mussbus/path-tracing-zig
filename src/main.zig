const path_tracing_zig = @import("path_tracing_zig");
const std = @import("std");

pub const tracy_impl = @import("tracy_impl");
pub const tracy = @import("tracy");
const Zone = tracy.Zone;

const print = std.debug.print;
const func = @import("helpers/func.zig");

const a_state = @import("screen/app_state.zig");
const AppState = a_state.AppState;

const intersect = @import("math/intersect.zig");
const Sphere = intersect.Sphere;
const Plane = intersect.Plane;

const ray = @import("math/ray.zig");
const Camera = ray.Camera;

const screen = @import("screen/screen.zig");
const Material = screen.Material;
const ColorRGBf = screen.ColorRGBf;

const vec = @import("math/vec.zig");
const Vec3 = vec.Vec3;
const UnitVec3 = vec.UnitVec3;

pub const tracy_options: tracy.Options = .{
    .on_demand = false,
    .no_broadcast = false,
    .only_localhost = false,
    .only_ipv4 = false,
    .delayed_init = false,
    .manual_lifetime = false,
    .verbose = false,
    .data_port = null,
    .broadcast_port = null,
    .default_callstack_depth = 0,
};

const win = @cImport({
    @cInclude("windows.h");
});

export fn WndProc(
    hwnd: win.HWND,
    msg: win.UINT,
    wParam: win.WPARAM,
    lParam: win.LPARAM,
) callconv(.c) win.LRESULT {
    if (msg == win.WM_NCCREATE) {
        print("WM_NCCREATE\n", .{});
        const cs = @as(
            *win.CREATESTRUCTW,
            @ptrFromInt(@as(usize, @intCast(lParam))),
        );

        const state = @as(
            *AppState,
            @ptrCast(@alignCast(cs.lpCreateParams.?)),
        );

        _ = win.SetWindowLongPtrW(
            hwnd,
            win.GWLP_USERDATA,
            @as(i64, @intCast(@intFromPtr(state))),
        );

        return 1;
    }

    const raw = win.GetWindowLongPtrW(hwnd, win.GWLP_USERDATA);
    if (raw == 0) return win.DefWindowProcW(hwnd, msg, wParam, lParam);

    const state_ptr = @as(*AppState, @ptrFromInt(@as(usize, @intCast(raw))));
    switch (msg) {
        win.WM_PAINT => {
            var ps: win.PAINTSTRUCT = undefined;
            const hdc = win.BeginPaint(hwnd, &ps);

            var bmi: win.BITMAPINFO = std.mem.zeroes(win.BITMAPINFO);
            bmi.bmiHeader.biSize = @sizeOf(win.BITMAPINFOHEADER);
            bmi.bmiHeader.biWidth = state_ptr.width;
            bmi.bmiHeader.biHeight = -state_ptr.height;
            bmi.bmiHeader.biPlanes = 1;
            bmi.bmiHeader.biBitCount = 32;
            bmi.bmiHeader.biCompression = win.BI_RGB;

            _ = win.StretchDIBits(
                hdc,
                0,
                0,
                state_ptr.width,
                state_ptr.height,
                0,
                0,
                state_ptr.width,
                state_ptr.height,
                state_ptr.framebuffer.ptr,
                &bmi,
                win.DIB_RGB_COLORS,
                win.SRCCOPY,
            );

            _ = win.EndPaint(hwnd, &ps);

            return 0;
        },
        win.WM_SIZE => {
            const new_width: i32 = @intCast(lParam & 0xFFFF);
            const new_height: i32 = @intCast((lParam >> 16) & 0xFFFF);

            if (new_width > 0 and new_height > 0) {
                state_ptr.width = new_width;
                state_ptr.height = new_height;

                const allocator = std.heap.page_allocator;
                allocator.free(state_ptr.framebuffer);

                state_ptr.framebuffer = allocator.alloc(u32, @intCast(state_ptr.width * state_ptr.height)) catch unreachable;
                @memset(state_ptr.framebuffer, 0);
            }
            _ = win.InvalidateRect(hwnd, null, win.FALSE);
            return 0;
        },
        win.WM_CLOSE => {
            _ = win.DestroyWindow(hwnd);
            return 0;
        },
        win.WM_DESTROY => {
            win.PostQuitMessage(0);
            return 0;
        },
        else => {},
    }

    return win.DefWindowProcW(hwnd, msg, wParam, lParam);
}

fn renderFrame(app_state: *AppState) void {
    for (app_state.framebuffer, 0..) |*pixel, i| {
        const width = @as(usize, @intCast(app_state.width));
        const x = @as(u32, @intCast(@mod(i, width)));
        const y = @as(u32, @intCast(i / width));

        const r: u32 = (x + @as(u32, @intCast(std.time.milliTimestamp() & 0xFF))) & 0xFF;
        const g = y & 0xFF;
        const b = 0x40;

        pixel.* = (r << 16) | (g << 8) | b;
    }

    for (app_state.framebuffer, 0..) |*pixel, i| {
        const width = @as(usize, @intCast(app_state.width));
        const x = @as(u32, @intCast(@mod(i, width)));
        const y = @as(u32, @intCast(i / width));

        const r: u32 = (x + @as(u32, @intCast(std.time.milliTimestamp() & 0xFF))) & 0xFF;
        const g = y & 0xFF;
        const b = 0x40;

        pixel.* = (r << 16) | (g << 8) | b;
    }
}

// const Command = enum {
//     quit,
//     help,
//     unknown,
// };

fn parseCommand(line: []const u8) u8 {
    if (std.mem.eql(u8, line, "0")) return '0';
    if (std.mem.eql(u8, line, "1")) return '1';
    if (std.mem.eql(u8, line, "2")) return '2';
    if (std.mem.eql(u8, line, "3")) return '3';
    if (std.mem.eql(u8, line, "4")) return '4';
    if (std.mem.eql(u8, line, "5")) return '5';
    if (std.mem.eql(u8, line, "6")) return '6';
    return 'Z';
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // const initial_width: i32 = 3840;
    // const initial_height: i32 = 2160;
    const initial_width: i32 = 7680;
    const initial_height: i32 = 4320;
    const initial_framebuffer: []u32 = try allocator.alloc(u32, initial_width * initial_height);

    var app_state = AppState{
        .width = initial_width,
        .height = initial_height,
        .framebuffer = initial_framebuffer,
    };

    if (0 == 1) {
        // const hInstance = win.GetModuleHandleW(null);
        // const class_name = std.unicode.utf8ToUtf16LeStringLiteral("MyWindowClass");
        // const window_title = std.unicode.utf8ToUtf16LeStringLiteral("Zig Win32 Window");

        // var wc: win.WNDCLASSEXW = std.mem.zeroes(win.WNDCLASSEXW);
        // wc.cbSize = @sizeOf(win.WNDCLASSEXW);
        // wc.lpfnWndProc = WndProc;
        // wc.hInstance = hInstance;
        // wc.lpszClassName = class_name;
        // _ = win.RegisterClassExW(&wc);

        // const hwnd = win.CreateWindowExW(0, // dwExStyle
        //     class_name, // lpClassName
        //     window_title, // lpWindowName
        //     win.WS_OVERLAPPEDWINDOW, // dwStyle
        //     win.CW_USEDEFAULT, // x
        //     win.CW_USEDEFAULT, // y
        //     app_state.width, // width
        //     app_state.height, // height
        //     null, // hWndParent
        //     null, // hMenu
        //     hInstance, // hInstance
        //     &app_state // lpParam
        // );

        // _ = win.ShowWindow(hwnd, win.SW_SHOW);
        // _ = win.UpdateWindow(hwnd);

        // var msg: win.MSG = undefined;

        // while (true) {
        //     while (win.PeekMessageW(&msg, null, 0, 0, win.PM_REMOVE) != 0) {
        //         if (msg.message == win.WM_QUIT) {
        //             return;
        //         }
        //         _ = win.TranslateMessage(&msg);
        //         _ = win.DispatchMessageW(&msg);
        //     }
        //     renderFrame(&app_state);
        //     _ = win.InvalidateRect(hwnd, null, win.FALSE);
        // }
        //
    }

    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout: *std.Io.Writer = &stdout_writer.interface;
    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin: *std.Io.Reader = &stdin_reader.interface;
    var running: bool = true;

    const output =
        \\Options:
        \\0. Quit
        \\1. Create PPM
        \\2. Initial Render
        \\3. Lambertian Shading
        \\4. Shadow
        \\5. Ray Tracer
        \\6. Multithreaded
        \\Enter Your Choice:
    ;

    const scene = intersect.scene;
    const camera = Camera.init(Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 }, Vec3{ .x = 0.0, .y = 0.0, .z = -1.0 }, UnitVec3.normalize(Vec3{ .x = 0.0, .y = 1.0, .z = 0.0 }), 90.0, app_state.width, app_state.height, 1.0);

    while (running) {
        try stdout.writeAll(output);
        try stdout.flush();
        const bare_line = try stdin.takeDelimiter('\n') orelse unreachable;
        const line = std.mem.trim(u8, bare_line, "\r");
        switch (parseCommand(line)) {
            '0' => {
                running = false;
            },
            '1' => {
                try func.create_ppm(&app_state);
            },
            '2' => {
                try func.show_scene(&scene, camera, true, &app_state);
            },
            '3' => {
                try func.lambertian_shading(&scene, camera, &app_state);
            },
            '4' => {
                try func.shadows(&scene, camera, &app_state);
            },
            '5' => {
                var timer = try std.time.Timer.start();
                try func.depth_tracing(&scene, camera, &app_state);
                const elapsed_ns = timer.read();
                // tracy.frameMark();
                std.debug.print("Render time: {d} ms\n", .{elapsed_ns / 1_000_000});
            },
            '6' => {
                var timer = try std.time.Timer.start();
                try func.multithreaded(&scene, camera, &app_state);
                const elapsed_ns = timer.read();
                // tracy.frameMark();
                std.debug.print("Render time: {d} ms\n", .{elapsed_ns / 1_000_000});
            },
            else => {
                try stdout.writeAll("bitchin'\n");
                try stdout.flush();
                running = true;
            },
        }
    }
    return;
}
