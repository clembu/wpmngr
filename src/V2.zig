const V2 = [2]f32;

pub fn x(v: V2) f32 {
    return v[0];
}

pub fn y(v: V2) f32 {
    return v[1];
}

pub fn neg(v: V2) V2 {
    return .{
        -x(v),
        -y(v),
    };
}

/// The CCW orthogonal vector to v
pub fn orth(v: V2) V2 {
    return .{ -y(v), x(v) };
}

/// The squared length of the vector
pub fn lenSq(v: V2) f32 {
    return x(v) * x(v) + y(v) * y(v);
}

pub fn len(v: V2) f32 {
    return @import("std").math.sqrt(lenSq(v));
}

/// The squared distance between the points
pub fn distSq(a: V2, b: V2) f32 {
    return lenSq(direction(a, b));
}

/// The unsigned distance between the points
pub fn dist(a: V2, b: V2) f32 {
    return @import("std").math.sqrt(distSq(a, b));
}

pub fn scale(v: V2, f: f32) V2 {
    return .{
        x(v) * f,
        y(v) * f,
    };
}

/// In-place add
pub fn offset(a: *V2, v: V2) void {
    a.*[0] += x(v);
    a.*[1] += y(v);
}

/// Element-wise addition
pub fn add(v: V2, w: V2) V2 {
    return .{
        x(v) + x(w),
        y(v) + y(w),
    };
}

/// Element-wise subtraction
pub fn sub(v: V2, w: V2) V2 {
    return .{
        x(v) - x(w),
        y(v) - y(w),
    };
}

/// Element-wise multiplication
pub fn mul(v: V2, w: V2) V2 {
    return .{
        x(v) * x(w),
        y(v) * y(w),
    };
}

/// Element-wise division
pub fn div(v: V2, w: V2) V2 {
    return .{
        x(v) / x(w),
        y(v) / y(w),
    };
}

/// The perpendicular vector, counter clock-wise
pub fn normal(v: V2) V2 {
    return .{
        -y(v),
        x(v),
    };
}

/// The vector in the same direction, of length 1
pub fn unit(v: V2) V2 {
    const length = len(v);
    return .{
        x(v) / length,
        y(v) / length,
    };
}

/// The vector used to get from a to b
pub fn direction(a: V2, b: V2) V2 {
    return .{
        x(b) - x(a),
        y(b) - y(a),
    };
}

/// Linearly interpolate between a and b
pub fn lerp(a: V2, b: V2, t: f32) V2 {
    return .{
        @mulAdd(f32, t, x(b) - x(a), x(a)),
        @mulAdd(f32, t, y(b) - y(a), y(a)),
    };
}

pub fn dot(a: V2, b: V2) f32 {
    return x(a) * x(b) + y(a) * y(b);
}

/// How much to multiply W by to get the projection of V onto W
pub fn rel_scalar_project(v: V2, w: V2) f32 {
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
    const t = @import("std").testing;
    const math = @import("std").math;
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
    return @import("std").math.atan2(dot(a, orth(b)), dot(a, b));
}

/// The signed angle from (1,0) to b
/// CCW positive
/// Between 0 and 2pi
pub fn angleAbs(v: V2) f32 {
    const math = @import("std").math;
    return math.wrap(angle(.{ 1, 0 }, v), math.pi) + math.pi;
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
