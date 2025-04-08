var tmp_buf: ?std.ArrayList(u8) = null;

const std = @import("std");
pub const backend = switch (@import("builtin").target.os.tag) {
    .windows => @import("imgui_win32_dx11.zig"),
    else => .{},
};

// ---------------
// | Basic Types |
// ---------------

pub const ID = u32;

pub const Cond = enum(c_int) {
    /// No condition (always set the variable), same as _Always
    none = 0,
    /// No condition (always set the variable), same as _None
    always = 1 << 0,
    /// Set the variable once per runtime session (only the first call will succeed)
    once = 1 << 1,
    /// Set the variable if the object/window has no persistently saved data (no entry in .ini file)
    first_use_ever = 1 << 2,
    /// Set the variable if the object/window is appearing after being hidden/inactive (or the first time)
    appearing = 1 << 3,
};

// -------------------------------
// | Context Creation and access |
// -------------------------------

pub const Context = *opaque {};

/// - Each context create its own ImFontAtlas by default.
///   You may instance one yourself and pass it to CreateContext() to share a font atlas between contexts.
/// - DLL users: heaps and globals are not shared across DLL boundaries!
///   You will need to call SetCurrentContext() + SetAllocatorFunctions() for each static/DLL boundary you are calling from.
///   Read "Context and Memory Allocators" section of imgui.cpp for details.
pub fn init(allocator: std.mem.Allocator) Context {
    tmp_buf = .init(allocator);
    // NOTE(smugs): Default font atlas for now
    return CImGuiCreateContext(null);
}
extern fn CImGuiCreateContext(?*anyopaque) Context;

/// if given null, destroy current context
pub fn deinit(ctx: ?Context) void {
    tmp_buf.?.deinit();
    CImGuiDestroyContext(ctx);
}
extern fn CImGuiDestroyContext(?Context) void;

// --------
// | Main |
// --------

pub fn newFrame() void {
    CImGuiNewFrame();
}
extern fn CImGuiNewFrame() void;

pub fn render() void {
    CImGuiRender();
}
extern fn CImGuiRender() void;

pub fn getDrawData() draw.Data {
    return CImGuiGetDrawData();
}
extern fn CImGuiGetDrawData() draw.Data;

pub const config = struct {
    pub fn SetFlags(flags: Flags) void {
        CImGuiSetConfigFlags(flags);
    }
    extern fn CImGuiSetConfigFlags(Flags) void;

    pub const Flags = packed struct(c_int) {
        /// Master keyboard navigation enable flag. Enable full Tabbing + directional arrows + space/enter to activate.
        NavEnableKeyboard: bool = false,
        /// Master gamepad navigation enable flag. Backend also needs to set ImGuiBackendFlags_HasGamepad.
        NavEnableGamepad: bool = false,
        /// Bits 3 and 4 aren't used
        _unused_3_4: u2 = 0,
        /// Instruct dear imgui to disable mouse inputs and interactions.
        NoMouse: bool = false,
        /// Instruct backend to not alter mouse cursor shape and visibility. Use if the backend cursor changes are interfering with yours and you don't want to use SetMouseCursor() to change mouse cursor. You may want to honor requests from imgui by reading GetMouseCursor() yourself instead.
        NoMouseCursorChange: bool = false,
        /// Instruct dear imgui to disable keyboard inputs and interactions. This is done by ignoring keyboard events and clearing existing states.
        NoKeyboard: bool = false,

        // [BETA] Docking
        /// Docking enable flags.
        DockingEnable: bool = false,

        /// Bits 9 and 10 aren't used
        _unused_9_10: u2 = 0,

        // [BETA] Viewports
        /// When using viewports it is recommended that your default value for ImGuiCol_WindowBg is opaque (Alpha=1.0) so transition to a viewport won't be noticeable.
        ///
        /// Viewport enable flags (require both ImGuiBackendFlags_PlatformHasViewports + ImGuiBackendFlags_RendererHasViewports set by the respective backends)
        ViewportsEnable: bool = false,
        /// Bits 12 through 14 aren't used
        _unused_12_14: u3 = 0,
        /// [BETA: Don't use] FIXME-DPI: Reposition and resize imgui windows when the DpiScale of a viewport changed (mostly useful for the main viewport hosting other window). Note that resizing the main window itself is up to your application.
        DpiEnableScaleViewports: bool = false,
        /// [BETA: Don't use] FIXME-DPI: Request bitmap-scaled fonts to match DpiScale. This is a very low-quality workaround. The correct way to handle DPI is _currently_ to replace the atlas and/or fonts in the Platform_OnChangedViewport callback, but this is all early work in progress.
        DpiEnableScaleFonts: bool = false,

        /// Bits 17 through 20 aren't used
        _unused_17_20: u4 = 0,

        // User storage (to allow your backend/engine to communicate to code that may be shared between multiple projects. Those flags are NOT used by core Dear ImGui)
        /// Application is SRGB-aware.
        IsSRGB: bool = false,
        /// Application is using a touch screen instead of a mouse.
        IsTouchScreen: bool = false,

        /// Bits 23 through 32 aren't used
        _unused_23_32: u10 = 0,
    };
};

// ----------------------------
// | Demo, Debug, Information |
// ----------------------------

/// create Demo window.
/// demonstrate most ImGui features.
/// call this to learn about the library!
/// try to make it always available in your application!
pub fn showDemoWindow() void {
    CImGuiShowDemoWindow();
}
extern fn CImGuiShowDemoWindow() void;

pub fn showDefaultStyleEditor() void {
    CImGuiShowDefaultStyleEditor();
}
extern fn CImGuiShowDefaultStyleEditor() void;

/// -----------
/// | Windows |
/// -----------
pub const window = struct {
    /// Push a window to the stack and start appending to it.
    ///
    /// Passing '.{ .open: &is_open }' shows a window-closing widget
    /// in the upper-right corner of the window,
    /// which clicking will set the boolean to false when clicked.
    ///
    /// You may append multiple times to the same window during the same frame by
    /// calling Begin()/End() pairs with the same name  multiple times.
    /// Some information such as 'flags' or 'p_open' will only be considered by
    /// the first call to Begin().
    ///
    /// Returns false to indicate the window is collapsed or fully clipped,
    /// so you may early out and omit submitting anything to the window.
    ///
    /// Always call a matching End() for each Begin() call, regardless of its return value!
    ///
    /// [Important: due to legacy reason, Begin/End and BeginChild/EndChild are
    /// inconsistent with all other functions such as
    /// BeginMenu/EndMenu, BeginPopup/EndPopup, etc.
    /// where the EndXXX call should only be called if the corresponding
    /// BeginXXX function returned true.
    /// Begin and BeginChild are the only odd ones out.
    /// Will be fixed in a future update.]
    ///
    /// Note that the bottom of window stack always contains a window called "Debug".
    pub fn begin(name: [*:0]const u8, args: struct {
        open: ?*bool = null,
        flags: Flags = .{},
    }) bool {
        return CImGuiBegin(name, args.open, args.flags);
    }
    extern fn CImGuiBegin([*:0]const u8, ?*bool, Flags) bool;

    /// Pop a window from the stack.
    pub fn end() void {
        return CImGuiEnd();
    }
    extern fn CImGuiEnd() void;

    pub fn beginChild(name: [*:0]const u8, args: struct {
        size: [2]f32 = .{ 0, 0 },
        child_flags: ChildFlags = .{},
        window_flags: Flags = .{},
    }) bool {
        return CImGuiBeginChild(name, &args.size, args.child_flags, args.window_flags);
    }
    extern fn CImGuiBeginChild([*:0]const u8, *const [2]f32, ChildFlags, Flags) bool;

    /// Pop a window from the stack.
    pub fn endChild() void {
        return CImGuiEndChild();
    }
    extern fn CImGuiEndChild() void;

    // ---------------------
    // | Windows Utilities |
    // ---------------------

    pub fn getDrawList() draw.List {
        return CImGuiGetWindowDrawList();
    }
    extern fn CImGuiGetWindowDrawList() draw.List;

    pub const next = struct {
        pub fn setDockID(dock_id: ID, cond: Cond) void {
            CImGuiSetNextWindowDockID(dock_id, cond);
        }
    };
    extern fn CImGuiSetNextWindowDockID(ID, Cond) void;

    pub const Flags = packed struct(c_int) {
        /// Disable title-bar
        NoTitleBar: bool = false,
        /// Disable user resizing with the lower-right grip
        NoResize: bool = false,
        /// Disable user moving the window
        NoMove: bool = false,
        /// Disable scrollbars (window can still scroll with mouse or programmatically)
        NoScrollbar: bool = false,
        /// Disable user vertically scrolling with mouse wheel. On child window, mouse wheel will be forwarded to the parent unless NoScrollbar is also set.
        NoScrollWithMouse: bool = false,
        /// Disable user collapsing window by double-clicking on it. Also referred to as Window Menu Button (e.g. within a docking node).
        NoCollapse: bool = false,
        /// Resize every window to its content every frame
        AlwaysAutoResize: bool = false,
        /// Disable drawing background color (WindowBg, etc.) and outside border. Similar as using SetNextWindowBgAlpha(0.0f).
        NoBackground: bool = false,
        /// Never load/save settings in .ini file
        NoSavedSettings: bool = false,
        /// Disable catching mouse, hovering test with pass through.
        NoMouseInputs: bool = false,
        /// Has a menu-bar
        MenuBar: bool = false,
        /// Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
        HorizontalScrollbar: bool = false,
        /// Disable taking focus when transitioning from hidden to visible state
        NoFocusOnAppearing: bool = false,
        /// Disable bringing window to front when taking focus (e.g. clicking on it or programmatically giving it focus)
        NoBringToFrontOnFocus: bool = false,
        /// Always show vertical scrollbar (even if ContentSize.y < Size.y)
        AlwaysVerticalScrollbar: bool = false,
        /// Always show horizontal scrollbar (even if ContentSize.x < Size.x)
        AlwaysHorizontalScrollbar: bool = false,
        /// No keyboard/gamepad navigation within the window
        NoNavInputs: bool = false,
        /// No focusing toward this window with keyboard/gamepad navigation (e.g. skipped by CTRL+TAB)
        NoNavFocus: bool = false,
        /// Display a dot next to the title. When used in a tab/docking context, tab is selected when clicking the X + closure is not assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
        UnsavedDocument: bool = false,
        /// Disable docking of this window
        NoDocking: bool = false,

        /// Bits 21 through 24 aren't used
        _unused_21_24: u4 = 0,
        /// Internal flags used by specialized Begin functions.
        _internals: u6 = 0,
        /// Bits 31 and 32 are obsolete
        _unused_31_32: u2 = 0,

        pub const NoNav: Flags = .{
            .NoNavInputs = true,
            .NoNavFocus = true,
        };
        const NoDecoration: Flags = .{
            .NoTitleBar = true,
            .NoResize = true,
            .NoScrollbar = true,
            .NoCollapse = true,
        };
        const NoInputs: Flags = .{
            .NoMouseInputs = true,
            .NoNavInputs = true,
            .NoNavFocus = true,
        };
    };

    pub const ChildFlags = packed struct(c_int) {
        /// Show an outer border and enable WindowPadding.
        borders: bool = false,
        /// Pad with style.WindowPadding even if no border are drawn (no padding by default for non-bordered child windows because it makes more sense)
        alwaysUseWindowPadding: bool = false,
        /// Allow resize from right border (layout direction). Enable .ini saving (unless ImGuiWindowFlags_NoSavedSettings passed to window flags)
        resizeX: bool = false,
        /// Allow resize from bottom border (layout direction). "
        resizeY: bool = false,
        /// Enable auto-resizing width. Read "IMPORTANT: Size measurement" details above.
        autoResizeX: bool = false,
        /// Enable auto-resizing height. Read "IMPORTANT: Size measurement" details above.
        autoResizeY: bool = false,
        /// Combined with AutoResizeX/AutoResizeY. Always measure size even when child is hidden, always return true, always disable clipping optimization! NOT RECOMMENDED.
        alwaysAutoResize: bool = false,
        /// Style the child window like a framed item: use FrameBg, FrameRounding, FrameBorderSize, FramePadding instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.
        frameStyle: bool = false,
        /// [BETA] Share focus scope, allow keyboard/gamepad navigation to cross over parent border to this child or between sibling child windows.
        navFlattened: bool = false,
        _unused_10_32: u23 = 0,
    };
};

/// -----------------------------
/// | Layout cursor positioning |
/// -----------------------------
/// Layout cursor positioning
/// - By "cursor" we mean the current output position.
/// - The typical widget behavior is to output themselves at the current cursor position, then move the cursor one line down.
/// - You can call SameLine() between widgets to undo the last carriage return and output at the right of the preceding widget.
/// - YOU CAN DO 99% OF WHAT YOU NEED WITH ONLY GetCursorScreenPos() and GetContentRegionAvail().
/// - Attention! We currently have inconsistencies between window-local and absolute positions we will aim to fix with future API:
///    - Absolute coordinate:        GetCursorScreenPos(), SetCursorScreenPos(), all ImDrawList:: functions. -> this is the preferred way forward.
///    - Window-local coordinates:   SameLine(offset), GetCursorPos(), SetCursorPos(), GetCursorStartPos(), PushTextWrapPos()
///    - Window-local coordinates:   GetContentRegionMax(), GetWindowContentRegionMin(), GetWindowContentRegionMax() --> all obsoleted. YOU DON'T NEED THEM.
/// - GetCursorScreenPos() = GetCursorPos() + GetWindowPos(). GetWindowPos() is almost only ever useful to convert from window-local to absolute coordinates. Try not to use it.
pub const cursor = struct {
    // get the cursor position, absolute coordinates. THIS IS YOUR BEST FRIEND
    //
    // (prefer using this rather than GetPos(), also more useful to work with ImDrawList API).
    pub fn getScreenPos() [2]f32 {
        var pos: [2]f32 = undefined;
        CImGuiGetCursorScreenPos(&pos);
        return pos;
    }
    extern fn CImGuiGetCursorScreenPos(*[2]f32) void;

    // set the cursor position, absolute coordinates. THIS IS YOUR BEST FRIEND.
    pub fn setScreenPos(pos: [2]f32) void {
        CImGuiSetCursorScreenPos(&pos);
    }
    extern fn CImGuiSetCursorScreenPos(*const [2]f32) void;

    /// available space from current position. THIS IS YOUR BEST FRIEND.
    pub fn getContentRegionAvail() [2]f32 {
        var avail: [2]f32 = undefined;
        CImGuiGetContentRegionAvail(&avail);
        return avail;
    }
    extern fn CImGuiGetContentRegionAvail(*[2]f32) void;
};

pub fn separator(opts: struct {
    label: ?[:0]const u8 = null,
}) void {
    if (opts.label) |l| {
        CImGuiSeparatorText(l);
    } else {
        CImGuiSeparator();
    }
}
extern fn CImGuiSeparator() void;
extern fn CImGuiSeparatorText([*:0]const u8) void;

pub const layout = struct {
    pub fn sameLine(opts: struct {
        xoffset: f32 = 0,
        spacing: f32 = -1,
    }) void {
        CImGuiSameLine(opts.xoffset, opts.spacing);
    }
    extern fn CImGuiSameLine(f32, f32) void;
};

// -----------------
// | Widgets: Text |
// -----------------
pub fn text(comptime fmt: []const u8, args: anytype) !void {
    // Resize the buffer if needed
    const req_len = std.fmt.count(fmt, args);
    if (req_len > tmp_buf.?.items.len) {
        try tmp_buf.?.resize(@intCast(req_len));
    }
    const formatted = try std.fmt.bufPrint(tmp_buf.?.items, fmt, args);
    CImGuiTextUnformatted(formatted.ptr, formatted.ptr + formatted.len);
}
extern fn CImGuiTextUnformatted([*]const u8, [*]const u8) void;

// -----------------
// | Widgets: Main |
// -----------------

pub fn button(label: [:0]const u8, opts: struct { size: [2]f32 = .{ 0, 0 } }) bool {
    return CImGuiButton(label, &opts.size);
}
extern fn CImGuiButton([*:0]const u8, *const [2]f32) bool;

pub fn invisibleButton(label: [:0]const u8, size: [2]f32, opts: struct {
    flags: ButtonFlags = .{},
}) bool {
    return CImGuiInvisibleButton(label, &size, opts.flags);
}
extern fn CImGuiInvisibleButton([*:0]const u8, *const [2]f32, ButtonFlags) bool;

pub fn checkbox(label: [:0]const u8, checked: *bool) bool {
    return CImGuiCheckbox(label, checked);
}
extern fn CImGuiCheckbox(label: [*:0]const u8, v: *bool) bool;

pub fn progressBar(
    progress: f32,
    opts: struct {
        size: [2]f32 = .{ -std.math.floatMin(f32), 0 },
        overlay: ?[:0]const u8 = null,
    },
) void {
    CImGuiProgressBar(progress, &opts.size, if (opts.overlay) |s| s else null);
}
extern fn CImGuiProgressBar(f32, *const [2]f32, ?[*:0]const u8) void;

pub fn loadingBar(
    opts: struct {
        speed: f32 = 1,
        size: [2]f32 = .{ -std.math.floatMin(f32), 0 },
        overlay: ?[:0]const u8 = null,
    },
) void {
    CImGuiLoadingBar(opts.speed, &opts.size, if (opts.overlay) |s| s else null);
}
extern fn CImGuiLoadingBar(f32, *const [2]f32, ?[*:0]const u8) void;

pub const ButtonFlags = packed struct(c_int) {
    mouse_button: MouseButton = .{ .left = true },
    /// InvisibleButton(): do not disable navigation/tabbing. Otherwise disabled by default.
    EnableNav: bool = false,
    _unused_5_32: u28 = 0,

    pub const MouseButton = packed struct(u3) {
        /// React on left mouse button (default)
        left: bool = false,
        /// React on right mouse button
        right: bool = false,
        /// React on center mouse button
        middle: bool = false,
    };
};

// -------------------
// | Widgets: Images |
// -------------------

/// - Read about ImTextureID here: https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples
pub const TextureID = *anyopaque;

/// - Read about ImTextureID here: https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples
/// - 'uv0' and 'uv1' are texture coordinates. Read about them from the same link above.
/// - Image() pads adds style.ImageBorderSize on each side, ImageButton() adds style.FramePadding on each side.
/// - ImageButton() draws a background based on regular Button() color + optionally an inner background if specified.
pub fn image(texture_id: TextureID, args: struct {
    size: [2]f32,
    uv0: [2]f32 = .{ 0.0, 0.0 },
    uv1: [2]f32 = .{ 1.0, 1.0 },
}) void {
    CImGuiImage(texture_id, &args.size, &args.uv0, &args.uv1);
}
extern fn CImGuiImage(TextureID, *const [2]f32, *const [2]f32, *const [2]f32) void;

/// ---------------------------------
/// | Widgets: Combo Box (Dropdown) |
/// ---------------------------------
/// - The BeginCombo()/EndCombo() api allows you to manage your contents and selection state however you want it, by creating e.g. Selectable() items.
pub const combo = struct {
    pub fn begin(label: [:0]const u8, preview: ?[:0]const u8, opts: struct {
        flags: Flags = .{},
    }) bool {
        return CImGuiBeginCombo(label, if (preview) |p| p.ptr else null, opts.flags);
    }
    extern fn CImGuiBeginCombo([*:0]const u8, ?[*:0]const u8, Flags) bool;

    pub fn end() void {
        CImGuiEndCombo();
    }
    extern fn CImGuiEndCombo() void;

    pub const Flags = packed struct(c_uint) {
        /// Align the popup toward the left by default
        popupAlignLeft: bool = false,
        /// Tweak the height of the child window
        height: Height = .default,
        /// Display on the preview box without the square arrow button
        noArrowButton: bool = false,
        /// Display only a square arrow button
        noPreview: bool = false,
        /// Width dynamically calculated from preview contents
        widthFitPreview: bool = false,
        _unused_9_32: u24 = 0,

        pub const Height = enum(u4) {
            default = 0b0000,
            /// Max ~4 items visible. Tip: If you want your combo popup to be a specific size you can use SetNextWindowSizeConstraints() prior to calling BeginCombo()
            small = 0b0001,
            /// Max ~8 items visible (default)
            regular = 0b0010,
            /// max ~20 items visible
            large = 0b0100,
            /// as many fitting items as possible
            largest = 0b1000,
        };
    };
};

// -------------------------
// | Widgets: Drag Sliders |
// -------------------------

pub fn dragFloat(label: [:0]const u8, value: *f32, opts: struct {
    speed: f32 = 1,
    min: f32 = 0,
    max: f32 = 0,
    cfmt: [:0]const u8 = "%.3f",
    flags: SliderFlags = .{},
}) bool {
    return CImGuiDragFloat(label, value, opts.speed, opts.min, opts.max, opts.cfmt, opts.flags);
}
extern fn CImGuiDragFloat([*:0]const u8, *f32, f32, f32, f32, [*:0]const u8, SliderFlags) bool;

pub fn dragInt(label: [:0]const u8, value: *u32, opts: struct {
    speed: f32 = 1,
    min: u32 = 0,
    max: u32 = 0,
    cfmt: [:0]const u8 = "%d",
    flags: SliderFlags = .{},
}) bool {
    return CImGuiDragInt(label, value, opts.speed, opts.min, opts.max, opts.cfmt, opts.flags);
}
extern fn CImGuiDragInt([*:0]const u8, *u32, f32, u32, u32, [*:0]const u8, SliderFlags) bool;

pub const SliderFlags = packed struct(c_int) {
    _unused_1_5: u5 = 0,
    /// Make the widget logarithmic (linear otherwise). Consider using ImGuiSliderFlags_NoRoundToFormat with this if using a format-string with small amount of digits.
    logarithmic: bool = false,
    /// Disable rounding underlying value to match precision of the display format string (e.g. %.3f values are rounded to those 3 digits).
    noRoundToFormat: bool = false,
    /// Disable CTRL+Click or Enter key allowing to input text directly into the widget.
    noInput: bool = false,
    /// Enable wrapping around from max to min and from min to max. Only supported by DragXXX() functions for now.
    wrapAround: bool = false,
    /// Clamp value to min/max bounds when input manually with CTRL+Click. By default CTRL+Click allows going out of bounds.
    clampOnInput: bool = false,
    /// Clamp even if min==max==0.0f. Otherwise due to legacy reason DragXXX functions don't clamp with those values. When your clamping limits are dynamic you almost always want to use it.
    clampZeroRange: bool = false,
    /// Disable keyboard modifiers altering tweak speed. Useful if you want to alter tweak speed yourself based on your own logic.
    noSpeedTweaks: bool = false,
    _unused_13_32: u20 = 0,
    pub const alwaysClamp: SliderFlags = .{ .clampOnInput = true, .clampZeroRange = true };
};

/// --------------------------------
/// | Widgets: Input with Keyboard |
/// --------------------------------
pub const input = struct {
    pub fn text(label: [:0]const u8, buf: []u8, opts: struct {
        flags: Flags = .{},
    }) bool {
        return CImGuiInputText(label, buf.ptr, buf.len, opts.flags);
    }
    extern fn CImGuiInputText([*:0]const u8, [*]u8, usize, Flags) bool;

    pub const Flags = packed struct(u32) {
        chars: packed struct {
            /// Allow 0123456789.+-*/
            decimal: bool = false,
            /// Allow 0123456789ABCDEFabcdef
            hexadecimal: bool = false,
            /// Allow 0123456789.+-*/eE (Scientific notation input)
            scientific: bool = false,
            /// Turn a..z into A..Z
            uppercase: bool = false,
            /// Filter out spaces, tabs
            no_blank: bool = false,
        } = .{},

        keybinds: packed struct {
            /// Pressing TAB input a '\t' character into the text field
            allow_tab_input: bool = false,
            /// Return 'true' when Enter is pressed (as opposed to every time the value was modified). Consider using IsItemDeactivatedAfterEdit() instead!
            enter_returns_true: bool = false,
            /// Escape key clears content if not empty, and deactivate otherwise (contrast to default behavior of Escape to revert)
            escape_clears_all: bool = false,
            /// In multi-line mode, validate with Enter, add new line with Ctrl+Enter (default is opposite: validate with Ctrl+Enter, add line with Enter).
            ctrl_enter_for_new_line: bool = false,
        } = .{},

        /// Read-only mode
        read_only: bool = false,
        /// Password mode, display all characters as '*', disable copy
        password: bool = false,
        /// Overwrite mode
        always_overwrite: bool = false,
        /// Select entire text when first taking mouse focus
        auto_select_all: bool = false,

        /// InputFloat(), InputInt(), InputScalar() etc. only:
        empty_ref_val: packed struct {
            /// parse empty string as zero value.
            parse: bool = false,
            /// when value is zero, do not display it.
            /// Generally used with `parse`.
            display: bool = false,
        } = .{},

        /// Disable following the cursor horizontally
        no_horizontal_scroll: bool = false,
        /// Disable undo/redo. Note that input text owns the text data while active, if you want to provide your own undo/redo stack you need e.g. to call ClearActiveID().
        no_undo_redo: bool = false,

        /// When text doesn't fit, elide left side to ensure right side stays visible.
        /// Useful for path/filenames. Single-line only!
        elide_left: bool = false,

        // Callback features
        _unused_callback_19_24: u6 = 0,

        _unused_25_32: u8 = 0,
    };
};

/// ------------------------
/// | Widgets: Selectables |
/// ------------------------
/// - A selectable highlights when hovered, and can display another color when selected.
/// - Neighbors selectable extend their highlight bounds in order to leave no gap between them. This is so a series of selected Selectable appear contiguous.
pub const selectable = struct {
    /// "selected" carries the selection state (read-only).
    ///
    /// Returns true if clicked so you can modify your selection state.
    ///
    /// Size:
    /// - size.x==0.0: use remaining width,
    /// - size.x>0.0: specify width.
    /// - size.y==0.0: use label height,
    /// - size.y>0.0: specify height.
    pub fn manual(
        label: [:0]const u8,
        selected: bool,
        opts: struct {
            flags: Flags = .{},
            size: [2]f32 = .{ 0, 0 },
        },
    ) bool {
        return CImGuiSelectable(label, selected, opts.flags, &opts.size);
    }
    extern fn CImGuiSelectable([*:0]const u8, bool, Flags, *const [2]f32) bool;

    /// "selected" points to the selection state (read-write), as a convenient helper.
    ///
    /// Returns true if clicked.
    ///
    /// Size:
    /// - size.x==0.0: use remaining width,
    /// - size.x>0.0: specify width.
    /// - size.y==0.0: use label height,
    /// - size.y>0.0: specify height.
    pub fn auto(
        label: [:0]const u8,
        selected: *bool,
        opts: struct {
            flags: Flags = .{},
            size: [2]f32 = .{ 0, 0 },
        },
    ) bool {
        return CImGuiSelectable(label, selected, opts.flags, &opts.size);
    }
    extern fn CImGuiSelectablePtr([*:0]const u8, *bool, Flags, *const [2]f32) bool;

    pub const Flags = packed struct(c_uint) {
        /// Clicking this doesn't close parent popup window (overrides ImGuiItemFlags_AutoClosePopups)
        noAutoClosePopups: bool = false,
        /// Frame will span all columns of its container table (text will still fit in current column)
        spanAllColumns: bool = false,
        /// Generate press events on double clicks too
        allowDoubleClick: bool = false,
        /// Cannot be selected, display grayed out text
        disabled: bool = false,
        /// (WIP) Hit testing to allow subsequent widgets to overlap this one
        allowOverlap: bool = false,
        /// Make the item be displayed as if it is hovered
        highlight: bool = false,
        _unused_7_32: u26 = 0,
    };
};

/// -----------
/// | Docking |
/// -----------
/// [BETA API] Enable with io.ConfigFlags |= ImGuiConfigFlags_DockingEnable.
/// Note: You can use most Docking facilities without calling any API. You DO NOT need to call DockSpace() to use Docking!
/// - Drag from window title bar or their tab to dock/undock. Hold SHIFT to disable docking.
/// - Drag from window menu button (upper-left button) to undock an entire node (all windows).
/// - When io.ConfigDockingWithShift == true, you instead need to hold SHIFT to enable docking.
/// About dockspaces:
/// - Use DockSpaceOverViewport() to create a window covering the screen or a specific viewport + a dockspace inside it.
///   This is often used with ImGuiDockNodeFlags_PassthruCentralNode to make it transparent.
/// - Use DockSpace() to create an explicit dock node _within_ an existing window. See Docking demo for details.
/// - Important: Dockspaces need to be submitted _before_ any window they can host. Submit it early in your frame!
/// - Important: Dockspaces need to be kept alive if hidden, otherwise windows docked into it will be undocked.
///   e.g. if you have multiple tabs with a dockspace inside each tab: submit the non-visible dockspaces with ImGuiDockNodeFlags_KeepAliveOnly.
pub const dockSpace = struct {
    pub fn overViewport(args: struct {
        id: ID = 0,
        viewport: ?*Viewport = null,
        flags: NodeFlags = .{},
        window_class: ?*WindowClass = null,
    }) ID {
        return CImGuiDockSpaceOverViewport(
            args.id,
            args.viewport,
            args.flags,
            args.window_class,
        );
    }
    extern fn CImGuiDockSpaceOverViewport(ID, ?*const Viewport, NodeFlags, ?*const WindowClass) ID;

    pub const WindowClass = opaque {};

    pub const NodeFlags = packed struct(c_int) {
        /// Represent a Platform Window
        ImGuiViewportFlags_IsPlatformWindow: bool = false,
        /// Represent a Platform Monitor (unused yet)
        ImGuiViewportFlags_IsPlatformMonitor: bool = false,
        /// Platform Window: Is created/managed by the user application? (rather than our backend)
        ImGuiViewportFlags_OwnedByApp: bool = false,
        /// Platform Window: Disable platform decorations: title bar, borders, etc. (generally set all windows, but if ImGuiConfigFlags_ViewportsDecoration is set we only set this on popups/tooltips)
        ImGuiViewportFlags_NoDecoration: bool = false,
        /// Platform Window: Disable platform task bar icon (generally set on popups/tooltips, or all windows if ImGuiConfigFlags_ViewportsNoTaskBarIcon is set)
        ImGuiViewportFlags_NoTaskBarIcon: bool = false,
        /// Platform Window: Don't take focus when created.
        ImGuiViewportFlags_NoFocusOnAppearing: bool = false,
        /// Platform Window: Don't take focus when clicked on.
        ImGuiViewportFlags_NoFocusOnClick: bool = false,
        /// Platform Window: Make mouse pass through so we can drag this window while peaking behind it.
        ImGuiViewportFlags_NoInputs: bool = false,
        /// Platform Window: Renderer doesn't need to clear the framebuffer ahead (because we will fill it entirely).
        ImGuiViewportFlags_NoRendererClear: bool = false,
        /// Platform Window: Avoid merging this window into another host window. This can only be set via ImGuiWindowClass viewport flags override (because we need to now ahead if we are going to create a viewport in the first place!).
        ImGuiViewportFlags_NoAutoMerge: bool = false,
        /// Platform Window: Display on top (for tooltips only).
        ImGuiViewportFlags_TopMost: bool = false,
        /// Viewport can host multiple imgui windows (secondary viewports are associated to a single window). // FIXME: In practice there's still probably code making the assumption that this is always and only on the MainViewport. Will fix once we add support for "no main viewport".
        ImGuiViewportFlags_CanHostOtherWindows: bool = false,

        // Output status flags (from Platform)
        /// Platform Window: Window is minimized, can skip render. When minimized we tend to avoid using the viewport pos/size for clipping window or testing if they are contained in the viewport.
        ImGuiViewportFlags_IsMinimized: bool = false,
        /// Platform Window: Window is focused (last call to Platform_GetWindowFocus() returned true)
        ImGuiViewportFlags_IsFocused: bool = false,

        _unused_15_32: u18 = 0,
    };
};

/// ----------------------------------------------
/// | Item/Widgets Utilities and Query Functions |
/// ----------------------------------------------
pub const item = struct {
    pub fn isHovered(flags: HoveredFlags) bool {
        return CImGuiIsItemHovered(flags);
    }
    extern fn CImGuiIsItemHovered(HoveredFlags) bool;

    pub fn isActive() bool {
        return CImGuiIsItemActive();
    }
    extern fn CImGuiIsItemActive() bool;

    pub fn isActivated() bool {
        return CImGuiIsItemActivated();
    }
    extern fn CImGuiIsItemActivated() bool;

    pub fn isDeactivated() bool {
        return CImGuiIsItemDeactivated();
    }
    extern fn CImGuiIsItemDeactivated() bool;

    pub const HoveredFlags = packed struct(u32) {
        /// IsWindowHovered() only: Return true if any children of the window is hovered
        childWindows: bool = false,
        /// IsWindowHovered() only: Test from root window (top most parent of the current hierarchy)
        rootWindow: bool = false,
        /// IsWindowHovered() only: Return true if any window is hovered
        anyWindow: bool = false,
        /// IsWindowHovered() only: Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
        noPopupHierarchy: bool = false,
        /// IsWindowHovered() only: Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
        dockHierarchy: bool = false,
        /// Return true even if a popup window is normally blocking access to this item/window
        allowWhenBlockedByPopup: bool = false,
        /// Return true even if a modal popup window is normally blocking access to this item/window. FIXME-TODO: Unavailable yet.
        allowWhenBlockedByModal: bool = false,
        /// Return true even if an active item is blocking access to this item/window. Useful for Drag and Drop patterns.
        allowWhenBlockedByActiveItem: bool = false,
        /// IsItemHovered() only: Return true even if the item uses AllowOverlap mode and is overlapped by another hoverable item.
        allowWhenOverlappedByItem: bool = false,
        /// IsItemHovered() only: Return true even if the position is obstructed or overlapped by another window.
        allowWhenOverlappedByWindow: bool = false,
        /// IsItemHovered() only: Return true even if the item is disabled
        allowWhenDisabled: bool = false,
        /// IsItemHovered() only: Disable using keyboard/gamepad navigation state when active, always query mouse
        noNavOverride: bool = false,
        _unused: u20 = 0,
    };
};

/// ---------------------------
/// | Inputs Utilities: Mouse |
/// ---------------------------
pub const mouse = struct {
    /// did mouse button clicked? (went from !Down to Down). Same as GetMouseClickedCount() == 1.
    pub fn isClicked(btn: MouseButton, opts: struct {
        repeat: bool = false,
    }) bool {
        return CImGuiIsMouseClicked(btn, opts.repeat);
    }
    extern fn CImGuiIsMouseClicked(MouseButton, bool) bool;

    pub fn getPos() [2]f32 {
        var pos: [2]f32 = undefined;
        CImGuiGetMousePos(&pos);
        return pos;
    }
    extern fn CImGuiGetMousePos(*[2]f32) void;

    pub fn getDelta() [2]f32 {
        var delta: [2]f32 = undefined;
        CImGuiGetMouseDelta(&delta);
        return delta;
    }
    extern fn CImGuiGetMouseDelta(*[2]f32) void;

    pub fn getDragDelta(
        opts: struct {
            mouse_button: MouseButton = .left,
            lock_threshold: f32 = -1,
        },
    ) [2]f32 {
        var delta: [2]f32 = undefined;
        CImGuiGetMouseDragDelta(&delta, opts.mouse_button, opts.lock_threshold);
        return delta;
    }
    extern fn CImGuiGetMouseDragDelta(*[2]f32, MouseButton, f32) void;

    pub fn setPointer(ptr: MousePointer) void {
        CImGuiSetMouseCursor(ptr);
    }
    extern fn CImGuiSetMouseCursor(MousePointer) void;

    pub const MouseButton = enum(c_int) {
        left = 0,
        right = 1,
        middle = 2,
    };

    pub const MousePointer = enum(c_int) {
        none = -1,
        arrow = 0,
        /// When hovering over InputText, etc.
        textInput,
        /// (Unused by Dear ImGui functions)
        resizeAll,
        /// When hovering over a horizontal border
        resizeNS,
        /// When hovering over a vertical border or a column
        resizeEW,
        /// When hovering over the bottom-left corner of a window
        resizeNESW,
        /// When hovering over the bottom-right corner of a window
        resizeNWSE,
        /// (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
        hand,
        /// When waiting for something to process/load.
        wait,
        /// When waiting for something to process/load, but application is still interactive.
        progress,
        /// When hovering something with disallowed interaction. Usually a crossed circle.
        notAllowed,
    };
};

/// ---------------
/// | Drawing API |
/// ---------------
/// Hold a series of drawing commands.
/// The user provides a renderer for ImDrawData which essentially contains an array of ImDrawList.
pub const draw = struct {
    /// ImDrawCallback: Draw callbacks for advanced uses [configurable type: override in imconfig.h]
    /// NB: You most likely do NOT need to use draw callbacks just to create your own widget or customized UI rendering,
    /// you can poke into the draw list for that! Draw callback may be useful for example to:
    ///  A) Change your GPU render state,
    ///  B) render a complex 3D scene inside a UI element without an intermediate texture/render target, etc.
    /// The expected behavior from your rendering function is 'if (cmd.UserCallback != NULL) { cmd.UserCallback(parent_list, cmd); } else { RenderTriangles() }'
    /// If you want to override the signature of ImDrawCallback, you can simply use e.g. '#define ImDrawCallback MyDrawCallback' (in imconfig.h) + update rendering backend accordingly.
    ///
    /// Note:
    /// The first parameter is a `DrawList`.
    /// The second parameter is a `DrawCmd`.
    /// Hard typing it would create a cyclic dependency and zig doesn't like it.
    pub const Callback = *const fn (*const anyopaque, *const anyopaque) callconv(.c) void;

    /// This is the low-level list of polygons that ImGui:: functions are filling. At the end of the frame,
    /// all command lists are passed to your ImGuiIO::RenderDrawListFn function for rendering.
    /// Each dear imgui window contains its own ImDrawList. You can use ImGui::GetWindowDrawList() to
    /// access the current window draw list and draw custom primitives.
    /// You can interleave normal ImGui:: calls and adding primitives to the current draw list.
    /// In single viewport mode, top-left is == GetMainViewport()->Pos (generally 0,0), bottom-right is == GetMainViewport()->Pos+Size (generally io.DisplaySize).
    /// You are totally free to apply whatever transformation matrix you want to the data (depending on the use of the transformation you may want to apply it to ClipRect as well!)
    /// Important: Primitives are always added to the list and not culled (culling is done at higher-level by ImGui:: functions), if you use this API a lot consider coarse culling your drawn objects.
    pub const List = *opaque {
        pub fn getFlags(draw_list: List) ListFlags {
            return CImGuiDrawListGetFlags(draw_list);
        }
        extern fn CImGuiDrawListGetFlags(List) ListFlags;

        pub fn setFlags(draw_list: List, flags: ListFlags) void {
            CImGuiDrawListSetFlags(draw_list, flags);
        }
        extern fn CImGuiDrawListSetFlags(List, ListFlags) void;

        pub fn addLine(draw_list: List, a: [2]f32, b: [2]f32, col: u32, opts: struct {
            thickness: f32 = 1.0,
        }) void {
            CImGuiDrawListAddLine(draw_list, &a, &b, col, opts.thickness);
        }
        extern fn CImGuiDrawListAddLine(List, *const [2]f32, *const [2]f32, u32, f32) void;

        // a: upper-left, b: lower-right (== upper-left + size)
        pub fn addRect(draw_list: List, a: [2]f32, b: [2]f32, col: u32, opts: struct {
            rounding: f32 = 0,
            flags: Flags = .{},
            thickness: f32 = 1.0,
        }) void {
            CImGuiDrawListAddRect(
                draw_list,
                &a,
                &b,
                col,
                opts.rounding,
                opts.flags,
                opts.thickness,
            );
        }
        extern fn CImGuiDrawListAddRect(List, *const [2]f32, *const [2]f32, u32, f32, Flags, f32) void;

        pub fn addQuad(
            draw_list: List,
            points: [4][2]f32,
            col: u32,
            opts: struct {
                thickness: f32 = 1.0,
            },
        ) void {
            CImGuiDrawListAddQuad(
                draw_list,
                &points[0],
                &points[1],
                &points[2],
                &points[3],
                col,
                opts.thickness,
            );
        }
        extern fn CImGuiDrawListAddQuad(List, *const [2]f32, *const [2]f32, *const [2]f32, *const [2]f32, u32, f32) void;

        pub fn addImageQuad(
            draw_list: List,
            user_texture_id: TextureID,
            points: [4][2]f32,
            uvs: [4][2]f32,
            opts: struct {
                col: u32 = 0xffffffff,
            },
        ) void {
            CImGuiDrawListAddImageQuad(
                draw_list,
                user_texture_id,
                &points[0],
                &points[1],
                &points[2],
                &points[3],
                &uvs[0],
                &uvs[1],
                &uvs[2],
                &uvs[3],
                opts.col,
            );
        }
        extern fn CImGuiDrawListAddImageQuad(List, TextureID, *const [2]f32, *const [2]f32, *const [2]f32, *const [2]f32, *const [2]f32, *const [2]f32, *const [2]f32, *const [2]f32, u32) void;

        pub fn path(draw_list: List) Path {
            return @ptrCast(draw_list);
        }

        /// Advanced: Draw Callbacks
        /// - May be used to alter render state (change sampler, blending, current shader). May be used to emit custom rendering commands (difficult to do correctly, but possible).
        /// - Use special ImDrawCallback_ResetRenderState callback to instruct backend to reset its render state to the default.
        /// - Your rendering loop must check for 'UserCallback' in ImDrawCmd and call the function instead of rendering triangles. All standard backends are honoring this.
        /// - For some backends, the callback may access selected render-states exposed by the backend in a ImGui_ImplXXXX_RenderState structure pointed to by platform_io.Renderer_RenderState.
        /// - IMPORTANT: please be mindful of the different level of indirection between using size==0 (copying argument) and using size>0 (copying pointed data into a buffer).
        ///   - If userdata_size == 0: we copy/store the 'userdata' argument as-is. It will be available unmodified in ImDrawCmd::UserCallbackData during render.
        ///   - If userdata_size > 0,  we copy/store 'userdata_size' bytes pointed to by 'userdata'. We store them in a buffer stored inside the drawlist. ImDrawCmd::UserCallbackData will point inside that buffer so you have to retrieve data from there. Your callback may need to use ImDrawCmd::UserCallbackDataSize if you expect dynamically-sized data.
        ///   - Support for userdata_size > 0 was added in v1.91.4, October 2024. So earlier code always only allowed to copy/store a simple void*.
        pub fn addCallback(
            draw_list: List,
            callback: Callback,
            callback_data: ?*anyopaque,
        ) void {
            CImGuiDrawListAddCallback(draw_list, callback, callback_data);
        }
        extern fn CImGuiDrawListAddCallback(List, Callback, ?*anyopaque) void;

        /// Special Draw callback value to request renderer backend to reset the graphics/render state.
        /// The renderer backend needs to handle this special value, otherwise it will crash trying to call a function at this address.
        /// This is useful, for example, if you submitted callbacks which you know have altered the render state and you want it to be restored.
        /// Render state is not reset by default because they are many perfectly useful way of altering render state (e.g. changing shader/blending settings before an Image call).
        pub fn addResetCallback(draw_list: List) void {
            CImGuiDrawListAddResetCallback(draw_list);
        }
        extern fn CImGuiDrawListAddResetCallback(List) void;

        // Flags for ImDrawList instance. Those are set automatically by ImGui:: functions from ImGuiIO settings, and generally not manipulated directly.
        // It is however possible to temporarily alter flags between calls to ImDrawList:: functions.
        pub const ListFlags = packed struct(c_int) {
            /// Enable anti-aliased lines/borders (*2 the number of triangles for 1.0f wide line or lines thin enough to be drawn using textures, otherwise *3 the number of triangles)
            antiAliasedLines: bool = false,
            /// Enable anti-aliased lines/borders using textures when possible. Require backend to render with bilinear filtering (NOT point/nearest filtering).
            antiAliasedLinesUseTex: bool = false,
            /// Enable anti-aliased edge around filled shapes (rounded rectangles, circles).
            antiAliasedFill: bool = false,
            /// Can emit 'VtxOffset > 0' to allow large meshes. Set when 'ImGuiBackendFlags_RendererHasVtxOffset' is enabled.
            allowVtxOffset: bool = false,
            _unused_5_32: u28 = 0,
        };
    };

    pub const Path = *opaque {
        pub fn arc(
            path: Path,
            center: [2]f32,
            radius: f32,
            angle_min: f32,
            angle_max: f32,
            opts: struct {
                num_segments: u32 = 0,
            },
        ) void {
            CImGuiDrawListPathArcTo(path, &center, radius, angle_min, angle_max, opts.num_segments);
        }
        extern fn CImGuiDrawListPathArcTo(Path, *const [2]f32, f32, f32, f32, u32) void;

        pub fn stroke(
            path: Path,
            col: u32,
            opts: struct {
                flags: Flags = .{},
                thickness: f32 = 1,
            },
        ) void {
            CImGuiDrawListPathStroke(path, col, opts.flags, opts.thickness);
        }
        extern fn CImGuiDrawListPathStroke(Path, u32, Flags, f32) void;
    };

    /// Typically, 1 command = 1 GPU draw call (unless command is a callback)
    /// - VtxOffset: When 'io.BackendFlags & ImGuiBackendFlags_RendererHasVtxOffset' is enabled,
    ///   this fields allow us to render meshes larger than 64K vertices while keeping 16-bit indices.
    ///   Backends made for <1.71. will typically ignore the VtxOffset fields.
    /// - The ClipRect/TextureId/VtxOffset fields must be contiguous as we memcmp() them together (this is asserted for).
    pub const Cmd = extern struct {
        /// Clipping rectangle (x1, y1, x2, y2).
        /// Subtract ImDrawData->DisplayPos to get clipping rectangle in "viewport" coordinates
        ///
        /// Size:4*4
        ClipRect: [4]f32,
        /// User-provided texture ID.
        /// Set by user in ImfontAtlas::SetTexID() for fonts or passed to Image*() functions.
        /// Ignore if never using images or multiple fonts atlas.
        ///
        /// Size: 4-8
        TextureId: TextureID,
        /// Start offset in vertex buffer.
        /// ImGuiBackendFlags_RendererHasVtxOffset: always 0, otherwise may be >0 to support meshes larger than 64K vertices with 16-bit indices.
        ///
        /// Size: 4
        VtxOffset: c_uint,
        /// Start offset in index buffer.
        ///
        /// Size: 4
        IdxOffset: c_uint,
        /// Number of indices (multiple of 3) to be rendered as triangles.
        /// Vertices are stored in the callee ImDrawList's vtx_buffer[] array,
        /// indices in idx_buffer[].
        ///
        /// Size: 4
        ElemCount: c_uint,
        /// If != NULL, call the function instead of rendering the vertices.
        /// clip_rect and texture_id will be set normally.
        ///
        /// Size: 4-8
        UserCallback: ?Callback,
        /// Callback user data (when UserCallback != NULL).
        /// If called AddCallback() with size == 0, this is a copy of the AddCallback() argument.
        /// If called AddCallback() with size > 0, this is pointing to a buffer where data is stored.
        ///
        /// Size: 4-8
        UserCallbackData: ?*const anyopaque,
        /// Size of callback user data when using storage, otherwise 0.
        ///
        /// Size: 4
        UserCallbackDataSize: c_int,
        /// [Internal] Offset of callback user data when using storage, otherwise -1.
        ///
        /// Size: 4
        UserCallbackDataOffset: c_int,
    };

    pub const Flags = packed struct(c_uint) {
        /// PathStroke(), AddPolyline(): specify that shape should be closed (Important: this is always == 1 for legacy reason)
        closed: bool = false,
        _unused_1_3: u3 = 0,
        /// How to round the corners.
        ///
        /// For AddRect(), AddRectFilled() and PathRect().
        round_corners: RoundCorners = .{},
        _unused_10_32: u23 = 0,

        pub const RoundCorners = packed struct(u5) {
            /// AddRect(), AddRectFilled(), PathRect(): enable rounding top-left corner only (when rounding > 0.0f, we default to all corners). Was 0x01.
            topLeft: bool = false,
            /// AddRect(), AddRectFilled(), PathRect(): enable rounding top-right corner only (when rounding > 0.0f, we default to all corners). Was 0x02.
            topRight: bool = false,
            /// AddRect(), AddRectFilled(), PathRect(): enable rounding bottom-left corner only (when rounding > 0.0f, we default to all corners). Was 0x04.
            bottomLeft: bool = false,
            /// AddRect(), AddRectFilled(), PathRect(): enable rounding bottom-right corner only (when rounding > 0.0f, we default to all corners). Wax 0x08.
            bottomRight: bool = false,
            /// AddRect(), AddRectFilled(), PathRect(): disable rounding on all corners (when rounding > 0.0f). This is NOT zero, NOT an implicit flag!
            none: bool = false,

            pub const all: @This() = .{
                .topLeft = true,
                .topRight = true,
                .bottomLeft = true,
                .bottomRight = true,
            };
            pub const top: @This() = .{
                .topLeft = true,
                .topRight = true,
            };
            pub const bottom: @This() = .{
                .bottomLeft = true,
                .bottomRight = true,
            };

            pub const left: @This() = .{
                .topLeft = true,
                .bottomLeft = true,
            };
            pub const right: @This() = .{
                .topRight = true,
                .bottomRight = true,
            };
        };
    };

    /// All draw data to render a Dear ImGui frame
    pub const Data = *opaque {};
};

// -------------
// | Viewports |
// -------------

/// - Currently represents the Platform Window created by the application which is hosting our Dear ImGui windows.
/// - With multi-viewport enabled, we extend this concept to have multiple active viewports.
/// - In the future we will extend this concept further to also represent Platform Monitor and support a "no main platform window" operation mode.
/// - About Main Area vs Work Area:
///   - Main Area = entire viewport.
///   - Work Area = entire viewport minus sections used by main menu bars (for platform windows), or by task bar (for platform monitor).
///   - Windows are generally trying to stay within the Work Area of their host viewport.
pub const Viewport = opaque {};

/// ---------------
/// | Platform IO |
/// ---------------
pub const platform = struct {
    /// Written by some backends during ImGui_ImplXXXX_RenderDrawData() call to
    /// point backend_specific ImGui_ImplXXXX_RenderState* structure.
    pub fn getRenderState() *anyopaque {
        return CImGuiPlatformIOGetRenderState();
    }
    extern fn CImGuiPlatformIOGetRenderState() *anyopaque;
};
