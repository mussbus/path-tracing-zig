const std = @import("std");
const print = std.debug.print;

const path_tracing_zig = @import("path_tracing_zig");

const win = @cImport({
    @cInclude("windows.h");
});

export fn WndProc(
    hwnd: win.HWND,
    msg: win.UINT,
    wParam: win.WPARAM,
    lParam: win.LPARAM,
) callconv(.c) win.LRESULT {
    switch (msg) {
        win.WM_PAINT => {
            print("repaint\n", .{});
            var ps: win.PAINTSTRUCT = undefined;
            const hdc = win.BeginPaint(hwnd, &ps);
            const rect = win.RECT{ .left = 50, .top = 50, .right = 250, .bottom = 150 };
            const brush = win.CreateSolidBrush(win.RGB(255, 0, 0));
            _ = win.SelectObject(hdc ,brush);
            _ = win.Rectangle(hdc, rect.left, rect.top, rect.right, rect.bottom);
            _ = win.EndPaint(hwnd, &ps);
            _ = win.DeleteObject(brush);
            return 0;
        },
        win.WM_CLOSE => {
            print("closing\n", .{});
            _ = win.DestroyWindow(hwnd);
            return 0;
        },
        win.WM_DESTROY => {
            print("destroying\n", .{});
            win.PostQuitMessage(0);
            return 0;
        },
        else => {},
    }

    return win.DefWindowProcW(hwnd, msg, wParam, lParam);
}

pub fn main() !void {
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
        1280, // width
        720, // height
        null, // hWndParent
        null, // hMenu
        hInstance, // hInstance
        null // lpParam
    );

    // assert(wc.lpszClassName == hwmd)

    _ = win.ShowWindow(hwnd, win.SW_SHOW);
    _ = win.UpdateWindow(hwnd);

    var msg: win.MSG = undefined;

    while (win.GetMessageW(&msg, null, 0, 0) > 0) {
        _ = win.TranslateMessage(&msg);
        _ = win.DispatchMessageW(&msg);
    }
}

// test "simple test" {
//     const gpa = std.testing.allocator;
//     var list: std.ArrayList(i32) = .empty;
//     defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
//     try list.append(gpa, 42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }

// test "fuzz example" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }
