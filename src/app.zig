const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const V2 = @import("V2.zig");

image: ?Image,
aspect: [2]u32,
roi: [4][2]f32,
working_roi: ?[4][2]f32,
set_sampler: imgui.draw.Callback,
set_diff_blender: imgui.draw.Callback,
roi_op: ?Handle = null,

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
        .working_roi = null,
        .set_sampler = set_sampler,
        .set_diff_blender = set_diff_blender,
    };
}

/// Get the sizes of a rectangle of the given aspect ratio,
/// either as wide as `max_size[0]`, or as tall as `max_size[1]`
fn fit_aspect(aspect: [2]f32, max_size: [2]f32) [2]f32 {
    const maxwf: f32, const maxhf: f32 = max_size;
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
        const roi_size = fit_aspect(
            .{ @floatFromInt(self.aspect[0]), @floatFromInt(self.aspect[1]) },
            img.dims,
        );
        self.roi = .{
            .{ 0, 0 },
            .{ roi_size[0], 0 },
            .{ roi_size[0], roi_size[1] },
            .{ 0, roi_size[1] },
        };
    }
}

pub fn commit_working_roi(self: *@This()) void {
    if (self.working_roi) |roi| {
        self.roi = roi;
    }
}

pub fn update(self: *@This()) !void {
    _ = imgui.dockSpace.overViewport(.{});
    if (imgui.window.begin("ROI", .{})) {
        imgui.separator(.{ .label = "Operations" });
        if (imgui.button("Reset rotation", .{})) {
            const center = V2.lerp(self.roi[0], self.roi[2], 0.5);
            const height = V2.dist(self.roi[0], self.roi[3]);
            const aspwf: f32, const asphf: f32 = .{
                @floatFromInt(self.aspect[0]),
                @floatFromInt(self.aspect[1]),
            };
            const width = height * (aspwf / asphf);
            self.roi[0] = V2.add(center, .{ -width * 0.5, -height * 0.5 });
            self.roi[1] = V2.add(center, .{ width * 0.5, -height * 0.5 });
            self.roi[2] = V2.add(center, .{ width * 0.5, height * 0.5 });
            self.roi[3] = V2.add(center, .{ -width * 0.5, height * 0.5 });
        }
        imgui.separator(.{ .label = "Aspect Ratio" });
        if (imgui.dragInt("Width", &self.aspect[0], .{})) {
            self.set_full_roi();
        }
        if (imgui.dragInt("Height", &self.aspect[1], .{})) {
            self.set_full_roi();
        }
        try imgui.text(
            "Ratio: {d}",
            .{@as(f32, @floatFromInt(self.aspect[0])) / @as(f32, @floatFromInt(self.aspect[1]))},
        );
        imgui.separator(.{});
        imgui.separator(.{ .label = "Actual ROI" });
        const roi_width = V2.dist(self.roi[0], self.roi[1]);
        const roi_height = V2.dist(self.roi[0], self.roi[3]);
        try imgui.text("Width: {d}", .{roi_width});
        try imgui.text("Height: {d}", .{roi_height});
        try imgui.text("Ratio: {d}", .{roi_width / roi_height});
        const roi_width_int = std.math.round(roi_width);
        const roi_height_int = std.math.round(roi_height);
        try imgui.text("Width (Rounded): {d}", .{roi_width_int});
        try imgui.text("Height (Rounded): {d}", .{roi_height_int});
        try imgui.text("Ratio (Rounded): {d}", .{roi_width_int / roi_height_int});
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

        if (self.working_roi) |roi| {
            imgui.separator(.{});
            imgui.separator(.{ .label = "Working ROI" });
            const work_roi_width = V2.dist(roi[0], roi[1]);
            const work_roi_height = V2.dist(roi[0], roi[3]);
            try imgui.text("Width: {d}", .{work_roi_width});
            try imgui.text("Height: {d}", .{work_roi_height});
            try imgui.text("Ratio: {d}", .{work_roi_width / work_roi_height});
            const work_roi_width_int = std.math.round(work_roi_width);
            const work_roi_height_int = std.math.round(work_roi_height);
            try imgui.text("Width (Rounded): {d}", .{work_roi_width_int});
            try imgui.text("Height (Rounded): {d}", .{work_roi_height_int});
            try imgui.text("Ratio (Rounded): {d}", .{work_roi_width_int / work_roi_height_int});
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
        try self.single_button_image();
    }
    imgui.window.end();

    if (imgui.window.begin("Preview", .{})) {
        if (self.image) |img| {
            const avail = imgui.cursor.getContentRegionAvail();
            const imgscrsize = fit_aspect(
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
            }, if (self.working_roi) |roi| .{
                V2.div(roi[0], img.dims),
                V2.div(roi[1], img.dims),
                V2.div(roi[2], img.dims),
                V2.div(roi[3], img.dims),
            } else .{
                V2.div(self.roi[0], img.dims),
                V2.div(self.roi[1], img.dims),
                V2.div(self.roi[2], img.dims),
                V2.div(self.roi[3], img.dims),
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
    dims: [2]f32,
    sampler: ?*anyopaque,
};

fn single_button_image(self: *@This()) !void {
    if (self.image) |img| {
        const avail = imgui.cursor.getContentRegionAvail();
        const img_screen_size = fit_aspect(img.dims, avail);
        const imgpos = imgui.cursor.getScreenPos();

        imgui.window.getDrawList().addCallback(self.set_sampler, img.sampler);
        imgui.image(img.txid, .{ .size = img_screen_size });
        imgui.window.getDrawList().addResetCallback();

        const img_to_screen_scale = V2.div(img_screen_size, img.dims);
        const screen_to_img_scale = V2.div(img.dims, img_screen_size);
        const screen_roi: [4][2]f32 = .{
            V2.add(imgpos, V2.mul(self.roi[0], img_to_screen_scale)),
            V2.add(imgpos, V2.mul(self.roi[1], img_to_screen_scale)),
            V2.add(imgpos, V2.mul(self.roi[2], img_to_screen_scale)),
            V2.add(imgpos, V2.mul(self.roi[3], img_to_screen_scale)),
        };
        const screen_roi_size: [2]f32 = .{
            V2.len(V2.direction(screen_roi[0], screen_roi[1])),
            V2.len(V2.direction(screen_roi[0], screen_roi[3])),
        };

        imgui.window.getDrawList().addCallback(self.set_diff_blender, null);
        const drawflags = imgui.window.getDrawList().getFlags();
        imgui.window.getDrawList().setFlags(.{ .antiAliasedLines = false });
        if (self.working_roi) |roi| {
            const working_screen_roi: [4][2]f32 = .{
                V2.add(imgpos, V2.mul(roi[0], img_to_screen_scale)),
                V2.add(imgpos, V2.mul(roi[1], img_to_screen_scale)),
                V2.add(imgpos, V2.mul(roi[2], img_to_screen_scale)),
                V2.add(imgpos, V2.mul(roi[3], img_to_screen_scale)),
            };
            imgui.window.getDrawList().addQuad(working_screen_roi, 0xffffffff, .{});
        } else {
            imgui.window.getDrawList().addQuad(screen_roi, 0xffffffff, .{});
        }
        imgui.window.getDrawList().setFlags(drawflags);
        imgui.window.getDrawList().addResetCallback();

        imgui.cursor.setScreenPos(imgpos);
        _ = imgui.invisibleButton("Image ROI manipulation", img_screen_size, .{});

        const mousepos = imgui.mouse.getPos();
        if (imgui.item.isActivated()) {
            self.working_roi = self.roi;
        }
        if (imgui.item.isDeactivated()) {
            self.commit_working_roi();
            self.working_roi = null;
        }
        if (imgui.item.isHovered(.{}) and self.working_roi == null) {
            const mouse_roi = .{ V2.rel_scalar_project(
                V2.direction(screen_roi[0], mousepos),
                V2.unit(V2.direction(screen_roi[0], screen_roi[1])),
            ), V2.rel_scalar_project(
                V2.direction(screen_roi[0], mousepos),
                V2.unit(V2.direction(screen_roi[0], screen_roi[3])),
            ) };
            const mouse_roi_uv = .{ std.math.clamp(V2.rel_scalar_project(
                V2.direction(screen_roi[0], mousepos),
                V2.direction(screen_roi[0], screen_roi[1]),
            ), 0, 1), std.math.clamp(V2.rel_scalar_project(
                V2.direction(screen_roi[0], mousepos),
                V2.direction(screen_roi[0], screen_roi[3]),
            ), 0, 1) };

            const ew_region: Region = blk: {
                if (mouse_roi[0] < -10) {
                    break :blk .out;
                } else if (mouse_roi[0] < 10) {
                    break :blk .near_edge;
                } else if (mouse_roi_uv[0] < 0.2) {
                    break :blk .near;
                } else if (mouse_roi_uv[0] < 0.8) {
                    break :blk .in;
                } else if (mouse_roi[0] < screen_roi_size[0] - 10) {
                    break :blk .far;
                } else if (mouse_roi[0] < screen_roi_size[0] + 10) {
                    break :blk .far_edge;
                } else {
                    break :blk .out;
                }
            };

            const ns_region: Region = blk: {
                if (mouse_roi[1] < -10) {
                    break :blk .out;
                } else if (mouse_roi[1] < 10) {
                    break :blk .near_edge;
                } else if (mouse_roi_uv[1] < 0.2) {
                    break :blk .near;
                } else if (mouse_roi_uv[1] < 0.8) {
                    break :blk .in;
                } else if (mouse_roi[1] < screen_roi_size[1] - 10) {
                    break :blk .far;
                } else if (mouse_roi[1] < screen_roi_size[1] + 10) {
                    break :blk .far_edge;
                } else {
                    break :blk .out;
                }
            };

            self.roi_op = handle_table.get(ew_region).get(ns_region);
            imgui.mouse.setPointer(switch (self.roi_op.?) {
                .rot => .hand,
                .nw, .se => .resizeNWSE,
                .ne, .sw => .resizeNESW,
                .e, .w => .resizeEW,
                .n, .s => .resizeNS,
                .mov => .resizeAll,
            });
        }
        if (imgui.item.isActive()) {
            const mouse_delta = imgui.mouse.getDelta();
            const mouse_delta_img = V2.mul(mouse_delta, screen_to_img_scale);

            if (self.roi_op) |op| switch (op) {
                .nw => {
                    self.scale_corner_handle(mouse_delta_img, 0);
                },
                .ne => {
                    self.scale_corner_handle(mouse_delta_img, 1);
                },
                .se => {
                    self.scale_corner_handle(mouse_delta_img, 2);
                },
                .sw => {
                    self.scale_corner_handle(mouse_delta_img, 3);
                },
                .n => {
                    self.scale_edge_handle(mouse_delta_img, 0);
                },
                .e => {
                    self.scale_edge_handle(mouse_delta_img, 1);
                },
                .s => {
                    self.scale_edge_handle(mouse_delta_img, 2);
                },
                .w => {
                    self.scale_edge_handle(mouse_delta_img, 3);
                },
                .mov => {
                    self.move_op(mouse_delta_img);
                },
                .rot => {
                    const old_pos = V2.sub(mousepos, mouse_delta);
                    const pivot = V2.lerp(screen_roi[0], screen_roi[2], 0.5);
                    // NOTE: our Y is pointing down-screen, so the angle
                    // direction has to be reversed: CCW positive in a (+X,+Y)
                    // base is CW positive in a (+X,-Y) base.
                    const angle_delta = -V2.angle(
                        V2.direction(pivot, old_pos),
                        V2.direction(pivot, mousepos),
                    );
                    self.rot_op(angle_delta, img.dims);
                },
            };
            if (imgui.mouse.isClicked(.right, .{})) {
                self.working_roi = null;
            }
        }
    }
}

fn bound_check_point_move(self: *@This(), point: [2]f32, move: [2]f32) f32 {
    var t_delta: f32 = 1;
    if (V2.vec_bound_intersect(
        point,
        move,
        .x,
        .pos,
        0,
    )) |x0|
        if (x0 < t_delta) {
            t_delta = x0;
        };
    if (V2.vec_bound_intersect(
        point,
        move,
        .y,
        .pos,
        0,
    )) |y0|
        if (y0 < t_delta) {
            t_delta = y0;
        };
    if (V2.vec_bound_intersect(
        point,
        move,
        .x,
        .neg,
        self.image.?.dims[0],
    )) |x1|
        if (x1 < t_delta) {
            t_delta = x1;
        };
    if (V2.vec_bound_intersect(
        point,
        move,
        .y,
        .neg,
        self.image.?.dims[1],
    )) |y1|
        if (y1 < t_delta) {
            t_delta = y1;
        };
    return t_delta;
}

fn scale_corner_handle(self: *@This(), init_delta: [2]f32, corner_idx: usize) void {
    // These renamings make it easier to reason about: we treat everything as it
    // if was using the indices for the North West corner (0).
    const p0 = corner_idx & 3;
    const p1 = (corner_idx + 1) & 3;
    const p2 = (corner_idx + 2) & 3;
    const p3 = (corner_idx + 3) & 3;
    if (self.working_roi) |roi| {
        const poc = roi[p2];
        var corner_delta = V2.project(
            init_delta,
            V2.direction(roi[p0], poc),
        );
        var propag_delta_1 = V2.project(
            corner_delta,
            V2.direction(roi[p1], poc),
        );
        var propag_delta_2 = V2.project(
            corner_delta,
            V2.direction(roi[p3], poc),
        );
        const t = @min(
            self.bound_check_point_move(roi[p0], corner_delta),
            self.bound_check_point_move(roi[p1], propag_delta_1),
            self.bound_check_point_move(roi[p3], propag_delta_2),
        );
        {
            corner_delta = V2.scale(corner_delta, t);
            propag_delta_1 = V2.scale(propag_delta_1, t);
            propag_delta_2 = V2.scale(propag_delta_2, t);
        }
        self.working_roi.?[p0] = V2.add(roi[p0], corner_delta);
        self.working_roi.?[p1] = V2.add(roi[p1], propag_delta_1);
        self.working_roi.?[p3] = V2.add(roi[p3], propag_delta_2);
    }
}

/// edge is identified by the index of its first vertex. And edge will always be
/// (i, i+1), where 'i' wraps within [0,3]
fn scale_edge_handle(self: *@This(), init_delta: [2]f32, edge: usize) void {
    // These renamings make it easier to reason about: we treat everything as it
    // if was using the indices for the North edge (0,1).
    const p0 = (edge & 3);
    const p1 = ((edge + 1) & 3);
    const p2 = ((edge + 2) & 3);
    const p3 = ((edge + 3) & 3);
    if (self.working_roi) |roi| {
        const poc = V2.lerp(roi[p2], roi[p3], 0.5);
        const normal_delta = V2.project(
            init_delta,
            V2.direction(roi[p0], roi[p3]),
        );
        var p0_delta = V2.unproject(
            normal_delta,
            V2.direction(roi[p0], poc),
        );
        var p1_delta = V2.unproject(
            normal_delta,
            V2.direction(roi[p1], poc),
        );
        var p3_delta = V2.project(
            p0_delta,
            V2.direction(roi[p3], poc),
        );
        var p2_delta = V2.project(
            p1_delta,
            V2.direction(roi[p2], poc),
        );
        const t = @min(
            self.bound_check_point_move(roi[p0], p0_delta),
            self.bound_check_point_move(roi[p1], p1_delta),
            self.bound_check_point_move(roi[p2], p2_delta),
            self.bound_check_point_move(roi[p3], p3_delta),
        );
        {
            p0_delta = V2.scale(p0_delta, t);
            p1_delta = V2.scale(p1_delta, t);
            p2_delta = V2.scale(p2_delta, t);
            p3_delta = V2.scale(p3_delta, t);
        }
        self.working_roi.?[p0] = V2.add(roi[p0], p0_delta);
        self.working_roi.?[p1] = V2.add(roi[p1], p1_delta);
        self.working_roi.?[p2] = V2.add(roi[p2], p2_delta);
        self.working_roi.?[p3] = V2.add(roi[p3], p3_delta);
    }
}

fn move_op(self: *@This(), init_delta: [2]f32) void {
    if (self.working_roi) |roi| {
        var working_bb: [2][2]f32 = .{ .{
            @min(roi[0][0], roi[1][0], roi[2][0], roi[3][0]),
            @min(roi[0][1], roi[1][1], roi[2][1], roi[3][1]),
        }, .{
            @max(roi[0][0], roi[1][0], roi[2][0], roi[3][0]),
            @max(roi[0][1], roi[1][1], roi[2][1], roi[3][1]),
        } };

        var iter_delta = init_delta;
        var final_delta: [2]f32 = .{ 0, 0 };
        for (0..2) |_| {
            var t_delta: f32 = 1;
            var hit: ?enum { x, y } = null;

            if (V2.vec_bound_intersect(working_bb[0], iter_delta, .x, .pos, 0)) |x0|
                if (x0 < t_delta) {
                    hit = .x;
                    t_delta = x0;
                };
            if (V2.vec_bound_intersect(working_bb[0], iter_delta, .y, .pos, 0)) |y0|
                if (y0 < t_delta) {
                    hit = .y;
                    t_delta = y0;
                };
            if (V2.vec_bound_intersect(working_bb[1], iter_delta, .x, .neg, self.image.?.dims[0])) |x1|
                if (x1 < t_delta) {
                    hit = .x;
                    t_delta = x1;
                };
            if (V2.vec_bound_intersect(
                working_bb[1],
                iter_delta,
                .y,
                .neg,
                self.image.?.dims[1],
            )) |y1|
                if (y1 < t_delta) {
                    hit = .y;
                    t_delta = y1;
                };

            const delta_hit = V2.scale(iter_delta, t_delta);
            final_delta = V2.add(final_delta, delta_hit);
            working_bb[0] = V2.add(working_bb[0], delta_hit);
            working_bb[1] = V2.add(working_bb[1], delta_hit);

            if (t_delta < 1) {
                switch (hit.?) {
                    .x => {
                        // glide along y
                        iter_delta = V2.mul(iter_delta, .{ 0, 1 - t_delta });
                    },
                    .y => {
                        // glide along x
                        iter_delta = V2.mul(iter_delta, .{ 1 - t_delta, 0 });
                    },
                }
            } else {
                break;
            }
        }
        self.working_roi.?[0] = V2.add(roi[0], final_delta);
        self.working_roi.?[1] = V2.add(roi[1], final_delta);
        self.working_roi.?[2] = V2.add(roi[2], final_delta);
        self.working_roi.?[3] = V2.add(roi[3], final_delta);
    }
}

fn rot_op(self: *@This(), init_angle: f32, bounds: [2]f32) void {
    if (std.math.approxEqAbs(f32, init_angle, 0, std.math.floatEps(f32))) {
        // no angle, no rotation
        return;
    }
    if (self.working_roi) |roi| {
        const pivot = V2.lerp(self.roi[0], self.roi[2], 0.5);
        // Positive: CW
        // Negative: CCW
        const angle_p0 = -V2.angleAbs(V2.direction(pivot, roi[0]));
        const angle_p1 = -V2.angleAbs(V2.direction(pivot, roi[1]));
        const angle_p2 = -V2.angleAbs(V2.direction(pivot, roi[2]));
        const angle_p3 = -V2.angleAbs(V2.direction(pivot, roi[3]));
        const radiusSq = V2.distSq(pivot, roi[2]);

        const intersect_left_sq = radiusSq - (pivot[0] * pivot[0]);
        const intersect_right_sq = radiusSq - ((bounds[0] - pivot[0]) * (bounds[0] - pivot[0]));
        const intersect_top_sq = radiusSq - (pivot[1] * pivot[1]);
        const intersect_bottom_sq = radiusSq - ((bounds[1] - pivot[1]) * (bounds[1] - pivot[1]));

        // We want the minimum absolute
        const angle_delta_sign = std.math.sign(init_angle);
        var final_angle = init_angle * angle_delta_sign;
        if (intersect_left_sq > 0) {
            const rel_y = std.math.sqrt(intersect_left_sq) * angle_delta_sign;
            const hit = .{ 0, pivot[1] + rel_y };
            const hit_angle_aligned = -V2.angleAbs(V2.direction(pivot, hit));
            const p0_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p0) * angle_delta_sign);
            const p1_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p1) * angle_delta_sign);
            const p2_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p2) * angle_delta_sign);
            const p3_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p3) * angle_delta_sign);
            final_angle = @min(
                final_angle,
                p0_hit_rel_angle,
                p1_hit_rel_angle,
                p2_hit_rel_angle,
                p3_hit_rel_angle,
            );
        }
        if (intersect_right_sq > 0) {
            const rel_y = std.math.sqrt(intersect_right_sq) * -angle_delta_sign;
            const hit = .{ bounds[0], pivot[1] + rel_y };
            const hit_angle_aligned = -V2.angleAbs(V2.direction(pivot, hit));
            const p0_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p0) * angle_delta_sign);
            const p1_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p1) * angle_delta_sign);
            const p2_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p2) * angle_delta_sign);
            const p3_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p3) * angle_delta_sign);
            final_angle = @min(
                final_angle,
                p0_hit_rel_angle,
                p1_hit_rel_angle,
                p2_hit_rel_angle,
                p3_hit_rel_angle,
            );
        }
        if (intersect_top_sq > 0) {
            const rel_x = std.math.sqrt(intersect_right_sq) * -angle_delta_sign;
            const hit = .{ pivot[0] + rel_x, 0 };
            const hit_angle_aligned = -V2.angleAbs(V2.direction(pivot, hit));
            const p0_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p0) * angle_delta_sign);
            const p1_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p1) * angle_delta_sign);
            const p2_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p2) * angle_delta_sign);
            const p3_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p3) * angle_delta_sign);
            final_angle = @min(
                final_angle,
                p0_hit_rel_angle,
                p1_hit_rel_angle,
                p2_hit_rel_angle,
                p3_hit_rel_angle,
            );
        }
        if (intersect_bottom_sq > 0) {
            const rel_x = std.math.sqrt(intersect_right_sq) * angle_delta_sign;
            const hit = .{ pivot[0] + rel_x, bounds[1] };
            const hit_angle_aligned = -V2.angleAbs(V2.direction(pivot, hit));
            const p0_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p0) * angle_delta_sign);
            const p1_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p1) * angle_delta_sign);
            const p2_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p2) * angle_delta_sign);
            const p3_hit_rel_angle = positive(approxDiff(hit_angle_aligned, angle_p3) * angle_delta_sign);
            final_angle = @min(
                final_angle,
                p0_hit_rel_angle,
                p1_hit_rel_angle,
                p2_hit_rel_angle,
                p3_hit_rel_angle,
            );
        }

        // We restore the sign.
        final_angle *= angle_delta_sign;

        const cos = std.math.cos(final_angle);
        const sin = std.math.sin(final_angle);
        self.working_roi.?[0] = V2.add(pivot, V2.rotate(V2.direction(pivot, roi[0]), cos, sin));
        self.working_roi.?[1] = V2.add(pivot, V2.rotate(V2.direction(pivot, roi[1]), cos, sin));
        self.working_roi.?[2] = V2.add(pivot, V2.rotate(V2.direction(pivot, roi[2]), cos, sin));
        self.working_roi.?[3] = V2.add(pivot, V2.rotate(V2.direction(pivot, roi[3]), cos, sin));
    }
}

/// Gets you `a - b`, but if the result is close enough to zero, we snap it.
fn approxDiff(a: f32, b: f32) f32 {
    var raw_diff = a - b;
    if (std.math.approxEqAbs(f32, raw_diff, 0, 1e-5))
        raw_diff = 0;
    return raw_diff;
}

/// If given a negative number, gives you +inf back.
fn positive(f: f32) f32 {
    return if (f < 0) std.math.inf(f32) else f;
}

const Region = enum {
    out,
    near_edge,
    near,
    in,
    far,
    far_edge,
};

const handle_table: std.enums.EnumArray(Region, std.enums.EnumArray(Region, Handle)) = .init(.{
    .out = .initFill(.rot),
    .near_edge = .init(.{
        .out = .rot,
        .near_edge = .nw,
        .near = .nw,
        .in = .w,
        .far = .sw,
        .far_edge = .sw,
    }),
    .near = .init(.{
        .out = .rot,
        .near_edge = .nw,
        .near = .mov,
        .in = .mov,
        .far = .mov,
        .far_edge = .sw,
    }),
    .in = .init(.{
        .out = .rot,
        .near_edge = .n,
        .near = .mov,
        .in = .mov,
        .far = .mov,
        .far_edge = .s,
    }),
    .far = .init(.{
        .out = .rot,
        .near_edge = .ne,
        .near = .mov,
        .in = .mov,
        .far = .mov,
        .far_edge = .se,
    }),
    .far_edge = .init(.{
        .out = .rot,
        .near_edge = .ne,
        .near = .ne,
        .in = .e,
        .far = .se,
        .far_edge = .se,
    }),
});

const Handle = enum { rot, nw, ne, se, sw, n, s, e, w, mov };
