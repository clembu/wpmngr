#include "imgui.h"

extern "C" {
    ImGuiContext* CImGuiCreateContext(ImFontAtlas* shared_font_atlas) {
        return ImGui::CreateContext(shared_font_atlas);
    }

    void CImGuiSetConfigFlags(ImGuiConfigFlags flags) {
        ImGui::GetIO().ConfigFlags = flags;
    }

    void CImGuiDestroyContext(ImGuiContext *ctx)
    {
        ImGui::DestroyContext(ctx);
    }
    void CImGuiNewFrame() {
        ImGui::NewFrame();
    }
    void CImGuiRender() {
        ImGui::Render();
    }
    ImDrawData* CImGuiGetDrawData() {
        return ImGui::GetDrawData();
    }

    bool CImGuiBegin(const char* name, bool* p_open = NULL, ImGuiWindowFlags flags = 0) {
        return ImGui::Begin(name, p_open, flags);
    }

    void CImGuiEnd() {
        ImGui::End();
    }

    // Layout

    void CImGuiGetContentRegionAvail(float size[2]) {
        const ImVec2 avail = ImGui::GetContentRegionAvail();
        size[0] = avail.x;
        size[1] = avail.y;
    }

    void CImGuiGetCursorScreenPos(float pos[2]) {
        const ImVec2 cur = ImGui::GetCursorScreenPos();
        pos[0] = cur.x;
        pos[1] = cur.y;
    }

    void CImGuiSetCursorScreenPos(const float pos[2]) {
        ImGui::SetCursorScreenPos({pos[0],pos[1]});
    }

    // Docking

    ImGuiID CImGuiDockSpaceOverViewport(
        ImGuiID dockspace_id = 0,
        const ImGuiViewport* viewport = NULL,
        ImGuiDockNodeFlags flags = 0,
        const ImGuiWindowClass* window_class = NULL
    ) {
        return ImGui::DockSpaceOverViewport(dockspace_id, viewport, flags, window_class);
    }
    
    void CImGuiSetNextWindowDockID(ImGuiID dock_id, ImGuiCond cond = 0) {
        ImGui::SetNextWindowDockID(dock_id, cond);
    }

    // Builtin Windows
    
    void CImGuiShowDemoWindow() {
        ImGui::ShowDemoWindow();
    }

    // Images

    void CImGuiImage(
        ImTextureID user_texture_id,
        const float image_size[2],
        const float uv0[2],
        const float uv1[2]
    ) {
        ImGui::Image(
            user_texture_id,
            {image_size[0],image_size[1]},
            {uv0[0], uv0[1]},
            {uv1[0], uv1[1]}
        );
    }

    // Selectables

    // "bool selected" carry the selection state (read-only). Selectable() is clicked is returns true so you can modify your selection state. size.x==0.0: use remaining width, size.x>0.0: specify width. size.y==0.0: use label height, size.y>0.0: specify height
    bool CImGuiSelectable(
        const char* label,
        bool selected,
        ImGuiSelectableFlags flags,
        const float size[2]
    ) {
        return ImGui::Selectable(label, selected, flags, {size[0], size[1]});
    };

    // ComboBox

    bool CImGuiBeginCombo(
        const char* label,
        const char* preview_value,
        ImGuiComboFlags flags
    ) {
        return ImGui::BeginCombo(label, preview_value, flags);
    }

    void CImGuiEndCombo() {
        ImGui::EndCombo();
    }
                                        
    // PlatformIO

    void* CImGuiPlatformIOGetRenderState() {
        return ImGui::GetPlatformIO().Renderer_RenderState;
    }

    // DrawList

    ImDrawList* CImGuiGetWindowDrawList() {
        return ImGui::GetWindowDrawList();
    }

    // a: upper-left, b: lower-right (== upper-left + size)
    void CImGuiDrawListAddRect(
        ImDrawList* draw_list,
        const float p_min[2],
        const float p_max[2],
        ImU32 col,
        float rounding,
        ImDrawFlags flags,
        float thickness
    ) {
        draw_list->AddRect({p_min[0],p_min[1]}, {p_max[0],p_max[1]}, col, rounding, flags, thickness);
    }

    void CImGuiDrawListAddCallback(
        ImDrawList* draw_list,
        ImDrawCallback callback,
        void* userdata
    ) {
        draw_list->AddCallback(callback, userdata);
    }

    void CImGuiDrawListAddResetCallback(
        ImDrawList* draw_list
    ) {
        draw_list->AddCallback(ImDrawCallback_ResetRenderState, NULL);
    }

} // extern "c"
