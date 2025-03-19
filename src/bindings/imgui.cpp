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

    void CImGuiGetContentRegionAvail(float size[2]) {
        const ImVec2 avail = ImGui::GetContentRegionAvail();
        size[0] = avail.x;
        size[1] = avail.y;
    }

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

    void CImGuiShowDemoWindow() {
        ImGui::ShowDemoWindow();
    }


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

    // PlatformIO

    void* CImGuiPlatformIOGetRenderState() {
        return ImGui::GetPlatformIO().Renderer_RenderState;
    }

    // DrawList

    ImDrawList* CImGuiGetWindowDrawList() {
        return ImGui::GetWindowDrawList();
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
