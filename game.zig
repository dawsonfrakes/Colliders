const DEVELOPER = true;

const core = struct {
    const builtin = @import("builtin");

    pub const build_mode = builtin.mode;
    pub const cpu_arch = builtin.target.cpu.arch;
    pub const cpu_bits = builtin.target.ptrBitWidth();
    pub const cpu_endianness = builtin.target.cpu.arch.endian();
    pub const os_tag = builtin.target.os.tag;

    pub const Type = @TypeOf(@typeInfo(type));
    pub const CallingConvention = @TypeOf(@typeInfo(fn () void).@"fn".calling_convention);

    pub fn zeroes(comptime T: type) T {
        return @as(*align(1) const T, @ptrCast(&[_]u8{0} ** @sizeOf(T))).*;
    }

    pub fn zeroInit(comptime T: type, args: anytype) T {
        var result: T = undefined;
        inline for (@typeInfo(T).@"struct".fields) |field| {
            @field(result, field.name) = if (@hasField(@TypeOf(args), field.name))
                switch (@typeInfo(field.type)) {
                    .@"struct" => zeroInit(field.type, @field(args, field.name)),
                    else => @field(args, field.name),
                }
            else if (field.default_value) |default_value|
                @as(*align(1) const field.type, @ptrCast(default_value)).*
            else
                zeroes(field.type);
        }
        return result;
    }

    pub fn FnsToFnPtrs(comptime T: type) type {
        return comptime blk: {
            var fields: [@typeInfo(T).@"struct".decls.len]Type.StructField = undefined;
            for (&fields, @typeInfo(T).@"struct".decls) |*field, decl| {
                const Decl = @TypeOf(@field(T, decl.name));
                field.* = if (@typeInfo(Decl) == .@"fn")
                    .{
                        .name = decl.name,
                        .type = *const Decl,
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = @alignOf(*const Decl),
                    }
                else
                    .{
                        .name = decl.name,
                        .type = Decl,
                        .default_value = &@field(T, decl.name),
                        .is_comptime = true,
                        .alignment = @alignOf(Decl),
                    };
            }
            break :blk @Type(.{ .@"struct" = .{
                .layout = .auto,
                .fields = &fields,
                .decls = &.{},
                .is_tuple = false,
            } });
        };
    }

    pub fn nativeToLittle(comptime T: type, x: T) T {
        return if (cpu_endianness == .little) x else @byteSwap(x);
    }

    pub fn nativeToBig(comptime T: type, x: T) T {
        return if (cpu_endianness == .big) x else @byteSwap(x);
    }

    pub fn utf8ToUtf16LeStringLiteral(comptime ascii: []const u8) *const [ascii.len:0]u16 {
        return comptime blk: {
            var utf16le: [ascii.len:0]u16 = undefined;
            for (&utf16le, ascii) |*dst, src| dst.* = nativeToLittle(u16, src);
            const result = utf16le;
            break :blk &result;
        };
    }
};

const windows = struct {
    pub const WINAPI = if (core.cpu_arch == .x86) .Stdcall else .C;

    pub const kernel32 = struct {
        pub const HINSTANCE = *opaque {};
        pub const HMODULE = HINSTANCE;
        pub const PROC = *const fn () callconv(WINAPI) isize;

        pub extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(WINAPI) ?HMODULE;
        pub extern "kernel32" fn Sleep(c_ulong) callconv(WINAPI) void;
        pub extern "kernel32" fn ExitProcess(c_uint) callconv(WINAPI) noreturn;
    };

    pub const user32 = struct {
        pub const IDI_WARNING: [*:0]align(1) const u16 = @ptrFromInt(32515);
        pub const IDC_CROSS: [*:0]align(1) const u16 = @ptrFromInt(32515);
        pub const CS_OWNDC = 0x0020;
        pub const WS_MAXIMIZEBOX = 0x00010000;
        pub const WS_MINIMIZEBOX = 0x00020000;
        pub const WS_THICKFRAME = 0x00040000;
        pub const WS_SYSMENU = 0x00080000;
        pub const WS_CAPTION = 0x00C00000;
        pub const WS_VISIBLE = 0x10000000;
        pub const WS_OVERLAPPEDWINDOW = WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
        pub const CW_USEDEFAULT: c_int = @bitCast(@as(c_uint, 0x80000000));
        pub const PM_REMOVE = 0x0001;
        pub const WM_CREATE = 0x0001;
        pub const WM_DESTROY = 0x0002;
        pub const WM_SIZE = 0x0005;
        pub const WM_PAINT = 0x000F;
        pub const WM_QUIT = 0x0012;
        pub const WM_ERASEBKGND = 0x0014;
        pub const WM_ACTIVATEAPP = 0x001C;
        pub const WM_KEYDOWN = 0x0100;
        pub const WM_KEYUP = 0x0101;
        pub const WM_SYSKEYDOWN = 0x0104;
        pub const WM_SYSKEYUP = 0x0105;
        pub const WM_SYSCOMMAND = 0x0112;
        pub const SC_KEYMENU = 0xF100;
        pub const VK_RETURN = 0x0D;
        pub const VK_ESCAPE = 0x1B;
        pub const VK_F4 = 0x73;
        pub const VK_F10 = 0x79;
        pub const VK_F11 = 0x7A;

        pub const HDC = *opaque {};
        pub const HWND = *opaque {};
        pub const HMENU = *opaque {};
        pub const HICON = *opaque {};
        pub const HBRUSH = *opaque {};
        pub const HCURSOR = *opaque {};
        pub const HMONITOR = *opaque {};
        pub const WNDPROC = *const fn (HWND, c_uint, usize, isize) callconv(WINAPI) isize;
        pub const POINT = extern struct {
            x: c_long,
            y: c_long,
        };
        pub const RECT = extern struct {
            left: c_long,
            top: c_long,
            right: c_long,
            bottom: c_long,
        };
        pub const WNDCLASSEXW = extern struct {
            cbSize: c_uint,
            style: c_uint,
            lpfnWndProc: ?WNDPROC,
            cbClsExtra: c_int,
            cbWndExtra: c_int,
            hInstance: ?kernel32.HINSTANCE,
            hIcon: ?HICON,
            hCursor: ?HCURSOR,
            hbrBackground: ?HBRUSH,
            lpszMenuName: ?[*:0]const u16,
            lpszClassName: ?[*:0]const u16,
            hIconSm: ?HICON,
        };
        pub const MSG = extern struct {
            hwnd: ?HWND,
            message: c_uint,
            wParam: usize,
            lParam: isize,
            time: c_ulong,
            pt: POINT,
            lPrivate: c_ulong,
        };

        pub extern "user32" fn SetProcessDPIAware() callconv(WINAPI) c_int;
        pub extern "user32" fn LoadIconW(?kernel32.HINSTANCE, ?[*:0]align(1) const u16) callconv(WINAPI) ?HICON;
        pub extern "user32" fn LoadCursorW(?kernel32.HINSTANCE, ?[*:0]align(1) const u16) callconv(WINAPI) ?HCURSOR;
        pub extern "user32" fn RegisterClassExW(?*const WNDCLASSEXW) callconv(WINAPI) c_uint;
        pub extern "user32" fn CreateWindowExW(c_ulong, ?[*:0]const u16, ?[*:0]const u16, c_ulong, c_int, c_int, c_int, c_int, ?HWND, ?HMENU, ?kernel32.HINSTANCE, ?*anyopaque) callconv(WINAPI) ?HWND;
        pub extern "user32" fn PeekMessageW(?*MSG, ?HWND, c_uint, c_uint, c_uint) callconv(WINAPI) c_int;
        pub extern "user32" fn TranslateMessage(?*const MSG) callconv(WINAPI) c_int;
        pub extern "user32" fn DispatchMessageW(?*const MSG) callconv(WINAPI) isize;
        pub extern "user32" fn GetDC(?HWND) callconv(WINAPI) ?HDC;
        pub extern "user32" fn DefWindowProcW(?HWND, c_uint, usize, isize) callconv(WINAPI) isize;
        pub extern "user32" fn PostQuitMessage(c_int) callconv(WINAPI) void;
        pub extern "user32" fn DestroyWindow(?HWND) callconv(WINAPI) c_int;
        pub extern "user32" fn ValidateRect(?HWND, ?*const RECT) callconv(WINAPI) c_int;
    };

    pub const gdi32 = struct {
        pub const PFD_DOUBLEBUFFER = 0x00000001;
        pub const PFD_DRAW_TO_WINDOW = 0x00000004;
        pub const PFD_SUPPORT_OPENGL = 0x00000020;
        pub const PFD_DEPTH_DONTCARE = 0x20000000;

        pub const PIXELFORMATDESCRIPTOR = extern struct {
            nSize: c_ushort,
            nVersion: c_ushort,
            dwFlags: c_ulong,
            iPixelType: u8,
            cColorBits: u8,
            cRedBits: u8,
            cRedShift: u8,
            cGreenBits: u8,
            cGreenShift: u8,
            cBlueBits: u8,
            cBlueShift: u8,
            cAlphaBits: u8,
            cAlphaShift: u8,
            cAccumBits: u8,
            cAccumRedBits: u8,
            cAccumGreenBits: u8,
            cAccumBlueBits: u8,
            cAccumAlphaBits: u8,
            cDepthBits: u8,
            cStencilBits: u8,
            cAuxBuffers: u8,
            iLayerType: u8,
            bReserved: u8,
            dwLayerMask: c_ulong,
            dwVisibleMask: c_ulong,
            dwDamageMask: c_ulong,
        };

        pub extern "gdi32" fn ChoosePixelFormat(?user32.HDC, ?*const PIXELFORMATDESCRIPTOR) callconv(WINAPI) c_int;
        pub extern "gdi32" fn SetPixelFormat(?user32.HDC, c_int, ?*const PIXELFORMATDESCRIPTOR) callconv(WINAPI) c_int;
        pub extern "gdi32" fn SwapBuffers(?user32.HDC) callconv(WINAPI) c_int;
    };

    pub const opengl32 = struct {
        pub const HGLRC = *opaque {};

        pub extern "opengl32" fn wglCreateContext(?user32.HDC) callconv(WINAPI) ?HGLRC;
        pub extern "opengl32" fn wglDeleteContext(?HGLRC) callconv(WINAPI) c_int;
        pub extern "opengl32" fn wglMakeCurrent(?user32.HDC, ?HGLRC) callconv(WINAPI) c_int;
        pub extern "opengl32" fn wglGetProcAddress(?[*:0]const u8) callconv(WINAPI) ?kernel32.PROC;

        pub usingnamespace opengl.gl10;
        pub usingnamespace opengl.gl11;
    };

    pub const dwmapi = struct {
        pub const DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
        pub const DWMWA_WINDOW_CORNER_PREFERENCE = 33;
        pub const DWMWCP_DONOTROUND = 1;

        pub extern "dwmapi" fn DwmSetWindowAttribute(?user32.HWND, c_long, ?*const anyopaque, c_long) callconv(WINAPI) c_int;
    };

    pub const winmm = struct {
        pub extern "winmm" fn timeBeginPeriod(c_uint) callconv(WINAPI) c_uint;
    };
};

const opengl = struct {
    pub const GLAPI = if (core.os_tag == .windows and core.cpu_arch == .x86) .Stdcall else .C;

    pub const gl10 = struct {
        pub const GL_COLOR_BUFFER_BIT = 0x00004000;

        pub extern fn glEnable(u32) callconv(GLAPI) void;
        pub extern fn glDisable(u32) callconv(GLAPI) void;
        pub extern fn glGetIntegerv(u32, ?[*]c_int) callconv(GLAPI) void;
        pub extern fn glDepthFunc(u32) callconv(GLAPI) void;
        pub extern fn glBlendFunc(u32, u32) callconv(GLAPI) void;
        pub extern fn glViewport(i32, i32, u32, u32) callconv(GLAPI) void;
        pub extern fn glClearColor(f32, f32, f32, f32) callconv(GLAPI) void;
        pub extern fn glClear(u32) callconv(GLAPI) void;
    };

    pub const gl11 = struct {};

    pub const gl30 = struct {
        pub const GL_FRAMEBUFFER_SRGB = 0x8DB9;
    };

    pub const gl45 = struct {
        pub extern fn glClipControl(u32, u32) callconv(GLAPI) void;
    };
};

const RenderAPI = enum { opengl };
const render_api = RenderAPI.opengl;
const renderer = switch (render_api) {
    .opengl => struct {
        var gl: core.FnsToFnPtrs(struct {
            pub usingnamespace opengl.gl10;
            pub usingnamespace opengl.gl11;
            pub usingnamespace opengl.gl30;
            pub usingnamespace opengl.gl45;
        }) = undefined;

        const gl_os = switch (core.os_tag) {
            .windows => struct {
                const w = struct {
                    usingnamespace windows;
                    usingnamespace windows.gdi32;
                    usingnamespace windows.opengl32;
                };

                fn init() void {
                    const pfd = core.zeroInit(w.PIXELFORMATDESCRIPTOR, .{
                        .nSize = @sizeOf(w.PIXELFORMATDESCRIPTOR),
                        .nVersion = 1,
                        .dwFlags = w.PFD_DRAW_TO_WINDOW | w.PFD_SUPPORT_OPENGL | w.PFD_DOUBLEBUFFER | w.PFD_DEPTH_DONTCARE,
                        .cColorBits = 24,
                    });
                    const format = w.ChoosePixelFormat(platform.g_hdc, &pfd);
                    _ = w.SetPixelFormat(platform.g_hdc, format, &pfd);

                    const temp_ctx = w.wglCreateContext(platform.g_hdc);
                    // defer w.wglDeleteContext(temp_ctx);
                    _ = w.wglMakeCurrent(platform.g_hdc, temp_ctx);

                    inline for (@typeInfo(@TypeOf(gl)).@"struct".fields) |field| {
                        if (!field.is_comptime) {
                            @field(gl, field.name) = if (@hasDecl(windows.opengl32, field.name))
                                @field(windows.opengl32, field.name)
                            else
                                @ptrCast(w.wglGetProcAddress(field.name));
                        }
                    }
                }

                fn deinit() void {}

                fn present() void {
                    _ = w.SwapBuffers(platform.g_hdc);
                }
            },
            else => @compileError("Unsupported OS"),
        };

        pub fn init() void {
            gl_os.init();
        }

        pub fn deinit() void {
            gl_os.deinit();
        }

        pub fn resize() void {}

        pub fn present() void {
            gl.glEnable(gl.GL_FRAMEBUFFER_SRGB);
            gl.glClearColor(0.6, 0.2, 0.2, 1.0);
            gl.glClear(gl.GL_COLOR_BUFFER_BIT);

            gl_os.present();
        }
    },
};

const platform = @This();
pub usingnamespace switch (core.os_tag) {
    .windows => struct {
        const w = struct {
            usingnamespace windows;
            usingnamespace windows.kernel32;
            usingnamespace windows.user32;
            usingnamespace windows.dwmapi;
            usingnamespace windows.winmm;
        };

        pub var g_screen_width: u16 = undefined;
        pub var g_screen_height: u16 = undefined;
        pub var g_hinstance: w.HINSTANCE = undefined;
        pub var g_hwnd: w.HWND = undefined;
        pub var g_hdc: w.HDC = undefined;

        fn toggleFullscreen() void {}

        fn updateCursorClip() void {}

        fn clearHeldKeys() void {}

        fn windowProc(hwnd: ?w.HWND, message: c_uint, wParam: usize, lParam: isize) callconv(w.WINAPI) isize {
            switch (message) {
                w.WM_PAINT => _ = w.ValidateRect(hwnd, null),
                w.WM_ERASEBKGND => return 1,
                w.WM_ACTIVATEAPP => {
                    if (wParam != 0) updateCursorClip() else clearHeldKeys();
                },
                w.WM_SIZE => {
                    g_screen_width = @truncate(@as(usize, @bitCast(lParam)));
                    g_screen_height = @truncate(@as(usize, @bitCast(lParam)) >> 16);

                    renderer.resize();
                },
                w.WM_CREATE => {
                    g_hwnd = hwnd.?;
                    g_hdc = w.GetDC(hwnd).?;

                    const dark_mode: c_uint = 1;
                    _ = w.DwmSetWindowAttribute(hwnd, w.DWMWA_USE_IMMERSIVE_DARK_MODE, &dark_mode, @sizeOf(@TypeOf(dark_mode)));
                    const round_mode: c_uint = w.DWMWCP_DONOTROUND;
                    _ = w.DwmSetWindowAttribute(hwnd, w.DWMWA_WINDOW_CORNER_PREFERENCE, &round_mode, @sizeOf(@TypeOf(round_mode)));

                    renderer.init();
                },
                w.WM_DESTROY => {
                    renderer.deinit();

                    w.PostQuitMessage(0);
                },
                else => {
                    if (message == w.WM_SYSCOMMAND and wParam == w.SC_KEYMENU) return 0;
                    return w.DefWindowProcW(hwnd, message, wParam, lParam);
                },
            }
            return 0;
        }

        pub export fn WinMainCRTStartup() callconv(w.WINAPI) noreturn {
            @setAlignStack(16);

            g_hinstance = w.GetModuleHandleW(null).?;

            const sleep_is_granular = w.timeBeginPeriod(1) == 0;

            _ = w.SetProcessDPIAware();
            const wndclass = core.zeroInit(w.WNDCLASSEXW, .{
                .cbSize = @sizeOf(w.WNDCLASSEXW),
                .style = w.CS_OWNDC,
                .lpfnWndProc = windowProc,
                .hInstance = g_hinstance,
                .hIcon = w.LoadIconW(null, w.IDI_WARNING).?,
                .hCursor = w.LoadCursorW(null, w.IDC_CROSS).?,
                .lpszClassName = core.utf8ToUtf16LeStringLiteral("A"),
            });
            _ = w.RegisterClassExW(&wndclass);
            _ = w.CreateWindowExW(
                0,
                wndclass.lpszClassName,
                core.utf8ToUtf16LeStringLiteral("Game"),
                w.WS_OVERLAPPEDWINDOW | w.WS_VISIBLE,
                w.CW_USEDEFAULT,
                w.CW_USEDEFAULT,
                w.CW_USEDEFAULT,
                w.CW_USEDEFAULT,
                null,
                null,
                g_hinstance,
                null,
            ).?;

            game_loop: while (true) {
                var msg: w.MSG = undefined;
                while (w.PeekMessageW(&msg, null, 0, 0, w.PM_REMOVE) != 0) {
                    _ = w.TranslateMessage(&msg);
                    switch (msg.message) {
                        w.WM_KEYDOWN, w.WM_KEYUP, w.WM_SYSKEYDOWN, w.WM_SYSKEYUP => {
                            const pressed = msg.lParam & 1 << 31 == 0;
                            const repeat = pressed and msg.lParam & 1 << 30 != 0;
                            const sys = msg.message == w.WM_SYSKEYDOWN or msg.message == w.WM_SYSKEYUP;
                            const alt = sys and msg.lParam & 1 << 29 != 0;

                            if (!repeat and (!sys or alt or msg.wParam == w.VK_F10)) {
                                if (pressed) {
                                    if (msg.wParam == w.VK_F4 and alt) _ = w.DestroyWindow(g_hwnd);
                                    if (msg.wParam == w.VK_F11 or (msg.wParam == w.VK_RETURN and alt)) toggleFullscreen();
                                    if (DEVELOPER and msg.wParam == w.VK_ESCAPE) _ = w.DestroyWindow(g_hwnd);
                                }
                            }
                        },
                        w.WM_QUIT => break :game_loop,
                        else => _ = w.DispatchMessageW(&msg),
                    }
                }

                renderer.present();

                if (sleep_is_granular) {
                    w.Sleep(1);
                }
            }

            w.ExitProcess(0);
        }
    },
    else => @compileError("Unsupported OS"),
};
