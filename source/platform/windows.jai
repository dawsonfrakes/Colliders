toggle_fullscreen :: () #no_context {

}

update_cursor_clip :: () #no_context {

}

clear_held_keys :: () #no_context {

}

window_proc :: (hwnd: HWND, message: u32, wParam: u64, lParam: s64) -> s64 #c_call {
    if message == {
    case WM_PAINT;
        ValidateRect(hwnd, null);
    case WM_ERASEBKGND;
        return 1;
    case WM_ACTIVATEAPP;
        if wParam != 0 update_cursor_clip();
        else clear_held_keys();
    case WM_SIZE;
        platform_screen_width = cast,no_check(u16) cast,no_check(u64) lParam;
        platform_screen_height = cast,no_check(u16) (cast,no_check(u64) lParam >> 16);

        #if OPENGL opengl_resize();
    case WM_CREATE;
        platform_hwnd = hwnd;
        platform_hdc = GetDC(hwnd);

        dark_mode : s32 = xx true;
        DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, *dark_mode, size_of(type_of(dark_mode)));
        round_mode : s32 = DWMWCP_DONOTROUND;
        DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, *round_mode, size_of(type_of(round_mode)));

        #if OPENGL {
            pfd : PIXELFORMATDESCRIPTOR;
            pfd.nSize = size_of(PIXELFORMATDESCRIPTOR);
            pfd.nVersion = 1;
            pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL |
                PFD_DOUBLEBUFFER | PFD_DEPTH_DONTCARE;
            pfd.cColorBits = 24;
            format := ChoosePixelFormat(platform_hdc, *pfd);
            SetPixelFormat(platform_hdc, format, *pfd);

            temp_ctx := wglCreateContext(platform_hdc);
            wglMakeCurrent(platform_hdc, temp_ctx);

            wglCreateContextAttribsARB : (HDC, HGLRC, *s32) -> HGLRC #c_call
                = xx wglGetProcAddress("wglCreateContextAttribsARB");

            attribs := s32.[
                WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
                WGL_CONTEXT_MINOR_VERSION_ARB, 6,
                WGL_CONTEXT_FLAGS_ARB, xx ifx DEVELOPER WGL_CONTEXT_DEBUG_BIT_ARB,
                WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
                0,
            ];
            opengl_ctx = wglCreateContextAttribsARB(platform_hdc, xx null, attribs.data);
            wglMakeCurrent(platform_hdc, opengl_ctx);

            wglDeleteContext(temp_ctx);

            dll := LoadLibraryW((#run ascii_to_utf16le_string_literal("opengl32")).data);
            glEnable = xx GetProcAddress(dll, "glEnable");
            glDisable = xx GetProcAddress(dll, "glDisable");
            glGetIntegerv = xx GetProcAddress(dll, "glGetIntegerv");
            glViewport = xx GetProcAddress(dll, "glViewport");
            glClearColor = xx GetProcAddress(dll, "glClearColor");
            glClear = xx GetProcAddress(dll, "glClear");

            glCreateProgram = xx wglGetProcAddress("glCreateProgram");
            glAttachShader = xx wglGetProcAddress("glAttachShader");
            glDetachShader = xx wglGetProcAddress("glDetachShader");
            glLinkProgram = xx wglGetProcAddress("glLinkProgram");
            glUseProgram = xx wglGetProcAddress("glUseProgram");
            glCreateShader = xx wglGetProcAddress("glCreateShader");
            glDeleteShader = xx wglGetProcAddress("glDeleteShader");
            glShaderSource = xx wglGetProcAddress("glShaderSource");
            glCompileShader = xx wglGetProcAddress("glCompileShader");

            glBindFramebuffer = xx wglGetProcAddress("glBindFramebuffer");
            glBindVertexArray = xx wglGetProcAddress("glBindVertexArray");

            glProgramUniform1i = xx wglGetProcAddress("glProgramUniform1i");

            glDrawElementsInstancedBaseVertexBaseInstance = xx wglGetProcAddress("glDrawElementsInstancedBaseVertexBaseInstance");

            glClipControl = xx wglGetProcAddress("glClipControl");
            glCreateFramebuffers = xx wglGetProcAddress("glCreateFramebuffers");
            glNamedFramebufferRenderbuffer = xx wglGetProcAddress("glNamedFramebufferRenderbuffer");
            glClearNamedFramebufferfv = xx wglGetProcAddress("glClearNamedFramebufferfv");
            glBlitNamedFramebuffer = xx wglGetProcAddress("glBlitNamedFramebuffer");
            glCreateRenderbuffers = xx wglGetProcAddress("glCreateRenderbuffers");
            glNamedRenderbufferStorageMultisample = xx wglGetProcAddress("glNamedRenderbufferStorageMultisample");
            glCreateVertexArrays = xx wglGetProcAddress("glCreateVertexArrays");
            glVertexArrayElementBuffer = xx wglGetProcAddress("glVertexArrayElementBuffer");
            glVertexArrayVertexBuffer = xx wglGetProcAddress("glVertexArrayVertexBuffer");
            glVertexArrayBindingDivisor = xx wglGetProcAddress("glVertexArrayBindingDivisor");
            glEnableVertexArrayAttrib = xx wglGetProcAddress("glEnableVertexArrayAttrib");
            glVertexArrayAttribBinding = xx wglGetProcAddress("glVertexArrayAttribBinding");
            glVertexArrayAttribFormat = xx wglGetProcAddress("glVertexArrayAttribFormat");
            glVertexArrayAttribIFormat = xx wglGetProcAddress("glVertexArrayAttribIFormat");
            glCreateBuffers = xx wglGetProcAddress("glCreateBuffers");
            glNamedBufferData = xx wglGetProcAddress("glNamedBufferData");
            glCreateTextures = xx wglGetProcAddress("glCreateTextures");
            glTextureStorage2D = xx wglGetProcAddress("glTextureStorage2D");
            glTextureSubImage2D = xx wglGetProcAddress("glTextureSubImage2D");
            glTextureParameteri = xx wglGetProcAddress("glTextureParameteri");
            glBindTextureUnit = xx wglGetProcAddress("glBindTextureUnit");

            opengl_init();
        }
    case WM_DESTROY;
        PostQuitMessage(0);
    case WM_SYSCOMMAND;
        if (wParam == SC_KEYMENU) return 0;
        #through;
    case;
        return DefWindowProcW(hwnd, message, wParam, lParam);
    }
    return 0;
}

entry :: () {
    platform_hinstance = GetModuleHandleW(null);

    sleep_is_granular := timeBeginPeriod(1) == TIMERR_NOERROR;

    #if STEAM {
        dll := LoadLibraryW((#run ascii_to_utf16le_string_literal("steam_api64")).data);
        if dll {
            SteamAPI_InitFlat = xx GetProcAddress(dll, "SteamAPI_InitFlat");
            SteamAPI_RunCallbacks = xx GetProcAddress(dll, "SteamAPI_RunCallbacks");
            SteamAPI_Shutdown = xx GetProcAddress(dll, "SteamAPI_Shutdown");
            SteamAPI_SteamFriends_v017 = xx GetProcAddress(dll, "SteamAPI_SteamFriends_v017");
            SteamAPI_ISteamFriends_GetPersonaName = xx GetProcAddress(dll, "SteamAPI_ISteamFriends_GetPersonaName");
            SteamAPI_ISteamFriends_GetFriendCount = xx GetProcAddress(dll, "SteamAPI_ISteamFriends_GetFriendCount");
            SteamAPI_ISteamFriends_GetFriendByIndex = xx GetProcAddress(dll, "SteamAPI_ISteamFriends_GetFriendByIndex");
            SteamAPI_ISteamFriends_GetFriendPersonaName = xx GetProcAddress(dll, "SteamAPI_ISteamFriends_GetFriendPersonaName");
            SteamAPI_ISteamFriends_GetMediumFriendAvatar = xx GetProcAddress(dll, "SteamAPI_ISteamFriends_GetMediumFriendAvatar");
            SteamAPI_SteamUtils_v010 = xx GetProcAddress(dll, "SteamAPI_SteamUtils_v010");
            SteamAPI_ISteamUtils_GetImageRGBA = xx GetProcAddress(dll, "SteamAPI_ISteamUtils_GetImageRGBA");
            SteamAPI_SteamUser_v023 = xx GetProcAddress(dll, "SteamAPI_SteamUser_v023");
            SteamAPI_ISteamUser_GetSteamID = xx GetProcAddress(dll, "SteamAPI_ISteamUser_GetSteamID");
        }

        platform_steam_enabled = SteamAPI_InitFlat && SteamAPI_InitFlat(null) == .OK;
        if platform_steam_enabled {
            steam_user = SteamAPI_SteamUser_v023();
            steam_utils = SteamAPI_SteamUtils_v010();
            steam_friends = SteamAPI_SteamFriends_v017();

            steam_friend_count = xx SteamAPI_ISteamFriends_GetFriendCount(steam_friends, .ALL);
        }
        defer if platform_steam_enabled SteamAPI_Shutdown();
    }

    SetProcessDPIAware();
    wndclass : WNDCLASSEXW;
    wndclass.cbSize = size_of(WNDCLASSEXW);
    wndclass.style = CS_OWNDC;
    wndclass.lpfnWndProc = window_proc;
    wndclass.hInstance = platform_hinstance;
    wndclass.hIcon = LoadIconW(xx null, IDI_WARNING);
    wndclass.hCursor = LoadCursorW(xx null, IDC_CROSS);
    wndclass.lpszClassName = (#run ascii_to_utf16le_string_literal("A")).data;
    RegisterClassExW(*wndclass);
    CreateWindowExW(0, wndclass.lpszClassName, (#run ascii_to_utf16le_string_literal("Colliders")).data,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        xx null, xx null, platform_hinstance, null);

    while game_loop := true {
        msg : MSG = ---;
        while PeekMessageW(*msg, xx null, 0, 0, PM_REMOVE) {
            using msg;
            TranslateMessage(*msg);
            if message == {
            case WM_KEYDOWN; #through;
            case WM_KEYUP; #through;
            case WM_SYSKEYDOWN; #through;
            case WM_SYSKEYUP;
                pressed := lParam & (1 << 31) == 0;
                repeat  := pressed && lParam & (1 << 30) != 0;
                sys     := message == WM_SYSKEYDOWN || message == WM_SYSKEYUP;
                alt     := sys && lParam & (1 << 29) != 0;

                if !repeat && (!sys || alt || wParam == VK_F10) {
                    if pressed {
                        if wParam == VK_F4 && alt DestroyWindow(platform_hwnd);
                        if wParam == VK_F11 || (wParam == VK_RETURN && alt) toggle_fullscreen();
                        if DEVELOPER && wParam == VK_ESCAPE DestroyWindow(platform_hwnd);
                        if wParam == #char "R" game_do_reset = true;
                    }
                }

                DispatchMessageW(*msg); // @hack steam overlay needs input.
            case WM_MOUSEWHEEL;
                delta := cast,no_check(s16) (wParam >> 16) / WHEEL_DELTA;
            case WM_QUIT;
                break game_loop;
            case;
                DispatchMessageW(*msg);
            }
        }

        #if STEAM if platform_steam_enabled SteamAPI_RunCallbacks();

        game_update();

        #if OPENGL {
            opengl_present();
            SwapBuffers(platform_hdc);
        }

        if sleep_is_granular {
            Sleep(1);
        }
    }
}

#program_export
RawEntryPoint :: () #c_call {
    first_thread_context : type_of(context);
    push_context first_thread_context {
        entry();
    }

    ExitProcess(0);
}
