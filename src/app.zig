const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const V2 = @import("V2.zig");

image: ?Image,
aspect: [2]u32,
roi: [4][2]f32,
working_screen_roi: ?[4][2]f32 = null,
set_sampler: imgui.draw.Callback,
set_diff_blender: imgui.draw.Callback,

pub fn init(
    set_sampler: imgui.draw.Callback,
    set_diff_blender: imgui.draw.Callback,
) @This() {
    return .{
        .image = null,
        .aspect = .{ 9, 16 },
        .roi = .{
            .{ 0, 0 },
            .{ 1, 0 },
            .{ 1, 1 },
            .{ 0, 1 },
        },
        .set_sampler = set_sampler,
        .set_diff_blender = set_diff_blender,
    };
}

fn clamp_aspect(aspect: [2]f32, max_size: [2]f32) [2]f32 {
    const maxwf: f32 = max_size[0];
    const maxhf: f32 = max_size[1];
    const maxratio = maxwf / maxhf;
    const aspratio = aspect[0] / aspect[1];
    if (aspratio > maxratio) {
        return .{ maxwf, maxwf / aspratio };
    } else {
        return .{ maxhf * aspratio, maxhf };
    }
}

pub fn set_full_roi(self: *@This()) void {
    if (self.image) |img| {
        const roi_size = clamp_aspect(
            .{ @floatFromInt(self.aspect[0]), @floatFromInt(self.aspect[1]) },
            .{ @floatFromInt(img.width), @floatFromInt(img.height) },
        );
        self.roi = .{
            .{ 0, 0 },
            .{ roi_size[0], 0 },
            .{ roi_size[0], roi_size[1] },
            .{ 0, roi_size[1] },
        };
    }
}

pub fn commit_working_roi(self: *@This(), imgpos: [2]f32, base_ratio: [2]f32) void {
    if (self.working_screen_roi) |roi| {
        self.roi[0] = V2.mul(V2.sub(roi[0], imgpos), base_ratio);
        self.roi[1] = V2.mul(V2.sub(roi[1], imgpos), base_ratio);
        self.roi[2] = V2.mul(V2.sub(roi[2], imgpos), base_ratio);
        self.roi[3] = V2.mul(V2.sub(roi[3], imgpos), base_ratio);
    }
}

pub fn update(self: *@This()) !void {
    _ = imgui.dockSpace.overViewport(.{});
    if (imgui.window.begin("ROI", .{})) {
        imgui.separator(.{ .label = "Operations" });
        _ = imgui.button("ROI Rotate", .{});
        if (imgui.item.isActive()) {
            const xdelta = imgui.mouse.getDragDelta(.{})[0];
            const speed = 0.0005;
            const angle = speed * xdelta;
            const cos = std.math.cos(angle);
            const sin = std.math.sin(angle);

            // pivot is center
            const pivot = V2.lerp(self.roi[0], self.roi[2], 0.5);
            self.roi[0] = V2.add(pivot, V2.rotate(V2.direction(pivot, self.roi[0]), cos, sin));
            self.roi[1] = V2.add(pivot, V2.rotate(V2.direction(pivot, self.roi[1]), cos, sin));
            self.roi[2] = V2.add(pivot, V2.rotate(V2.direction(pivot, self.roi[2]), cos, sin));
            self.roi[3] = V2.add(pivot, V2.rotate(V2.direction(pivot, self.roi[3]), cos, sin));
        }
        imgui.layout.sameLine(.{});
        if (imgui.button("Reset##Rotation", .{})) {
            // TODO: reset rotation
            std.debug.print("I don't know how to do this yet.", .{});
        }
        imgui.separator(.{ .label = "Aspect Ratio" });
        if (imgui.dragInt("Width", &self.aspect[0], .{})) {
            self.set_full_roi();
        }
        if (imgui.dragInt("Height", &self.aspect[1], .{})) {
            self.set_full_roi();
        }
        imgui.separator(.{});
        imgui.separator(.{ .label = "Point 1" });
        try imgui.text("X: {d}", .{self.roi[0][0]});
        try imgui.text("y: {d}", .{self.roi[0][1]});
        imgui.separator(.{ .label = "Point 2" });
        try imgui.text("X: {d}", .{self.roi[1][0]});
        try imgui.text("y: {d}", .{self.roi[1][1]});
        imgui.separator(.{ .label = "Point 3" });
        try imgui.text("X: {d}", .{self.roi[2][0]});
        try imgui.text("y: {d}", .{self.roi[2][1]});
        imgui.separator(.{ .label = "Point 4" });
        try imgui.text("X: {d}", .{self.roi[3][0]});
        try imgui.text("y: {d}", .{self.roi[3][1]});

        if (self.working_screen_roi) |roi| {
            imgui.separator(.{ .label = "Working ROI" });
            imgui.separator(.{ .label = "Point 1" });
            try imgui.text("X: {d}", .{roi[0][0]});
            try imgui.text("y: {d}", .{roi[0][1]});
            imgui.separator(.{ .label = "Point 2" });
            try imgui.text("X: {d}", .{roi[1][0]});
            try imgui.text("y: {d}", .{roi[1][1]});
            imgui.separator(.{ .label = "Point 3" });
            try imgui.text("X: {d}", .{roi[2][0]});
            try imgui.text("y: {d}", .{roi[2][1]});
            imgui.separator(.{ .label = "Point 4" });
            try imgui.text("X: {d}", .{roi[3][0]});
            try imgui.text("y: {d}", .{roi[3][1]});
        }
    }
    imgui.window.end();

    if (imgui.window.begin("Image", .{})) {
        if (self.image) |img| {
            const avail = imgui.cursor.getContentRegionAvail();
            const imgheightf: f32 = @floatFromInt(img.height);
            const imgwidthf: f32 = @floatFromInt(img.width);
            const imgscrsize = clamp_aspect(
                .{ imgwidthf, imgheightf },
                avail,
            );
            const base_ratio = V2.div(.{ imgwidthf, imgheightf }, imgscrsize);
            const imgpos = imgui.cursor.getScreenPos();

            imgui.window.getDrawList().addCallback(self.set_sampler, img.sampler);
            imgui.image(img.txid, .{ .size = imgscrsize });
            imgui.window.getDrawList().addResetCallback();

            const screen_roi: [4][2]f32 = .{
                .{
                    imgpos[0] + (imgscrsize[0] * self.roi[0][0] / imgwidthf),
                    imgpos[1] + (imgscrsize[1] * self.roi[0][1] / imgheightf),
                },
                .{
                    imgpos[0] + (imgscrsize[0] * self.roi[1][0] / imgwidthf),
                    imgpos[1] + (imgscrsize[1] * self.roi[1][1] / imgheightf),
                },
                .{
                    imgpos[0] + (imgscrsize[0] * self.roi[2][0] / imgwidthf),
                    imgpos[1] + (imgscrsize[1] * self.roi[2][1] / imgheightf),
                },
                .{
                    imgpos[0] + (imgscrsize[0] * self.roi[3][0] / imgwidthf),
                    imgpos[1] + (imgscrsize[1] * self.roi[3][1] / imgheightf),
                },
            };

            const mousepos = imgui.mouse.getPos();
            const mouse_roi = .{ V2.rel_scalar_project(
                V2.direction(screen_roi[0], mousepos),
                V2.direction(screen_roi[0], screen_roi[1]),
            ), V2.rel_scalar_project(
                V2.direction(screen_roi[0], mousepos),
                V2.direction(screen_roi[0], screen_roi[3]),
            ) };

            imgui.window.getDrawList().addCallback(self.set_diff_blender, null);
            const drawflags = imgui.window.getDrawList().getFlags();
            imgui.window.getDrawList().setFlags(.{ .antiAliasedLines = false });
            if (self.working_screen_roi) |roi| {
                imgui.window.getDrawList().addQuad(roi, 0xffffffff, .{});
            } else {
                imgui.window.getDrawList().addQuad(screen_roi, 0xffffffff, .{});
            }
            imgui.window.getDrawList().setFlags(drawflags);
            imgui.window.getDrawList().addResetCallback();

            // TODO: use a single big invisible button and handle everything
            // yourself. Imgui's square buttons are actually making it harder
            // than it needs to be, *I ASSUME*

            const nw_handle = blk: {
                // If the mouse is outside the region of this handle,
                // it may be near another handle.
                // We don't want this one interfering.
                if (mouse_roi[0] > 0.2 or mouse_roi[1] > 0.2) {
                    break :blk screen_roi[0];
                }
                const nw_n_handle = V2.lerp(
                    screen_roi[0],
                    screen_roi[1],
                    std.math.clamp(mouse_roi[0], 0, 0.2),
                );
                const nw_w_handle = V2.lerp(
                    screen_roi[0],
                    screen_roi[3],
                    std.math.clamp(mouse_roi[1], 0, 0.2),
                );
                const distcmp = V2.distSq(nw_n_handle, mousepos) - V2.distSq(nw_w_handle, mousepos);
                if (distcmp >= 0) {
                    break :blk nw_w_handle;
                } else {
                    break :blk nw_n_handle;
                }
            };
            imgui.cursor.setScreenPos(V2.add(nw_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoINWHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeNWSE);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeNWSE);
                }
                const mousedelta = imgui.mouse.getDragDelta(.{});
                const poc = screen_roi[2];
                const p0_delta = V2.project(
                    mousedelta,
                    V2.direction(screen_roi[0], poc),
                );
                const p3_delta = V2.project(
                    p0_delta,
                    V2.direction(screen_roi[3], poc),
                );
                const p1_delta = V2.project(
                    p0_delta,
                    V2.direction(screen_roi[1], poc),
                );
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[0] = V2.add(screen_roi[0], p0_delta);
                    self.working_screen_roi.?[1] = V2.add(screen_roi[1], p1_delta);
                    self.working_screen_roi.?[3] = V2.add(screen_roi[3], p3_delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }

            const ne_handle = blk: {
                // If the mouse is outside the region of this handle,
                // it may be near another handle.
                // We don't want this one interfering.
                if (mouse_roi[0] < 0.8 or mouse_roi[1] > 0.2) {
                    break :blk screen_roi[1];
                }
                const ne_n_handle = V2.lerp(
                    screen_roi[0],
                    screen_roi[1],
                    std.math.clamp(mouse_roi[0], 0.8, 1),
                );
                const ne_e_handle = V2.lerp(
                    screen_roi[1],
                    screen_roi[2],
                    std.math.clamp(mouse_roi[1], 0, 0.2),
                );
                const distcmp = V2.distSq(ne_n_handle, mousepos) - V2.distSq(ne_e_handle, mousepos);
                if (distcmp >= 0) {
                    break :blk ne_e_handle;
                } else {
                    break :blk ne_n_handle;
                }
            };
            imgui.cursor.setScreenPos(V2.add(ne_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoINEHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeNESW);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeNESW);
                }
                const mousedelta = imgui.mouse.getDragDelta(.{});
                const poc = screen_roi[3];
                const p1_delta = V2.project(
                    mousedelta,
                    V2.direction(screen_roi[1], poc),
                );
                const p2_delta = V2.project(
                    p1_delta,
                    V2.direction(screen_roi[2], poc),
                );
                const p0_delta = V2.project(
                    p1_delta,
                    V2.direction(screen_roi[0], poc),
                );
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[0] = V2.add(screen_roi[0], p0_delta);
                    self.working_screen_roi.?[1] = V2.add(screen_roi[1], p1_delta);
                    self.working_screen_roi.?[2] = V2.add(screen_roi[2], p2_delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }

            const se_handle = blk: {
                // If the mouse is outside the region of this handle,
                // it may be near another handle.
                // We don't want this one interfering.
                if (mouse_roi[0] < 0.8 or mouse_roi[1] < 0.8) {
                    break :blk screen_roi[2];
                }
                const se_s_handle = V2.lerp(
                    screen_roi[3],
                    screen_roi[2],
                    std.math.clamp(mouse_roi[0], 0.8, 1),
                );
                const se_e_handle = V2.lerp(
                    screen_roi[1],
                    screen_roi[2],
                    std.math.clamp(mouse_roi[1], 0.8, 1),
                );
                const distcmp = V2.distSq(se_s_handle, mousepos) - V2.distSq(se_e_handle, mousepos);
                if (distcmp >= 0) {
                    break :blk se_e_handle;
                } else {
                    break :blk se_s_handle;
                }
            };
            imgui.cursor.setScreenPos(V2.add(se_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoISEHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeNWSE);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeNWSE);
                }
                const mousedelta = imgui.mouse.getDragDelta(.{});
                const poc = screen_roi[0];
                const p2_delta = V2.project(
                    mousedelta,
                    V2.direction(screen_roi[2], poc),
                );
                const p3_delta = V2.project(
                    p2_delta,
                    V2.direction(screen_roi[3], poc),
                );
                const p1_delta = V2.project(
                    p2_delta,
                    V2.direction(screen_roi[1], poc),
                );
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[1] = V2.add(screen_roi[1], p1_delta);
                    self.working_screen_roi.?[2] = V2.add(screen_roi[2], p2_delta);
                    self.working_screen_roi.?[3] = V2.add(screen_roi[3], p3_delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }

            const sw_handle = blk: {
                // If the mouse is outside the region of this handle,
                // it may be near another handle.
                // We don't want this one interfering.
                if (mouse_roi[0] > 0.2 or mouse_roi[1] < 0.8) {
                    break :blk screen_roi[3];
                }
                const sw_s_handle = V2.lerp(
                    screen_roi[3],
                    screen_roi[2],
                    std.math.clamp(mouse_roi[0], 0, 0.2),
                );
                const sw_w_handle = V2.lerp(
                    screen_roi[0],
                    screen_roi[3],
                    std.math.clamp(mouse_roi[1], 0.8, 1),
                );
                const distcmp = V2.distSq(sw_s_handle, mousepos) - V2.distSq(sw_w_handle, mousepos);
                if (distcmp >= 0) {
                    break :blk sw_w_handle;
                } else {
                    break :blk sw_s_handle;
                }
            };
            imgui.cursor.setScreenPos(V2.add(sw_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoISWHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeNESW);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeNESW);
                }
                const mousedelta = imgui.mouse.getDragDelta(.{});
                const poc = screen_roi[1];
                const p3_delta = V2.project(
                    mousedelta,
                    V2.direction(screen_roi[3], poc),
                );
                const p0_delta = V2.project(
                    p3_delta,
                    V2.direction(screen_roi[0], poc),
                );
                const p2_delta = V2.project(
                    p3_delta,
                    V2.direction(screen_roi[2], poc),
                );
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[0] = V2.add(screen_roi[0], p0_delta);
                    self.working_screen_roi.?[2] = V2.add(screen_roi[2], p2_delta);
                    self.working_screen_roi.?[3] = V2.add(screen_roi[3], p3_delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }

            const w_handle = blk: {
                if (mouse_roi[1] <= 0.2 or mouse_roi[1] >= 0.8) {
                    break :blk V2.lerp(screen_roi[0], screen_roi[3], 0.5);
                }
                break :blk V2.lerp(
                    screen_roi[0],
                    screen_roi[3],
                    std.math.clamp(mouse_roi[1], 0.2, 0.8),
                );
            };
            imgui.cursor.setScreenPos(V2.add(w_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoIWHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeEW);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeEW);
                }
                const mousedelta = imgui.mouse.getDragDelta(.{});
                const poc = V2.lerp(screen_roi[1], screen_roi[2], 0.5);
                const e_delta = V2.project(
                    mousedelta,
                    V2.direction(screen_roi[0], screen_roi[1]),
                );
                const p0_delta = V2.unproject(
                    e_delta,
                    V2.direction(screen_roi[0], poc),
                );
                const p3_delta = V2.unproject(
                    e_delta,
                    V2.direction(screen_roi[3], poc),
                );
                const p1_delta = V2.project(
                    p0_delta,
                    V2.direction(screen_roi[1], poc),
                );
                const p2_delta = V2.project(
                    p3_delta,
                    V2.direction(screen_roi[2], poc),
                );
                if (imgui.window.begin("ROI", .{})) {
                    imgui.separator(.{ .label = "Deltas" });
                    try imgui.text("E delta: {any}", .{e_delta});
                    try imgui.text("E delta dot P0-POC: {any}", .{V2.dot(
                        e_delta,
                        V2.direction(screen_roi[0], poc),
                    )});
                    try imgui.text("P0 delta: {any}", .{p0_delta});
                    try imgui.text("P1 delta: {any}", .{p1_delta});
                    try imgui.text("P2 delta: {any}", .{p2_delta});
                    try imgui.text("P3 delta: {any}", .{p3_delta});
                }
                imgui.window.end();
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[0] = V2.add(screen_roi[0], p0_delta);
                    self.working_screen_roi.?[1] = V2.add(screen_roi[1], p1_delta);
                    self.working_screen_roi.?[2] = V2.add(screen_roi[2], p2_delta);
                    self.working_screen_roi.?[3] = V2.add(screen_roi[3], p3_delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }

            const e_handle = blk: {
                if (mouse_roi[1] <= 0.2 or mouse_roi[1] >= 0.8) {
                    break :blk V2.lerp(screen_roi[1], screen_roi[2], 0.5);
                }
                break :blk V2.lerp(
                    screen_roi[1],
                    screen_roi[2],
                    std.math.clamp(mouse_roi[1], 0.2, 0.8),
                );
            };
            imgui.cursor.setScreenPos(V2.add(e_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoIEHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeEW);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeEW);
                }
                const mousedelta = imgui.mouse.getDragDelta(.{});
                const poc = V2.lerp(screen_roi[0], screen_roi[3], 0.5);
                const w_delta = V2.project(
                    mousedelta,
                    V2.direction(screen_roi[0], screen_roi[1]),
                );
                const p1_delta = V2.unproject(
                    w_delta,
                    V2.direction(screen_roi[1], poc),
                );
                const p2_delta = V2.unproject(
                    w_delta,
                    V2.direction(screen_roi[2], poc),
                );
                const p0_delta = V2.project(
                    p1_delta,
                    V2.direction(screen_roi[0], poc),
                );
                const p3_delta = V2.project(
                    p2_delta,
                    V2.direction(screen_roi[3], poc),
                );
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[0] = V2.add(screen_roi[0], p0_delta);
                    self.working_screen_roi.?[1] = V2.add(screen_roi[1], p1_delta);
                    self.working_screen_roi.?[2] = V2.add(screen_roi[2], p2_delta);
                    self.working_screen_roi.?[3] = V2.add(screen_roi[3], p3_delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }

            const n_handle = blk: {
                if (mouse_roi[0] <= 0.2 or mouse_roi[0] >= 0.8) {
                    break :blk V2.lerp(screen_roi[0], screen_roi[1], 0.5);
                }
                break :blk V2.lerp(
                    screen_roi[0],
                    screen_roi[1],
                    std.math.clamp(mouse_roi[0], 0.2, 0.8),
                );
            };
            imgui.cursor.setScreenPos(V2.add(n_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoINHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeNS);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeNS);
                }
                const mousedelta = imgui.mouse.getDragDelta(.{});
                const poc = V2.lerp(screen_roi[3], screen_roi[2], 0.5);
                const s_delta = V2.project(
                    mousedelta,
                    V2.direction(screen_roi[0], screen_roi[3]),
                );
                const p0_delta = V2.unproject(
                    s_delta,
                    V2.direction(screen_roi[0], poc),
                );
                const p1_delta = V2.unproject(
                    s_delta,
                    V2.direction(screen_roi[1], poc),
                );
                const p3_delta = V2.project(
                    p0_delta,
                    V2.direction(screen_roi[3], poc),
                );
                const p2_delta = V2.project(
                    p1_delta,
                    V2.direction(screen_roi[2], poc),
                );
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[0] = V2.add(screen_roi[0], p0_delta);
                    self.working_screen_roi.?[1] = V2.add(screen_roi[1], p1_delta);
                    self.working_screen_roi.?[2] = V2.add(screen_roi[2], p2_delta);
                    self.working_screen_roi.?[3] = V2.add(screen_roi[3], p3_delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }

            const s_handle = blk: {
                if (mouse_roi[0] <= 0.2 or mouse_roi[0] >= 0.8) {
                    break :blk V2.lerp(screen_roi[3], screen_roi[2], 0.5);
                }
                break :blk V2.lerp(
                    screen_roi[3],
                    screen_roi[2],
                    std.math.clamp(mouse_roi[0], 0.2, 0.8),
                );
            };
            imgui.cursor.setScreenPos(V2.add(s_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoISHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeNS);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeNS);
                }
                const mousedelta = imgui.mouse.getDragDelta(.{});
                const poc = V2.lerp(screen_roi[0], screen_roi[1], 0.5);
                const n_delta = V2.project(
                    mousedelta,
                    V2.direction(screen_roi[3], screen_roi[0]),
                );
                const p3_delta = V2.unproject(
                    n_delta,
                    V2.direction(screen_roi[3], poc),
                );
                const p2_delta = V2.unproject(
                    n_delta,
                    V2.direction(screen_roi[2], poc),
                );
                const p0_delta = V2.project(
                    p3_delta,
                    V2.direction(screen_roi[0], poc),
                );
                const p1_delta = V2.project(
                    p2_delta,
                    V2.direction(screen_roi[1], poc),
                );
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[0] = V2.add(screen_roi[0], p0_delta);
                    self.working_screen_roi.?[1] = V2.add(screen_roi[1], p1_delta);
                    self.working_screen_roi.?[2] = V2.add(screen_roi[2], p2_delta);
                    self.working_screen_roi.?[3] = V2.add(screen_roi[3], p3_delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }

            const move_handle = blk: {
                if (mouse_roi[0] <= 0.2 or mouse_roi[0] >= 0.8 or
                    mouse_roi[1] <= 0.2 or mouse_roi[1] >= 0.8)
                {
                    break :blk V2.lerp(screen_roi[0], screen_roi[2], 0.5);
                }
                break :blk mousepos;
            };
            imgui.cursor.setScreenPos(V2.add(move_handle, @splat(-10)));
            _ = imgui.invisibleButton("RoIMHandle", .{ 20, 20 }, .{});
            if (imgui.item.isActivated()) {
                self.working_screen_roi = screen_roi;
            }
            if (imgui.item.isDeactivated()) {
                self.commit_working_roi(imgpos, base_ratio);
                self.working_screen_roi = null;
            }
            if (imgui.item.isHovered(.{})) {
                // TODO: adapt pointer orientation to rect rotation
                imgui.mouse.setPointer(.resizeAll);
            }
            if (imgui.item.isActive()) {
                if (self.working_screen_roi) |_| {
                    imgui.mouse.setPointer(.resizeAll);
                }
                const delta = imgui.mouse.getDragDelta(.{});
                if (self.working_screen_roi) |_| {
                    self.working_screen_roi.?[0] = V2.add(screen_roi[0], delta);
                    self.working_screen_roi.?[1] = V2.add(screen_roi[1], delta);
                    self.working_screen_roi.?[2] = V2.add(screen_roi[2], delta);
                    self.working_screen_roi.?[3] = V2.add(screen_roi[3], delta);
                }
                if (imgui.mouse.isClicked(.right, .{})) {
                    self.working_screen_roi = null;
                }
            }
        }
    }
    imgui.window.end();

    if (imgui.window.begin("Preview", .{})) {
        if (self.image) |img| {
            const avail = imgui.cursor.getContentRegionAvail();
            const imgscrsize = clamp_aspect(
                .{ @floatFromInt(self.aspect[0]), @floatFromInt(self.aspect[1]) },
                avail,
            );

            const imgpos = imgui.cursor.getScreenPos();
            imgui.window.getDrawList().addCallback(self.set_sampler, img.sampler);
            imgui.window.getDrawList().addImageQuad(img.txid, .{
                .{ imgpos[0], imgpos[1] },
                .{
                    imgpos[0] + imgscrsize[0],
                    imgpos[1],
                },
                .{
                    imgpos[0] + imgscrsize[0],
                    imgpos[1] + imgscrsize[1],
                },
                .{
                    imgpos[0],
                    imgpos[1] + imgscrsize[1],
                },
            }, .{
                .{
                    self.roi[0][0] / @as(f32, @floatFromInt(img.width)),
                    self.roi[0][1] / @as(f32, @floatFromInt(img.height)),
                },
                .{
                    self.roi[1][0] / @as(f32, @floatFromInt(img.width)),
                    self.roi[1][1] / @as(f32, @floatFromInt(img.height)),
                },
                .{
                    self.roi[2][0] / @as(f32, @floatFromInt(img.width)),
                    self.roi[2][1] / @as(f32, @floatFromInt(img.height)),
                },
                .{
                    self.roi[3][0] / @as(f32, @floatFromInt(img.width)),
                    self.roi[3][1] / @as(f32, @floatFromInt(img.height)),
                },
            }, .{});
            imgui.window.getDrawList().addResetCallback();
        }
    }
    imgui.window.end();
}

fn white_rect(at: [2]f32) void {
    imgui.window.getDrawList().addRect(
        .{ at[0] - 5, at[1] - 5 },
        .{ at[0] + 5, at[1] + 5 },
        0xffffffff,
        .{},
    );
}

pub const Image = struct {
    txid: imgui.TextureID,
    width: u32,
    height: u32,
    sampler: ?*anyopaque,
};
