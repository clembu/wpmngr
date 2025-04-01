const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const vec = @import("vec.zig");

txid: imgui.TextureID,
dims: vec.V2,
sampler: ?*imgui.backend.Sampler,
