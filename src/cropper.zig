const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const vec = @import("vec.zig");

const Image = @import("image.zig");

/// The source image of this wallpaper
image: Image,
/// The aspect of this wallpaper
aspect: vec.V2,
/// The minimum size of this wallpaper
min_size: vec.V2,
/// The crop RoI being edited
roi: vec.Quad,
/// The 4 available zoomed regions
zooms: [4]struct {
    show: bool,
    area: vec.Rect,
},
/// Non-null when actually performing an operation
working_roi: ?vec.Quad,
/// Non-null when hovering a valid handle, or performing its operation
roi_op: ?Handle,
/// If non-null, index of the zoom region being edited
edit_mode: ?usize,

pub fn init(image: Image, aspect: vec.V2, min_size: vec.V2) @This() {
    var self: @This() = .{
        .image = image,
        .aspect = aspect,
        .min_size = min_size,
        .roi = @splat(0),
        .zooms = .{
            .{ .show = false, .area = .{ 0, 0, 64, 64 } },
            .{ .show = false, .area = .{ 0, 0, 64, 64 } },
            .{ .show = false, .area = .{ 0, 0, 64, 64 } },
            .{ .show = false, .area = .{ 0, 0, 64, 64 } },
        },
        .working_roi = null,
        .roi_op = null,
        .edit_mode = null,
    };
    self.reset_roi();
    return self;
}

fn reset_roi(self: *@This()) void {
    const roi_size = vec.fit(
        self.aspect,
        self.image.dims,
    );
    const img_center = self.image.dims * vec.v2(0.5);
    const roi_center = roi_size * vec.v2(0.5);
    const top_left = img_center - roi_center;
    const bottom_right = img_center + roi_center;
    self.roi = vec.quad.fromRectPoints(top_left, bottom_right);
}

fn reset_rotation(self: *@This()) void {
    const center = vec.quad.center(self.roi);
    const height = vec.quad.height(self.roi);
    const aspw, const asph = self.aspect;
    const width = height * (aspw / asph);
    self.roi = vec.quad.fromCenterAndSize(center, .{ width, height });
}

fn commit_transform(self: *@This()) void {
    if (self.working_roi) |roi| {
        if (self.edit_mode) |zidx| {
            self.zooms[zidx].area = vec.rect.fromQuad(roi);
        } else {
            self.roi = roi;
        }
    }
}

pub fn update(self: *@This()) !void {
    {
        const show_win = imgui.window.begin("Image", .{});
        defer imgui.window.end();
        if (show_win) {
            if (imgui.button("Reset", .{})) {
                self.reset_roi();
            }
            imgui.layout.sameLine(.{});
            if (imgui.button("Reset rotation", .{})) {
                self.reset_rotation();
            }
            imgui.layout.sameLine(.{});
            _ = imgui.checkbox("1", &self.zooms[0].show);
            imgui.layout.sameLine(.{});
            _ = imgui.checkbox("2", &self.zooms[1].show);
            imgui.layout.sameLine(.{});
            _ = imgui.checkbox("3", &self.zooms[2].show);
            imgui.layout.sameLine(.{});
            _ = imgui.checkbox("4", &self.zooms[3].show);
            imgui.separator(.{});
            const avail = imgui.cursor.getContentRegionAvail();
            const img_screen_size = vec.fit(self.image.dims, avail);
            const screen_pos = blk: {
                const cur = imgui.cursor.getScreenPos();
                const avail_center = avail * vec.v2(0.5);
                const img_screen_center = img_screen_size * vec.v2(0.5);
                break :blk cur + avail_center - img_screen_center;
            };

            imgui.cursor.setScreenPos(screen_pos);
            imgui.window.getDrawList().addCallback(imgui.backend.set_sampler, self.image.sampler);
            imgui.image(self.image.txid, .{ .size = img_screen_size });
            imgui.window.getDrawList().addResetCallback();

            imgui.window.getDrawList().addCallback(imgui.backend.set_diff_blender, null);
            const drawflags = imgui.window.getDrawList().getFlags();
            imgui.window.getDrawList().setFlags(.{ .antiAliasedLines = false });

            const img_to_screen_scale = img_screen_size / self.image.dims;
            const img_to_screen_scaleQ = vec.quad.splatV2(img_to_screen_scale);
            const screen_posQ = vec.quad.splatV2(screen_pos);
            if (self.working_roi) |roi| {
                const working_screen_roi = @mulAdd(vec.Quad, roi, img_to_screen_scaleQ, screen_posQ);
                imgui.window.getDrawList().addQuad(@bitCast(working_screen_roi), 0xff00ffff, .{});
            }
            inline for (0..4) |zidx| {
                if (self.zooms[zidx].show and (self.edit_mode != zidx or self.working_roi == null)) {
                    const screen_roi = @mulAdd(
                        vec.Quad,
                        vec.quad.fromRect(self.zooms[zidx].area),
                        img_to_screen_scaleQ,
                        screen_posQ,
                    );
                    imgui.window.getDrawList().addQuad(@bitCast(screen_roi), 0xffffffff, .{});
                }
            }

            if (self.edit_mode != null or self.working_roi == null) {
                const screen_roi = @mulAdd(vec.Quad, self.roi, img_to_screen_scaleQ, screen_posQ);
                imgui.window.getDrawList().addQuad(@bitCast(screen_roi), 0xffffffff, .{});
            }

            imgui.window.getDrawList().setFlags(drawflags);
            imgui.window.getDrawList().addResetCallback();

            self.roi_manipulator(
                vec.rect.fromPosAndSize(screen_pos, img_screen_size),
                vec.rect.fromSize(self.image.dims),
                true,
            );
        }
    }

    {
        const show_win = imgui.window.begin("Preview", .{});
        defer imgui.window.end();
        if (show_win) {
            const avail = imgui.cursor.getContentRegionAvail();
            const img_screen_size = vec.fit(self.aspect, avail);
            const imgpos = blk: {
                const cur = imgui.cursor.getScreenPos();
                const avail_center = avail * vec.v2(0.5);
                const img_screen_center = img_screen_size * vec.v2(0.5);
                break :blk cur + avail_center - img_screen_center;
            };

            const uv_quad = blk: {
                const img_dims: vec.Quad = vec.quad.splatV2(self.image.dims);
                if (self.edit_mode == null) {
                    if (self.working_roi) |roi| {
                        break :blk roi / img_dims;
                    }
                }
                break :blk self.roi / img_dims;
            };
            const screen_quad = vec.quad.fromPosAndSize(imgpos, img_screen_size);

            imgui.cursor.setScreenPos(imgpos);
            imgui.window.getDrawList().addCallback(imgui.backend.set_sampler, self.image.sampler);
            imgui.window.getDrawList().addImageQuad(
                self.image.txid,
                @bitCast(screen_quad),
                @bitCast(uv_quad),
                .{},
            );
            imgui.window.getDrawList().addResetCallback();
        }
    }

    // TODO: reposition within the Image window?
    inline for (0..4) |zidx| {
        if (self.zooms[zidx].show) {
            const show_win = imgui.window.begin(
                std.fmt.comptimePrint("Zoomed Area {d}", .{zidx}),
                .{
                    .open = &self.zooms[zidx].show,
                },
            );
            defer imgui.window.end();
            if (show_win) {
                var edit = (self.edit_mode == zidx);
                if (imgui.checkbox("Edit", &edit)) {
                    if (self.edit_mode == zidx) {
                        self.edit_mode = null;
                    } else {
                        self.edit_mode = zidx;
                    }
                }
                imgui.separator(.{});
                {
                    const show_child = imgui.window.beginChild("Image", .{
                        .size = imgui.cursor.getContentRegionAvail(),
                    });
                    defer imgui.window.endChild();
                    if (show_child) {
                        const avail = imgui.cursor.getContentRegionAvail();
                        const zoom_size = blk: {
                            if (self.edit_mode == zidx) {
                                if (self.working_roi) |roi| {
                                    break :blk vec.quad.dims(roi);
                                }
                            }
                            break :blk vec.rect.dims(self.zooms[zidx].area);
                        };

                        const img_screen_size = vec.fit(zoom_size, avail);
                        const screen_pos = blk: {
                            const cur = imgui.cursor.getScreenPos();
                            const avail_center = avail * vec.v2(0.5);
                            const img_screen_center = img_screen_size * vec.v2(0.5);
                            break :blk cur + avail_center - img_screen_center;
                        };

                        const img_dims: vec.Quad = vec.quad.splatV2(self.image.dims);
                        const uv_quad = blk: {
                            if (self.edit_mode == zidx) {
                                if (self.working_roi) |roi| {
                                    break :blk roi / img_dims;
                                }
                            }
                            break :blk vec.quad.fromRect(self.zooms[zidx].area) / img_dims;
                        };
                        const screen_quad = vec.quad.fromPosAndSize(screen_pos, img_screen_size);

                        imgui.window.getDrawList().addCallback(
                            imgui.backend.set_sampler,
                            self.image.sampler,
                        );
                        imgui.window.getDrawList().addImageQuad(
                            self.image.txid,
                            @bitCast(screen_quad),
                            @bitCast(uv_quad),
                            .{},
                        );
                        imgui.window.getDrawList().addResetCallback();

                        imgui.window.getDrawList().addCallback(imgui.backend.set_diff_blender, null);
                        const drawflags = imgui.window.getDrawList().getFlags();
                        imgui.window.getDrawList().setFlags(.{ .antiAliasedLines = false });

                        const img_to_screen_scale = img_screen_size / zoom_size;
                        const img_to_screen_scaleQ = vec.quad.splatV2(img_to_screen_scale);
                        const screen_posQ = vec.quad.splatV2(screen_pos);
                        if (self.edit_mode != null or self.working_roi == null) {
                            const origin = blk: {
                                if (self.edit_mode == zidx) {
                                    if (self.working_roi) |roi| {
                                        break :blk vec.quad.p0(roi);
                                    }
                                }
                                break :blk vec.rect.p0(self.zooms[zidx].area);
                            };
                            const screen_roi = @mulAdd(
                                vec.Quad,
                                self.roi - vec.quad.splatV2(origin),
                                img_to_screen_scaleQ,
                                screen_posQ,
                            );
                            imgui.window.getDrawList().addQuad(@bitCast(screen_roi), 0xffffffff, .{});
                        } else if (self.working_roi) |roi| {
                            const working_screen_roi = @mulAdd(
                                vec.Quad,
                                roi - vec.quad.splatV2(vec.rect.p0(self.zooms[zidx].area)),
                                img_to_screen_scaleQ,
                                screen_posQ,
                            );
                            imgui.window.getDrawList().addQuad(
                                @bitCast(working_screen_roi),
                                0xff00ffff,
                                .{},
                            );
                        }

                        imgui.window.getDrawList().setFlags(drawflags);
                        imgui.window.getDrawList().addResetCallback();

                        if (self.edit_mode == null) {
                            self.roi_manipulator(
                                vec.rect.fromQuad(screen_quad),
                                self.zooms[zidx].area,
                                false,
                            );
                        }
                    }
                }
            }
        }
    }
}

fn roi_manipulator(
    self: *@This(),
    screen_rect: vec.Rect,
    img_rect: vec.Rect,
    allow_rotation: bool,
) void {
    imgui.cursor.setScreenPos(vec.rect.p0(screen_rect));
    _ = imgui.invisibleButton("Image ROI manipulation", vec.rect.dims(screen_rect), .{});

    if (imgui.item.isDeactivated()) {
        self.commit_transform();
        self.working_roi = null;
    }

    const ref_roi =
        if (self.edit_mode) |zidx|
            vec.quad.fromRect(self.zooms[zidx].area)
        else
            self.roi;

    if (imgui.item.isActivated()) {
        self.working_roi = ref_roi;
    }

    const free_transform = self.edit_mode != null;

    const img_to_screen_scale = vec.rect.dims(screen_rect) / vec.rect.dims(img_rect);
    const screen_to_img_scale = vec.rect.dims(img_rect) / vec.rect.dims(screen_rect);
    const mousepos = imgui.mouse.getPos();

    // only update potential operation if none is being performed
    if (imgui.item.isHovered(.{}) and self.working_roi == null) {
        const screen_roi = @mulAdd(
            vec.Quad,
            ref_roi - vec.quad.splatV2(vec.rect.p0(img_rect)),
            vec.quad.splatV2(img_to_screen_scale),
            vec.quad.splatV2(vec.rect.p0(screen_rect)),
        );
        const screen_roi_size = vec.quad.dims(screen_roi);
        const mouse_roi: vec.V2 = .{
            vec.rel_scalar_project(
                mousepos - vec.quad.p0(screen_roi),
                vec.unit(vec.quad.p1(screen_roi) - vec.quad.p0(screen_roi)),
            ),
            vec.rel_scalar_project(
                mousepos - vec.quad.p0(screen_roi),
                vec.unit(vec.quad.p3(screen_roi) - vec.quad.p0(screen_roi)),
            ),
        };
        const mouse_roi_uv: vec.V2 = .{
            std.math.clamp(vec.rel_scalar_project(
                mousepos - vec.quad.p0(screen_roi),
                vec.quad.p1(screen_roi) - vec.quad.p0(screen_roi),
            ), 0, 1),
            std.math.clamp(vec.rel_scalar_project(
                mousepos - vec.quad.p0(screen_roi),
                vec.quad.p3(screen_roi) - vec.quad.p0(screen_roi),
            ), 0, 1),
        };

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
        const actually_allow_rotation = allow_rotation and self.edit_mode == null;
        if (self.roi_op == .rot and !actually_allow_rotation) self.roi_op = .mov;
        self.roi_op.?.use_mouse_pointer();
    }

    if (imgui.item.isActive()) {
        if (self.roi_op) |op| {
            const mouse_delta: vec.V2 = imgui.mouse.getDelta();
            const mouse_delta_img = mouse_delta * screen_to_img_scale;
            op.use_mouse_pointer();

            switch (op) {
                .nw => {
                    self.scale_corner_handle(mouse_delta_img, 0, free_transform);
                },
                .ne => {
                    self.scale_corner_handle(mouse_delta_img, 1, free_transform);
                },
                .se => {
                    self.scale_corner_handle(mouse_delta_img, 2, free_transform);
                },
                .sw => {
                    self.scale_corner_handle(mouse_delta_img, 3, free_transform);
                },
                .n => {
                    self.scale_edge_handle(mouse_delta_img, 0, free_transform);
                },
                .e => {
                    self.scale_edge_handle(mouse_delta_img, 1, free_transform);
                },
                .s => {
                    self.scale_edge_handle(mouse_delta_img, 2, free_transform);
                },
                .w => {
                    self.scale_edge_handle(mouse_delta_img, 3, free_transform);
                },
                .mov => {
                    self.move_op(mouse_delta_img);
                },
                .rot => {
                    const old_pos = vec.sub(mousepos, mouse_delta);
                    const pivot = vec.rect.p0(screen_rect) + vec.quad.center(ref_roi) * img_to_screen_scale;
                    imgui.window.getDrawList().addLine(mousepos, pivot, 0xffffffff, .{});
                    // NOTE: our Y is pointing down-screen, so the angle
                    // direction has to be reversed: CCW positive in a (+X,+Y)
                    // base is CW positive in a (+X,-Y) base.
                    const angle_delta = -vec.angle(
                        vec.direction(pivot, old_pos),
                        vec.direction(pivot, mousepos),
                    );

                    if (!std.math.approxEqAbs(f32, angle_delta, 0, std.math.floatEps(f32))) {
                        self.rot_op(angle_delta);
                    }
                },
            }
            if (imgui.mouse.isClicked(.right, .{})) {
                self.working_roi = null;
            }
        }
    }
}

fn scale_corner_handle(
    self: *@This(),
    init_delta: vec.V2,
    comptime corner_idx: i32,
    free_transform: bool,
) void {
    // These renamings make it easier to reason about: we treat everything as it
    // if was using the indices for the North West corner.
    const p0i = (corner_idx & 3); // 0
    const p1i = ((corner_idx + 1) & 3); // 1
    const p2i = ((corner_idx + 2) & 3); // 2
    const p3i = ((corner_idx + 3) & 3); // 3
    if (self.working_roi) |roi| {
        const p0 = vec.quad.corner(roi, p0i);
        const p1 = vec.quad.corner(roi, p1i);
        const p2 = vec.quad.corner(roi, p2i);
        const p3 = vec.quad.corner(roi, p3i);
        const corner_delta = if (free_transform) init_delta else vec.project(init_delta, p2 - p0);
        const delta_p1 = vec.project(corner_delta, p2 - p1);
        const delta_p3 = vec.project(corner_delta, p2 - p3);
        const mask: @Vector(8, i32) = .{
            (8 - p0i * 2) & 7,
            (9 - p0i * 2) & 7,
            (10 - p0i * 2) & 7,
            (11 - p0i * 2) & 7,
            (12 - p0i * 2) & 7,
            (13 - p0i * 2) & 7,
            (14 - p0i * 2) & 7,
            (15 - p0i * 2) & 7,
        };
        const quad_delta = @shuffle(f32, vec.quad.from4V2(
            corner_delta,
            delta_p1,
            @splat(0),
            delta_p3,
        ), undefined, mask);
        const factor = vec.quad.bound_transform(
            roi,
            quad_delta,
            @splat(0),
            self.image.dims,
        );
        const t: vec.Quad = @splat(factor);
        var new_roi = @mulAdd(vec.Quad, t, quad_delta, roi);
        if (!free_transform) {
            const new_size = vec.quad.dimsSq(new_roi);
            const min_size = self.min_size;
            if (@reduce(.Or, new_size < (min_size * min_size))) {
                const size_ratio = @sqrt((min_size * min_size) / new_size)[0];
                const size_ratio_quad: vec.Quad = @splat(size_ratio);
                const pivot = vec.quad.splatV2(p2);
                const new_roi_vecs = new_roi - pivot;
                new_roi = @mulAdd(vec.Quad, new_roi_vecs, size_ratio_quad, pivot);
            }
        }
        self.working_roi = new_roi;
    }
}

/// edge is identified by the index of its first vertex. And edge will always be
/// (i, i+1), where 'i' wraps within [0,3]
fn scale_edge_handle(
    self: *@This(),
    init_delta: vec.V2,
    comptime edge: usize,
    free_transform: bool,
) void {
    // These renamings make it easier to reason about: we treat everything as it
    // if was using the indices for the North edge.
    const p0i = (edge & 3); // 0
    const p1i = ((edge + 1) & 3); // 1
    const p2i = ((edge + 2) & 3); // 2
    const p3i = ((edge + 3) & 3); // 3
    if (self.working_roi) |roi| {
        const p0 = vec.quad.corner(roi, p0i);
        const p1 = vec.quad.corner(roi, p1i);
        const p2 = vec.quad.corner(roi, p2i);
        const p3 = vec.quad.corner(roi, p3i);
        const poc = vec.lerp(p2, p3, 0.5);
        const normal_delta = vec.project(init_delta, p3 - p0);
        const p0_delta = if (free_transform) normal_delta else vec.unproject(normal_delta, poc - p0);
        const p1_delta = if (free_transform) normal_delta else vec.unproject(normal_delta, poc - p1);
        const p3_delta = vec.project(p0_delta, poc - p3);
        const p2_delta = vec.project(p1_delta, poc - p2);
        const mask: @Vector(8, i32) = .{
            (8 - p0i * 2) & 7,
            (9 - p0i * 2) & 7,
            (10 - p0i * 2) & 7,
            (11 - p0i * 2) & 7,
            (12 - p0i * 2) & 7,
            (13 - p0i * 2) & 7,
            (14 - p0i * 2) & 7,
            (15 - p0i * 2) & 7,
        };
        const quad_delta = @shuffle(f32, vec.quad.from4V2(
            p0_delta,
            p1_delta,
            p2_delta,
            p3_delta,
        ), undefined, mask);
        const factor = vec.quad.bound_transform(
            roi,
            quad_delta,
            @splat(0),
            self.image.dims,
        );
        const t: vec.Quad = @splat(factor);
        var new_roi = @mulAdd(vec.Quad, t, quad_delta, roi);
        if (!free_transform) {
            const new_size = vec.quad.dimsSq(new_roi);
            const min_size = self.min_size;
            if (@reduce(.Or, new_size < (min_size * min_size))) {
                const size_ratio = @sqrt((min_size * min_size) / new_size)[0];
                const size_ratio_quad: vec.Quad = @splat(size_ratio);
                const pivot = vec.quad.splatV2(poc);
                const new_roi_vecs = new_roi - pivot;
                new_roi = @mulAdd(vec.Quad, new_roi_vecs, size_ratio_quad, pivot);
            }
        }
        self.working_roi = new_roi;
    }
}

fn move_op(self: *@This(), init_delta: vec.V2) void {
    if (self.working_roi) |roi| {
        const quad_delta: vec.Quad = vec.quad.splatV2(init_delta);
        var factor = vec.quad.bound_transform(
            roi,
            quad_delta,
            @splat(0),
            self.image.dims,
        );

        var t: vec.Quad = @splat(factor);
        var new_roi = @mulAdd(vec.Quad, t, quad_delta, roi);
        if (factor < 1) {
            const low_bounds: vec.Quad = @splat(0);
            const high_bounds: vec.Quad = vec.quad.splatV2(self.image.dims);
            var low_bounds_diffs = new_roi - low_bounds;
            var high_bounds_diffs = new_roi - high_bounds;

            // we snap small diffs to 0
            const eps: vec.Quad = @splat(std.math.floatEps(f32));
            const fzeroes: vec.Quad = @splat(0);
            low_bounds_diffs = @select(f32, @abs(low_bounds_diffs) <= eps, fzeroes, low_bounds_diffs);
            high_bounds_diffs = @select(f32, @abs(high_bounds_diffs) <= eps, fzeroes, high_bounds_diffs);

            const at_low_bounds = low_bounds_diffs == fzeroes;
            const at_high_bounds = high_bounds_diffs == fzeroes;
            const zeroes: @Vector(8, u32) = @splat(0);
            const hit_mask = (@intFromBool(at_low_bounds) | @intFromBool(at_high_bounds)) != zeroes;
            const indices: @Vector(8, u32) = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
            const hit_idxs = @select(u32, hit_mask, indices, zeroes);
            const hit_idx = @reduce(.Max, hit_idxs);
            const glide_factor: vec.Quad = vec.quad.splatV2(.{
                @as(f32, @floatFromInt((hit_idx) & 1)) * (1 - t[0]),
                @as(f32, @floatFromInt((hit_idx + 1) & 1)) * (1 - t[0]),
            });
            const glide_delta = glide_factor * quad_delta;

            factor = vec.quad.bound_transform(
                new_roi,
                glide_delta,
                @splat(0),
                self.image.dims,
            );
            t = @splat(factor);
            new_roi = @mulAdd(vec.Quad, t, glide_delta, new_roi);
        }
        self.working_roi = new_roi;
    }
}

fn rot_op(self: *@This(), init_angle: f32) void {
    if (self.working_roi) |roi| {
        const pivot = vec.quad.center(roi);
        const pivotRect = vec.rect.splatV2(pivot);
        const radiusSq = vec.distSq(pivot, vec.quad.p0(roi));

        const bounds = vec.Rect{ 0, 0, self.image.dims[0], self.image.dims[1] };
        // squares of:
        // { y coord of left edge intersection
        // , x coord of top edge intersection
        // , y coord of right edge intersection
        // , x coord of bottom edge intersection
        // }
        const intersect_offs_sq =
            @as(vec.Rect, @splat(radiusSq)) - ((bounds - pivotRect) * (bounds - pivotRect));
        // Vector of bools:
        // true if that quad coordinate would hit
        const zeroes: vec.Rect = @splat(0);
        const have_hits = intersect_offs_sq > zeroes;
        var final_angle = init_angle;
        if (@reduce(.Or, have_hits)) {
            // 1. get all hit points (dunno how yet)
            // 2. get abs angles of them
            // 3. compare with all angles? of quad points
            // 4. get min angle
            // NOTE: remember that you're using the mouse deltas and that those
            // deltas are typically small.
            // A "negative relative angle" between corner and hit point that's
            // under 1° is likely to mean your quad is slightly out of bounds
            // due to rounding inconsistencies.
            // That said, because we want the minimum of these, they should be
            // either snapped to 0 still or handled in some other way, not
            // ignored or treated as-is

            // positive coord of edge intersection,
            // nan if no intersection
            const nanRect: vec.Rect = @splat(std.math.nan(f32));
            const offs = @sqrt(@select(f32, have_hits, intersect_offs_sq, nanRect));
            const offs_q = vec.quad.spreadRect(offs);
            const angle_sign = std.math.sign(init_angle);
            const offs_mask = vec.Quad{
                0, angle_sign,  -angle_sign, 0,
                0, -angle_sign, angle_sign,  0,
            };
            const pivotProj = vec.Quad{
                bounds[0], pivot[1], pivot[0], bounds[1],
                bounds[2], pivot[1], pivot[0], bounds[3],
            };
            const hit_points = @mulAdd(vec.Quad, offs_q, offs_mask, pivotProj);

            const pivotQuad = vec.quad.splatV2(pivot);
            const hit_vecs = hit_points - pivotQuad;
            const hit0_angle = -vec.angleAbs(vec.quad.p0(hit_vecs));
            const hit1_angle = -vec.angleAbs(vec.quad.p1(hit_vecs));
            const hit2_angle = -vec.angleAbs(vec.quad.p2(hit_vecs));
            const hit3_angle = -vec.angleAbs(vec.quad.p3(hit_vecs));
            const hit_angles = vec.Rect{ hit0_angle, hit1_angle, hit2_angle, hit3_angle };

            const roi_vecs = roi - pivotQuad;
            const p0_angle = -vec.angleAbs(vec.quad.p0(roi_vecs));
            const p1_angle = -vec.angleAbs(vec.quad.p1(roi_vecs));
            const p2_angle = -vec.angleAbs(vec.quad.p2(roi_vecs));
            const p3_angle = -vec.angleAbs(vec.quad.p3(roi_vecs));

            var p0_rel_angles = hit_angles - @as(vec.Rect, @splat(p0_angle));
            var p1_rel_angles = hit_angles - @as(vec.Rect, @splat(p1_angle));
            var p2_rel_angles = hit_angles - @as(vec.Rect, @splat(p2_angle));
            var p3_rel_angles = hit_angles - @as(vec.Rect, @splat(p3_angle));

            // we snap small angle diffs to 0
            const eps: vec.Rect = @splat(0.0001);
            p0_rel_angles = @select(f32, @abs(p0_rel_angles) <= eps, zeroes, p0_rel_angles);
            p1_rel_angles = @select(f32, @abs(p1_rel_angles) <= eps, zeroes, p1_rel_angles);
            p2_rel_angles = @select(f32, @abs(p2_rel_angles) <= eps, zeroes, p2_rel_angles);
            p3_rel_angles = @select(f32, @abs(p3_rel_angles) <= eps, zeroes, p3_rel_angles);

            // we make it so angles in the direction of `init_angle` are positive:
            const angle_sign_rect: vec.Rect = @splat(angle_sign);
            p0_rel_angles *= angle_sign_rect;
            p1_rel_angles *= angle_sign_rect;
            p2_rel_angles *= angle_sign_rect;
            p3_rel_angles *= angle_sign_rect;

            // We keep only the positives:
            p0_rel_angles = @select(f32, p0_rel_angles < zeroes, nanRect, p0_rel_angles);
            p1_rel_angles = @select(f32, p1_rel_angles < zeroes, nanRect, p1_rel_angles);
            p2_rel_angles = @select(f32, p2_rel_angles < zeroes, nanRect, p2_rel_angles);
            p3_rel_angles = @select(f32, p3_rel_angles < zeroes, nanRect, p3_rel_angles);

            // Now we can look for the minimum:
            const p0_min_rel_angle = @reduce(.Min, p0_rel_angles);
            const p1_min_rel_angle = @reduce(.Min, p1_rel_angles);
            const p2_min_rel_angle = @reduce(.Min, p2_rel_angles);
            const p3_min_rel_angle = @reduce(.Min, p3_rel_angles);

            final_angle = @min(
                init_angle * angle_sign,
                p0_min_rel_angle,
                p1_min_rel_angle,
                p2_min_rel_angle,
                p3_min_rel_angle,
            ) * angle_sign;
        }

        const cos = std.math.cos(final_angle);
        const sin = std.math.sin(final_angle);

        self.working_roi = vec.quad.rotate(roi, pivot, cos, sin);
    }
}

/// An area of an editable RoI along one of its axes
const Region = enum { out, near_edge, near, in, far, far_edge };

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

const Handle = enum {
    rot,
    nw,
    ne,
    se,
    sw,
    n,
    s,
    e,
    w,
    mov,
    pub fn use_mouse_pointer(h: Handle) void {
        imgui.mouse.setPointer(switch (h) {
            .rot => .hand, // TODO: rotation pointer
            .nw, .se => .resizeNWSE,
            .ne, .sw => .resizeNESW,
            .e, .w => .resizeEW,
            .n, .s => .resizeNS,
            .mov => .resizeAll,
        });
    }
};
