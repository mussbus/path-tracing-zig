const path_tracing_zig = @import("path_tracing_zig");
const std = @import("std");
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

const scene = .{
    Plane{
        .point = Vec3.init(0.0, 0.0, -10.0),
        .normal = UnitVec3.init(0.0, 1.0, 1.0),
        .material = Material{
            .color = ColorRGBf{ .r = 0.0, .g = 1.0, .b = 0.0 },
            .reflectivity = 0.1,
        },
    },
    Plane{
        .point = Vec3.init(0.0, -2.0, 0.0),
        .normal = UnitVec3.init(0.0, 1.0, 0.0),
        .material = Material{
            .color = ColorRGBf{ .r = 0.0, .g = 0.0, .b = 0.0 },
            .reflectivity = 0.03,
        },
    },
    Plane{
        .point = Vec3.init(10.0, 0.0, 0.0),
        .normal = UnitVec3.init(-1.0, 1.0, 0.0),
        .material = Material{
            .color = ColorRGBf{ .r = 0.0, .g = 0.0, .b = 1.0 },
            .reflectivity = 0.1,
        },
    },
    Plane{
        .point = Vec3.init(-10.0, 0.0, 0.0),
        .normal = UnitVec3.init(1.0, 1.0, 0.0),
        .material = Material{
            .color = ColorRGBf{ .r = 1.0, .g = 0.0, .b = 0.0 },
            .reflectivity = 0.1,
        },
    },
    Sphere{
        .center = Vec3.init(0.0, -2.0, -7.0),
        .radius = 3.0,
        .material = Material{
            .color = ColorRGBf{ .r = 1.0, .g = 1.0, .b = 1.0 },
            .reflectivity = 0.4,
        },
    },
};

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
    return 'Z';
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const initial_width: i32 = 1920;
    const initial_height: i32 = 1080;
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
        \\Enter Your Choice:
    ;

    const camera = Camera.init(Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 }, Vec3{ .x = 0.0, .y = 0.0, .z = -1.0 }, UnitVec3.normalize(Vec3{ .x = 0.0, .y = 1.0, .z = 0.0 }), 90.0, app_state.width, app_state.height, 1.0);

    print("w: {}\n", .{camera.w});
    print("u: {}\n", .{camera.u});
    print("v: {}\n", .{camera.v});
    print("viewport height: {}\n", .{camera.viewport_height});
    print("viewport width: {}\n", .{camera.viewport_width});
    print("image plane center: {}\n", .{camera.image_plane_center});
    print("image plane upper left: {}\n", .{camera.image_plane_upper_left});
    print("h step: {}\n", .{camera.h_step});
    print("v step: {}\n", .{camera.v_step});

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
                try func.show_scene(scene, camera, true, &app_state);
            },
            '3' => {
                try func.lambertian_shading(scene, camera, &app_state);
            },
            '4' => {
                try func.shadows(scene, camera, &app_state);
            },
            '5' => {
                try func.depth_tracing(scene, camera, &app_state);
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
