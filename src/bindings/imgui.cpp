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

    void CImGuiShowDemoWindow() {
        ImGui::ShowDemoWindow();
    }

} // extern "c"
