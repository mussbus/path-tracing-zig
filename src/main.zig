const std = @import("std");
const print = std.debug.print;

const path_tracing_zig = @import("path_tracing_zig");

const win = @cImport({
    @cInclude("windows.h");
});

const AppState = struct {
    width: i32,
    height: i32,
    framebuffer: []u32,
};

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
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const initial_width: i32 = 800;
    const initial_height: i32 = 600;
    const initial_framebuffer: []u32 = try allocator.alloc(u32, initial_width * initial_height);

    var app_state = AppState{
        .width = initial_width,
        .height = initial_height,
        .framebuffer = initial_framebuffer,
    };

    const hInstance = win.GetModuleHandleW(null);
    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("MyWindowClass");
    const window_title = std.unicode.utf8ToUtf16LeStringLiteral("Zig Win32 Window");

    var wc: win.WNDCLASSEXW = std.mem.zeroes(win.WNDCLASSEXW);
    wc.cbSize = @sizeOf(win.WNDCLASSEXW);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = class_name;
    _ = win.RegisterClassExW(&wc);

    const hwnd = win.CreateWindowExW(0, // dwExStyle
        class_name, // lpClassName
        window_title, // lpWindowName
        win.WS_OVERLAPPEDWINDOW, // dwStyle
        win.CW_USEDEFAULT, // x
        win.CW_USEDEFAULT, // y
        app_state.width, // width
        app_state.height, // height
        null, // hWndParent
        null, // hMenu
        hInstance, // hInstance
        &app_state // lpParam
    );

    _ = win.ShowWindow(hwnd, win.SW_SHOW);
    _ = win.UpdateWindow(hwnd);

    var msg: win.MSG = undefined;

    while (true) {
        while (win.PeekMessageW(&msg, null, 0, 0, win.PM_REMOVE) != 0) {
            if (msg.message == win.WM_QUIT) {
                return;
            }
            _ = win.TranslateMessage(&msg);
            _ = win.DispatchMessageW(&msg);
        }
        renderFrame(&app_state);
        _ = win.InvalidateRect(hwnd, null, win.FALSE);
    }
    return 0;
}
