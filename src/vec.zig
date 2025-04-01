const std = @import("std");

pub const V2 = @Vector(2, f32);

pub fn v2(v: f32) V2 {
    return @splat(v);
}

pub fn x(v: V2) f32 {
    return v[0];
}

pub fn y(v: V2) f32 {
    return v[1];
}

pub fn neg(v: V2) V2 {
    return -v;
}

/// The CCW orthogonal vector to v
pub fn orth(v: V2) V2 {
    const x_, const y_ = v;
    return V2{ -y_, x_ };
}

pub fn dot(a: V2, b: V2) f32 {
    return @reduce(.Add, a * b);
}

/// The squared length of the vector
pub fn lenSq(v: V2) f32 {
    return dot(v, v);
}

/// The length of the vector
pub fn len(v: V2) f32 {
    return @sqrt(lenSq(v));
}

/// The squared distance between the points
pub fn distSq(a: V2, b: V2) f32 {
    return lenSq(direction(a, b));
}

/// The unsigned distance between the points
pub fn dist(a: V2, b: V2) f32 {
    return @sqrt(distSq(a, b));
}

pub fn scale(v: V2, f: f32) V2 {
    return v * @as(V2, @splat(f));
}

/// In-place add
pub fn offset(a: *V2, v: V2) void {
    a.* += v;
}

/// Element-wise addition
pub fn add(a: V2, b: V2) V2 {
    return a + b;
}

/// Element-wise subtraction
pub fn sub(a: V2, b: V2) V2 {
    return a - b;
}

/// Element-wise multiplication
pub fn mul(a: V2, b: V2) V2 {
    return a * b;
}

/// Element-wise division
pub fn div(a: V2, b: V2) V2 {
    return a / b;
}

/// The vector in the same direction, of length 1
pub fn unit(v: V2) V2 {
    const length: V2 = @splat(len(v));
    return v / length;
}

/// The vector used to get from a to b
pub fn direction(a: V2, b: V2) V2 {
    return b - a;
}

/// Linearly interpolate between a and b
pub fn lerp(a: V2, b: V2, t: f32) V2 {
    return @mulAdd(V2, @splat(t), b - a, a);
}

/// How much to multiply W by to get the projection of V onto W
pub fn rel_scalar_project(v: V2, w: V2) f32 {
    if (dot(w, w) == 0) {
        return 0;
    }
    return dot(v, w) / dot(w, w);
}

/// The projection of V onto W
pub fn project(v: V2, w: V2) V2 {
    const factor = rel_scalar_project(v, w);
    return scale(w, factor);
}

/// The vector aligned with W that if projected onto V, would give V
pub fn unproject(v: V2, w: V2) V2 {
    if (dot(v, w) == 0) {
        return .{ 0, 0 };
    }
    const factor = dot(v, v) / dot(v, w);
    return scale(w, factor);
}

/// Rotate V using pre-computed cos and sin
pub fn rotate(v: V2, cos: f32, sin: f32) V2 {
    return .{
        x(v) * cos - y(v) * sin,
        x(v) * sin + y(v) * cos,
    };
}

test "rotations" {
    const t = std.testing;
    const math = std.math;
    const eps = math.floatEps(f32);

    var rads: f32 = math.degreesToRadians(30);
    var cos: f32 = math.cos(rads);
    var sin: f32 = math.sin(rads);

    var v: [2]f32 = rotate(.{ 1, 0 }, cos, sin);
    try t.expectApproxEqRel(cos, v[0], eps);
    try t.expectApproxEqRel(sin, v[1], eps);
    v = rotate(.{ 0, 1 }, cos, sin);
    try t.expectApproxEqRel(-sin, v[0], eps);
    try t.expectApproxEqRel(cos, v[1], eps);

    rads = math.degreesToRadians(90);
    cos = math.cos(rads);
    sin = math.sin(rads);
    v = rotate(.{ 1, 0 }, cos, sin);
    try t.expectApproxEqAbs(0, v[0], eps);
    try t.expectApproxEqRel(1, v[1], eps);
    v = rotate(.{ 0, 1 }, cos, sin);
    try t.expectApproxEqRel(-1, v[0], eps);
    try t.expectApproxEqAbs(0, v[1], eps);
    v = rotate(.{ 0.5, 0.5 }, cos, sin);
    try t.expectApproxEqRel(-0.5, v[0], eps);
    try t.expectApproxEqRel(0.5, v[1], eps);

    rads = math.degreesToRadians(135);
    cos = math.cos(rads);
    sin = math.sin(rads);
    v = rotate(.{ 1, 0 }, cos, sin);
    try t.expectApproxEqRel(-(math.sqrt2 * 0.5), v[0], eps);
    try t.expectApproxEqRel((math.sqrt2 * 0.5), v[1], eps);
}

/// The signed angle from a to b
/// CCW positive
/// Between -pi and +pi
pub fn angle(a: V2, b: V2) f32 {
    return std.math.atan2(dot(a, orth(b)), dot(a, b));
}

/// The signed angle from (1,0) to b
/// CCW positive
/// Between 0 and 2pi
pub fn angleAbs(v: V2) f32 {
    const math = std.math;
    const a = angle(.{ 1, 0 }, v);
    return @mod(a, math.tau);
}

/// The factor to multiply `v` by to intersect the bound defined by `dim` and
/// `bound`, starting from `pos`
/// Returns null if the ray and bound are parallel, or if the factor is outside
/// the range (0,1)
pub fn vec_bound_intersect(
    pos: V2,
    v: V2,
    comptime dim: anytype,
    comptime norm: anytype,
    bound: f32,
) ?f32 {
    const dim_access = switch (dim) {
        .x => x,
        .y => y,
        else => @compileError("Expected .x or .y"),
    };
    if (dim_access(v) == 0) return null;
    const t = (bound - dim_access(pos)) / dim_access(v);
    const normal_v = blk: {
        var n: [2]f32 = .{ 0, 0 };
        const idx = switch (dim) {
            .x => 0,
            .y => 1,
            else => @compileError("Expected .x or .y"),
        };
        switch (norm) {
            .pos => n[idx] = 1,
            .neg => n[idx] = -1,
            else => @compileError("Expected .pos or .neg"),
        }
        break :blk n;
    };
    if (1 < t) return null;
    if (dot(v, normal_v) > 0) {
        if (t <= 0) return null;
    }
    if (t < 0) return null;
    return t;
}

/// Scales the aspect size to be either
/// as wide as `max_size[0]`, or as tall as `max_size[1]`
pub fn fit(aspect: V2, max_size: V2) V2 {
    const maxwf: f32, const maxhf: f32 = max_size;
    const aspwf: f32, const asphf: f32 = aspect;
    const maxratio = maxwf / maxhf;
    const aspratio = aspwf / asphf;
    if (aspratio > maxratio) {
        return .{ maxwf, maxwf / aspratio };
    } else {
        return .{ maxhf * aspratio, maxhf };
    }
}

/// Defined by top-left and bottom-right points
pub const Rect = @Vector(4, f32);

pub const mask2 = @Vector(2, i32);
pub const mask4 = @Vector(4, i32);
pub const mask8 = @Vector(8, i32);

pub const rect = struct {
    pub fn splatV2(v: V2) Rect {
        return @shuffle(f32, v, undefined, mask4{ 0, 1, 0, 1 });
    }

    pub fn fromQuad(q: Quad) Rect {
        return @shuffle(f32, q, undefined, mask4{ 0, 1, 4, 5 });
    }

    pub fn fromSize(size: V2) Rect {
        const w, const h = size;
        return Rect{
            0,
            0,
            w,
            h,
        };
    }

    pub fn fromPosAndSize(pos: V2, size: V2) Rect {
        return splatV2(pos) + fromSize(size);
    }

    pub fn p0(r: Rect) V2 {
        return @shuffle(f32, r, undefined, mask2{ 0, 1 });
    }

    pub fn p1(r: Rect) V2 {
        return @shuffle(f32, r, undefined, mask2{ 2, 3 });
    }

    pub fn dims(r: Rect) V2 {
        return p1(r) - p0(r);
    }
};

/// Defined by 4 points, assumed clockwise when relevant
pub const Quad = @Vector(8, f32);

pub const quad = struct {
    pub fn splatV2(v: V2) Quad {
        return @shuffle(f32, v, undefined, mask8{ 0, 1, 0, 1, 0, 1, 0, 1 });
    }

    pub fn fromRectPoints(top_left: V2, bottom_right: V2) Quad {
        return @shuffle(f32, top_left, bottom_right, mask8{ 0, 1, -1, 1, -1, -2, 0, -2 });
    }

    pub fn fromRect(r: Rect) Quad {
        return @shuffle(f32, r, undefined, mask8{ 0, 1, 2, 1, 2, 3, 0, 3 });
    }

    pub fn spreadRect(r: Rect) Quad {
        return @shuffle(f32, r, undefined, mask8{ 0, 0, 1, 1, 2, 2, 3, 3 });
    }

    pub fn fromPosAndSize(pos: V2, size: V2) Quad {
        const w, const h = size;
        return splatV2(pos) + Quad{ 0, 0, w, 0, w, h, 0, h };
    }

    pub fn fromCenterAndSize(c: V2, size: V2) Quad {
        const w, const h = size;
        const center8 = @shuffle(f32, c, undefined, mask8{ 0, 1, 0, 1, 0, 1, 0, 1 });
        return @mulAdd(
            Quad,
            Quad{ -w, -h, w, -h, w, h, -w, h },
            @splat(0.5),
            center8,
        );
    }

    pub fn from4V2(vec0: V2, vec1: V2, vec2: V2, vec3: V2) Quad {
        return .{ vec0[0], vec0[1], vec1[0], vec1[1], vec2[0], vec2[1], vec3[0], vec3[1] };
    }

    /// Corner Index is the index of the 2d-point, from 0 through 3
    pub fn corner(q: Quad, comptime corner_idx: i32) V2 {
        const coord_idx = (corner_idx * 2) & 7;
        return @shuffle(f32, q, undefined, mask2{ coord_idx, coord_idx + 1 });
    }

    pub fn p0(q: Quad) V2 {
        return corner(q, 0);
    }

    pub fn p1(q: Quad) V2 {
        return corner(q, 1);
    }

    pub fn p2(q: Quad) V2 {
        return corner(q, 2);
    }

    pub fn p3(q: Quad) V2 {
        return corner(q, 3);
    }

    pub fn center(q: Quad) V2 {
        return lerp(p0(q), p2(q), 0.5);
    }

    pub fn width(q: Quad) f32 {
        return dist(p0(q), p1(q));
    }

    pub fn height(q: Quad) f32 {
        return dist(p0(q), p3(q));
    }

    /// for comparison purposes
    pub fn dimsSq(q: Quad) V2 {
        const dests: Rect = @shuffle(f32, q, undefined, mask4{ 2, 3, 6, 7 });
        const src: Rect = @shuffle(f32, q, undefined, mask4{ 0, 1, 0, 1 });
        const axes = dests - src;
        const axesSq = axes * axes;
        const axesSqT = @shuffle(f32, axesSq, undefined, mask4{ 1, 0, 3, 2 });
        const xSqPlusYSq = axesSq + axesSqT;
        return @shuffle(f32, xSqPlusYSq, undefined, mask2{ 0, 2 });
    }

    pub fn dims(q: Quad) V2 {
        return .{
            width(q),
            height(q),
        };
    }

    /// Rotate Q around pivot using pre-computed cos and sin
    pub fn rotate(q: Quad, pivot: V2, cos: f32, sin: f32) Quad {
        const pivotQ = splatV2(pivot);
        const quadVecs = q - pivotQ;

        const xs = @shuffle(f32, quadVecs, undefined, mask8{ 0, 0, 2, 2, 4, 4, 6, 6 });
        const ys = @shuffle(f32, quadVecs, undefined, mask8{ 1, 1, 3, 3, 5, 5, 7, 7 });
        const cs = splatV2(.{ cos, sin });
        const sc = splatV2(.{ -sin, cos });

        return pivotQ + (xs * cs + ys * sc);
    }

    pub fn boundingRect(q: Quad) Rect {
        const xs = @shuffle(f32, q, undefined, mask4{ 0, 2, 4, 6 });
        const ys = @shuffle(f32, q, undefined, mask4{ 1, 3, 5, 7 });
        return .{
            @reduce(.Min, xs),
            @reduce(.Min, ys),
            @reduce(.Max, xs),
            @reduce(.Max, ys),
        };
    }

    /// The factor by which to multiply d to add to q so that the result stays
    /// within min and max.
    /// It is assumed that min < max
    pub fn bound_transform(q: Quad, d: Quad, min: V2, max: V2) f32 {
        // Intersect q+d with bb:
        // for each side of bb, get the maximum t so that q+t*d stays within bb
        const lower_bounds_quad: Quad = splatV2(min);
        const higher_bounds_quad: Quad = splatV2(max);
        const zeroes: Quad = @splat(0);
        // We select only deltas that are susceptible to intersection
        const nans: Quad = @splat(std.math.nan(f32));
        const low_delta = @select(f32, d < zeroes, d, nans);
        const high_delta = @select(f32, zeroes < d, d, nans);
        // because we pre-selected the deltas, all these are positive, or 0
        // and all 0s are relevant blockages
        const low_t = (lower_bounds_quad - q) / low_delta;
        const high_t = (higher_bounds_quad - q) / high_delta;
        const min_t = @min(@reduce(.Min, @min(low_t, high_t)), 1);
        return min_t;
    }

    test "Bounded Transform: Bump into wall" {
        {
            const q: Quad = .{ 0, 0, 0, 1, 1, 1, 1, 0 };
            const d: Quad = quad.splatV2(.{ 3, 0 });
            const transf = @mulAdd(
                Quad,
                @splat(quad.bound_transform(q, d, .{ -2, -2 }, .{ 2, 2 })),
                d,
                q,
            );
            try std.testing.expectEqual(Quad{ 1, 0, 1, 1, 2, 1, 2, 0 }, transf);
        }
        {
            const q: Quad = .{ 0, 0, 0, 1, 1, 1, 1, 0 };
            const d: Quad = quad.splatV2(.{ -5, 0 });
            const transf = @mulAdd(
                Quad,
                @splat(quad.bound_transform(q, d, .{ -2, -2 }, .{ 2, 2 })),
                d,
                q,
            );
            try std.testing.expectEqual(Quad{ -2, 0, -2, 1, -1, 1, -1, 0 }, transf);
        }
    }

    test "Bounded Transform: Don't stick to wall" {
        {
            const q: Quad = .{ -2, -2, -2, -1, -1, -1, -1, -2 };
            const d: Quad = quad.splatV2(.{ 3, 1 });
            const transf = @mulAdd(
                Quad,
                @splat(quad.bound_transform(q, d, .{ -2, -2 }, .{ 2, 2 })),
                d,
                q,
            );
            try std.testing.expectEqual(Quad{ 1, -1, 1, 0, 2, 0, 2, -1 }, transf);
        }
        {
            const q: Quad = .{ 1, 1, 1, 2, 2, 2, 2, 1 };
            const d: Quad = quad.splatV2(.{ -2, -1 });
            const transf = @mulAdd(
                Quad,
                @splat(quad.bound_transform(q, d, .{ -2, -2 }, .{ 2, 2 })),
                d,
                q,
            );
            try std.testing.expectEqual(Quad{ -1, 0, -1, 1, 0, 1, 0, 0 }, transf);
        }
    }
};

// We reference the structs so that zig actually runs the tests when running
// `zig test src/vecs.zig`
test {
    _ = rect;
    _ = quad;
}
