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

    bool CImGuiBegin(const char* name, bool* p_open, ImGuiWindowFlags flags) {
        return ImGui::Begin(name, p_open, flags);
    }

    void CImGuiEnd() {
        ImGui::End();
    }

    bool CImGuiBeginChild(
        const char* str_id,
        const float size[2],
        ImGuiChildFlags child_flags,
        ImGuiWindowFlags window_flags 
   ) {
        return ImGui::BeginChild(str_id, {size[0], size[1]}, child_flags, window_flags);
    }

    void CImGuiEndChild() {
        ImGui::EndChild();
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

    void CImGuiSeparator() {
        ImGui::Separator();
    };

    // call between widgets or groups to layout them horizontally. X position given in window coordinates.
    void CImGuiSameLine(float offset_from_start_x, float spacing) {
        ImGui::SameLine(offset_from_start_x, spacing);
    }

    // Docking

    ImGuiID CImGuiDockSpaceOverViewport(
        ImGuiID dockspace_id,
        const ImGuiViewport* viewport,
        ImGuiDockNodeFlags flags,
        const ImGuiWindowClass* window_class
    ) {
        return ImGui::DockSpaceOverViewport(dockspace_id, viewport, flags, window_class);
    }

    void CImGuiSetNextWindowDockID(ImGuiID dock_id, ImGuiCond cond) {
        ImGui::SetNextWindowDockID(dock_id, cond);
    }

    // is the last item hovered? (and usable, aka not blocked by a popup, etc.). See ImGuiHoveredFlags for more options.
    bool CImGuiIsItemHovered(ImGuiHoveredFlags flags) {
        return ImGui::IsItemHovered(flags);
    }

    // Item/Widgets Utilities and Query Functions
    bool CImGuiIsItemActive() {
        return ImGui::IsItemActive();
    }

    // was the last item just made active (item was previously inactive).
    bool CImGuiIsItemActivated() {
        return ImGui::IsItemActivated();
    }
    // was the last item just made inactive (item was previously active). Useful for Undo/Redo patterns with widgets that require continuous editing.
    bool CImGuiIsItemDeactivated() {
        return ImGui::IsItemDeactivated();
    }

    // Mouse Input
    
    // did mouse button clicked? (went from !Down to Down). Same as GetMouseClickedCount() == 1.
    bool CImGuiIsMouseClicked(ImGuiMouseButton button, bool repeat) {
        return ImGui::IsMouseClicked(button, repeat);
    }

    void CImGuiGetMousePos(float pos[2]) {
        const ImVec2 mp = ImGui::GetMousePos();
        pos[0] = mp.x;
        pos[1] = mp.y;
    }

    void CImGuiGetMouseDelta(float delta[2]) {
        const ImVec2 mdd = ImGui::GetIO().MouseDelta;
        delta[0] = mdd.x;
        delta[1] = mdd.y;
    }

    void CImGuiGetMouseDragDelta(
        float pos[2],
        ImGuiMouseButton button,
        float lock_threshold
    ) {
        const ImVec2 mdd = ImGui::GetMouseDragDelta();
        pos[0] = mdd.x;
        pos[1] = mdd.y;
    }

    // set desired mouse cursor shape
    void CImGuiSetMouseCursor(ImGuiMouseCursor cursor_type) {
        ImGui::SetMouseCursor(cursor_type);
    }

    // Builtin Windows

    void CImGuiShowDemoWindow() {
        ImGui::ShowDemoWindow();
    }

    void CImGuiShowDefaultStyleEditor() {
        ImGui::ShowStyleEditor();
    }

    // Text
    
    // raw text without formatting.
    // Roughly equivalent to Text("%s", text) but:
    // A) doesn't require null terminated string if 'text_end' is specified,
    // B) it's faster, no memory copy is done, no buffer size limits,
    // recommended for long chunks of text.
    void CImGuiTextUnformatted(
        const char* text,
        const char* text_end
    ) {
        ImGui::TextUnformatted(text, text_end);
    }

    void CImGuiSeparatorText(const char* label) {
        ImGui::SeparatorText(label);
    }

    // Main Widgets

     bool CImGuiButton(const char* label, const float size[2]) {
         return ImGui::Button(label, {size[0], size[1]});
     }

    // flexible button behavior without the visuals, frequently useful to build custom behaviors using the public api (along with IsItemActive, IsItemHovered, etc.)
    bool CImGuiInvisibleButton(
        const char* str_id,
        const float size[2],
        ImGuiButtonFlags flags
    ) {
        return ImGui::InvisibleButton(str_id, {size[0],size[1]}, flags);
    }

    bool CImGuiCheckbox(const char* label, bool* v) {
        return ImGui::Checkbox(label, v);
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

    // "bool* p_selected" point to the selection state (read-write), as a convenient helper.
    bool CImGuiSelectablePtr(
        const char* label,
        bool* p_selected,
        ImGuiSelectableFlags flags,
        const float size[2]
    ) {
        return ImGui::Selectable(label, p_selected, flags, {size[0], size[1]});
    }

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

    // Sliders

    bool CImGuiDragFloat(
        const char* label,
        float* v,
        float v_speed,
        float v_min,
        float v_max,
        const char* format,
        ImGuiSliderFlags flags
    ) {
        return ImGui::DragFloat(label, v, v_speed, v_min, v_max, format, flags);
    }
                                        
    bool CImGuiDragInt(
        const char* label,
        int* v,
        float v_speed,
        int v_min,
        int v_max,
        const char* format,
        ImGuiSliderFlags flags
    ) {
        return ImGui::DragInt(label, v, v_speed, v_min, v_max, format, flags);
    }

    // PlatformIO

    void* CImGuiPlatformIOGetRenderState() {
        return ImGui::GetPlatformIO().Renderer_RenderState;
    }

    // DrawList

    ImDrawList* CImGuiGetWindowDrawList() {
        return ImGui::GetWindowDrawList();
    }

    ImDrawListFlags CImGuiDrawListGetFlags(ImDrawList* draw_list) {
        return draw_list->Flags;
    }

    void CImGuiDrawListSetFlags(ImDrawList* draw_list, ImDrawListFlags flags) {
        draw_list->Flags = flags;
    }

    void CImGuiDrawListAddLine(
        ImDrawList* draw_list,
        const float p1[2],
        const float p2[2],
        ImU32 col,
        float thickness
    ) {
        draw_list->AddLine({p1[0],p1[1]}, {p2[0],p2[1]}, col, thickness);
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

    void CImGuiDrawListAddQuad(
        ImDrawList* draw_list,
        const float p1[2],
        const float p2[2],
        const float p3[2],
        const float p4[2],
        ImU32 col,
        float thickness
    ) {
        draw_list->AddQuad({p1[0],p1[1]}, {p2[0],p2[1]}, {p3[0],p3[1]}, {p4[0],p4[1]}, col, thickness);
    }

    void CImGuiDrawListAddImageQuad(
        ImDrawList* draw_list,
        ImTextureID user_texture_id,
        const float p1[2],
        const float p2[2],
        const float p3[2],
        const float p4[2],
        const float uv1[2],
        const float uv2[2],
        const float uv3[2],
        const float uv4[2],
        ImU32 col
    ) {
        draw_list->AddImageQuad(user_texture_id, {p1[0],p1[1]}, {p2[0],p2[1]}, {p3[0],p3[1]}, {p4[0],p4[1]}, {uv1[0],uv1[1]}, {uv2[0],uv2[1]}, {uv3[0],uv3[1]}, {uv4[0],uv4[1]}, col);
    }

    void CImGuiDrawListPathStroke(
        ImDrawList* draw_list,
        ImU32 col,
        ImDrawFlags flags,
        float thickness
    ) {
        draw_list->PathStroke(col, flags, thickness);
    }

    void CImGuiDrawListPathArcTo(
        ImDrawList* draw_list,
        const float center[2],
        float radius,
        float a_min,
        float a_max,
        int num_segments
    ) {
        draw_list->PathArcTo({center[0], center[1]}, radius, a_min, a_max, num_segments );
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
