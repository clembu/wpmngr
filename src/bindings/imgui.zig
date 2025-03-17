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

pub fn showDemoWindow() void {
    CImGuiShowDemoWindow();
}

pub const Context = *opaque {};
pub const DrawData = *opaque {};

pub const ConfigFlags = enum(c_int) {
    ImGuiConfigFlags_None = 0,
    /// Master keyboard navigation enable flag. Enable full Tabbing + directional arrows + space/enter to activate.
    ImGuiConfigFlags_NavEnableKeyboard = 1 << 0,
    /// Master gamepad navigation enable flag. Backend also needs to set ImGuiBackendFlags_HasGamepad.
    ImGuiConfigFlags_NavEnableGamepad = 1 << 1,
    /// Instruct dear imgui to disable mouse inputs and interactions.
    ImGuiConfigFlags_NoMouse = 1 << 4,
    /// Instruct backend to not alter mouse cursor shape and visibility. Use if the backend cursor changes are interfering with yours and you don't want to use SetMouseCursor() to change mouse cursor. You may want to honor requests from imgui by reading GetMouseCursor() yourself instead.
    ImGuiConfigFlags_NoMouseCursorChange = 1 << 5,
    /// Instruct dear imgui to disable keyboard inputs and interactions. This is done by ignoring keyboard events and clearing existing states.
    ImGuiConfigFlags_NoKeyboard = 1 << 6,

    // [BETA] Docking
    /// Docking enable flags.
    ImGuiConfigFlags_DockingEnable = 1 << 7,

    // [BETA] Viewports
    /// When using viewports it is recommended that your default value for ImGuiCol_WindowBg is opaque (Alpha=1.0) so transition to a viewport won't be noticeable.
    ///
    /// Viewport enable flags (require both ImGuiBackendFlags_PlatformHasViewports + ImGuiBackendFlags_RendererHasViewports set by the respective backends)
    ImGuiConfigFlags_ViewportsEnable = 1 << 10,
    /// [BETA: Don't use] FIXME-DPI: Reposition and resize imgui windows when the DpiScale of a viewport changed (mostly useful for the main viewport hosting other window). Note that resizing the main window itself is up to your application.
    ImGuiConfigFlags_DpiEnableScaleViewports = 1 << 14,
    /// [BETA: Don't use] FIXME-DPI: Request bitmap-scaled fonts to match DpiScale. This is a very low-quality workaround. The correct way to handle DPI is _currently_ to replace the atlas and/or fonts in the Platform_OnChangedViewport callback, but this is all early work in progress.
    ImGuiConfigFlags_DpiEnableScaleFonts = 1 << 15,

    // User storage (to allow your backend/engine to communicate to code that may be shared between multiple projects. Those flags are NOT used by core Dear ImGui)
    /// Application is SRGB-aware.
    ImGuiConfigFlags_IsSRGB = 1 << 20,
    /// Application is using a touch screen instead of a mouse.
    ImGuiConfigFlags_IsTouchScreen = 1 << 21,
};

extern fn CImGuiCreateContext(?*anyopaque) Context;
extern fn CImGuiDestroyContext(?Context) void;
extern fn CImGuiNewFrame() void;
extern fn CImGuiShowDemoWindow() void;
extern fn CImGuiRender() void;
extern fn CImGuiGetDrawData() DrawData;
extern fn CImGuiSetConfigFlags(ConfigFlags) void;
