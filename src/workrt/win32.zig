const std = @import("std");
const root = @import("root");
const w32 = @import("../bindings/win32.zig");
const wic = @import("../bindings/wincodec.zig");

wicfac: *wic.IWICImagingFactory,

pub fn init() !@This() {
    const wicfac = try w32.com.create(wic.IWICImagingFactory, &wic.IWICImagingFactory.CLSID);
    return .{ .wicfac = wicfac };
}

pub fn deinit(self: *@This()) void {
    _ = self.wicfac.Unknown.Release();
}

/// The following will be allocated and given to the caller:
/// - The image buffer data
pub fn load_image(
    self: *@This(),
    path: [:0]const u8,
    allocator: std.mem.Allocator,
) !root.ImageBuffer {
    const pathw = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, path);
    defer allocator.free(pathw);

    const decoder = try self.wicfac.ImagingFactory.CreateDecoderFromFilename(
        pathw,
        null,
        .{ .read = true },
        .{ .cache_metadata_on_load = true },
    );
    defer _ = decoder.Unknown.Release();

    const frame = try decoder.BitmapDecoder.GetFrame(0);
    defer _ = frame.Unknown.Release();

    const conv = try self.wicfac.ImagingFactory.CreateFormatConverter();
    defer _ = conv.Unknown.Release();
    try conv.FormatConverter.Initialize(
        @as(*wic.IWICBitmapSource, @ptrCast(frame)),
        &wic.GUID_WICPixelFormat32bppRGBA,
        .none,
        null,
        0.0,
        0,
    );

    const size = try conv.BitmapSource.GetSize();

    const imgbfr = try allocator.alloc(u8, size.width * size.height * 4);
    errdefer allocator.free(imgbfr);

    try conv.BitmapSource.CopyPixels(null, size.width * 4, imgbfr);

    return .{ .width = size.width, .height = size.height, .buffer = imgbfr };
}
