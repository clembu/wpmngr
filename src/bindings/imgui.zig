pub fn init() Context {
    // NOTE(smugs): Default font atlas for now
    return CImGuiCreateContext(null);
}

pub fn deinit(ctx: Context) void {
    CImGuiDestroyContext(ctx);
}

pub fn newFrame() void {
    CImGuiNewFrame();
}

pub fn render() void {
    CImGuiRender();
}

pub fn getDrawData() DrawData {
    return CImGuiGetDrawData();
}

pub const io = struct {
    pub fn SetConfigFlags(flags: ConfigFlags) void {
        CImGuiSetConfigFlags(flags);
    }
};

pub const platform = struct {
    pub fn getRenderState() *anyopaque {
        return CImGuiPlatformIOGetRenderState();
    }
};

pub const dockSpace = struct {
    pub fn overViewport(args: struct {
        id: ID = 0,
        viewport: ?*Viewport = null,
        flags: DockNodeFlags = .{},
        window_class: ?*WindowClass = null,
    }) ID {
        return CImGuiDockSpaceOverViewport(
            args.id,
            args.viewport,
            args.flags,
            args.window_class,
        );
    }
};

pub fn showDemoWindow() void {
    CImGuiShowDemoWindow();
}

pub fn begin(name: [*:0]const u8, args: struct {
    open: ?*bool = null,
    flags: WindowFlags = .{},
}) bool {
    return CImGuiBegin(name, args.open, args.flags);
}

pub fn end() void {
    return CImGuiEnd();
}

pub const nextWindow = struct {
    pub fn setDockID(dock_id: ID, cond: Cond) void {
        CImGuiSetNextWindowDockID(dock_id, cond);
    }
};

pub fn getContentRegionAvail() [2]f32 {
    var avail: [2]f32 = undefined;
    CImGuiGetContentRegionAvail(&avail);
    return avail;
}

pub const cursor = struct {
    pub fn getScreenPos() [2]f32 {
        var pos: [2]f32 = undefined;
        CImGuiGetCursorScreenPos(&pos);
        return pos;
    }

    pub fn setScreenPos(pos: [2]f32) void {
        CImGuiSetCursorScreenPos(&pos);
    }

    extern fn CImGuiGetCursorScreenPos(*[2]f32) void;
    extern fn CImGuiSetCursorScreenPos(*const [2]f32) void;
};

pub fn image(texture_id: TextureID, args: struct {
    size: [2]f32,
    uv0: [2]f32 = .{ 0.0, 0.0 },
    uv1: [2]f32 = .{ 1.0, 1.0 },
}) void {
    CImGuiImage(texture_id, &args.size, &args.uv0, &args.uv1);
}

pub fn selectable(
    label: [:0]const u8,
    selected: bool,
    opts: struct {
        flags: SelectableFlags = .{},
        size: [2]f32 = .{ 0, 0 },
    },
) bool {
    return CImGuiSelectable(label, selected, opts.flags, &opts.size);
}

pub const SelectableFlags = packed struct(c_uint) {
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

pub const ComboFlags = packed struct(c_uint) {
    /// Align the popup toward the left by default
    popupAlignLeft: bool = false,
    height: enum(u4) {
        default = 0b0000,
        /// Max ~4 items visible. Tip: If you want your combo popup to be a specific size you can use SetNextWindowSizeConstraints() prior to calling BeginCombo()
        small = 0b0001,
        /// Max ~8 items visible (default)
        regular = 0b0010,
        /// max ~20 items visible
        large = 0b0100,
        /// as many fitting items as possible
        largest = 0b1000,
    } = .default,
    /// Display on the preview box without the square arrow button
    noArrowButton: bool = false,
    /// Display only a square arrow button
    noPreview: bool = false,
    /// Width dynamically calculated from preview contents
    widthFitPreview: bool = false,
    _unused_9_32: u24 = 0,
};

pub const combo = struct {
    pub fn begin(label: [:0]const u8, preview: ?[:0]const u8, opts: struct {
        flags: ComboFlags = .{},
    }) bool {
        return CImGuiBeginCombo(label, if (preview) |p| p.ptr else null, opts.flags);
    }

    pub fn end() void {
        CImGuiEndCombo();
    }
};

pub fn getWindowDrawList() DrawList {
    return CImGuiGetWindowDrawList();
}

pub const DrawList = *opaque {
    pub fn addRect(draw_list: DrawList, p_min: [2]f32, p_max: [2]f32, col: u32, opts: struct {
        rounding: f32 = 0,
        flags: DrawFlags = .{},
        thickness: f32 = 1,
    }) void {
        CImGuiDrawListAddRect(
            draw_list,
            &p_min,
            &p_max,
            col,
            opts.rounding,
            opts.flags,
            opts.thickness,
        );
    }

    pub fn addCallback(
        draw_list: DrawList,
        callback: DrawCallback,
        callback_data: ?*anyopaque,
    ) void {
        CImGuiDrawListAddCallback(draw_list, callback, callback_data);
    }

    pub fn addResetCallback(draw_list: DrawList) void {
        CImGuiDrawListAddResetCallback(draw_list);
    }

    extern fn CImGuiDrawListAddCallback(DrawList, DrawCallback, ?*anyopaque) void;
    extern fn CImGuiDrawListAddResetCallback(DrawList) void;
    extern fn CImGuiDrawListAddRect(DrawList, *const [2]f32, *const [2]f32, u32, f32, DrawFlags, f32) void;
};

pub const Context = *opaque {};
pub const DrawData = *opaque {};

pub const ConfigFlags = packed struct(c_int) {
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

pub const WindowFlags = packed struct(c_int) {
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

    pub const NoNav: WindowFlags = .{
        .NoNavInputs = true,
        .NoNavFocus = true,
    };
    const NoDecoration: WindowFlags = .{
        .NoTitleBar = true,
        .NoResize = true,
        .NoScrollbar = true,
        .NoCollapse = true,
    };
    const NoInputs: WindowFlags = .{
        .NoMouseInputs = true,
        .NoNavInputs = true,
        .NoNavFocus = true,
    };
};

pub const ID = u32;
pub const TextureID = *anyopaque;
pub const Viewport = opaque {};
pub const WindowClass = opaque {};

pub const DockNodeFlags = packed struct(c_int) {
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

// Note: The first parameter is a `DrawList`, but hard typing it would create a
// cyclic dependency and zig doesn't like it.
pub const DrawCallback = *const fn (*const anyopaque, *const anyopaque) callconv(.c) void;
pub const DrawCmd = extern struct {
    // 4*4  // Clipping rectangle (x1, y1, x2, y2). Subtract ImDrawData->DisplayPos to get clipping rectangle in "viewport" coordinates
    ClipRect: [4]f32,
    // 4-8  // User-provided texture ID. Set by user in ImfontAtlas::SetTexID() for fonts or passed to Image*() functions. Ignore if never using images or multiple fonts atlas.
    TextureId: TextureID,
    // 4    // Start offset in vertex buffer. ImGuiBackendFlags_RendererHasVtxOffset: always 0, otherwise may be >0 to support meshes larger than 64K vertices with 16-bit indices.
    VtxOffset: c_uint,
    // 4    // Start offset in index buffer.
    IdxOffset: c_uint,
    // 4    // Number of indices (multiple of 3) to be rendered as triangles. Vertices are stored in the callee ImDrawList's vtx_buffer[] array, indices in idx_buffer[].
    ElemCount: c_uint,
    // 4-8  // If != NULL, call the function instead of rendering the vertices. clip_rect and texture_id will be set normally.
    UserCallback: ?DrawCallback,
    // 4-8  // Callback user data (when UserCallback != NULL). If called AddCallback() with size == 0, this is a copy of the AddCallback() argument. If called AddCallback() with size > 0, this is pointing to a buffer where data is stored.
    UserCallbackData: ?*const anyopaque,
    // 4 // Size of callback user data when using storage, otherwise 0.
    UserCallbackDataSize: c_int,
    // 4 // [Internal] Offset of callback user data when using storage, otherwise -1.
    UserCallbackDataOffset: c_int,
};

pub const DrawFlags = packed struct(c_uint) {
    /// PathStroke(), AddPolyline(): specify that shape should be closed (Important: this is always == 1 for legacy reason)
    closed: bool = false,
    _unused_1_3: u3 = 0,
    round_corners: packed struct(u5) {
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
    } = .{},
    _unused_10_32: u23 = 0,
};

extern fn CImGuiCreateContext(?*anyopaque) Context;
extern fn CImGuiDestroyContext(?Context) void;
extern fn CImGuiNewFrame() void;
extern fn CImGuiShowDemoWindow() void;
extern fn CImGuiRender() void;
extern fn CImGuiGetDrawData() DrawData;
extern fn CImGuiSetConfigFlags(ConfigFlags) void;
extern fn CImGuiBegin([*:0]const u8, ?*bool, WindowFlags) bool;
extern fn CImGuiEnd() void;
extern fn CImGuiDockSpaceOverViewport(ID, ?*const Viewport, DockNodeFlags, ?*const WindowClass) ID;
extern fn CImGuiSetNextWindowDockID(ID, Cond) void;
extern fn CImGuiImage(TextureID, *const [2]f32, *const [2]f32, *const [2]f32) void;
extern fn CImGuiGetContentRegionAvail(*[2]f32) void;
extern fn CImGuiGetWindowDrawList() DrawList;
extern fn CImGuiPlatformIOGetRenderState() *anyopaque;
extern fn CImGuiSelectable([*:0]const u8, bool, SelectableFlags, *const [2]f32) bool;
extern fn CImGuiBeginCombo([*:0]const u8, ?[*:0]const u8, ComboFlags) bool;
extern fn CImGuiEndCombo() void;
