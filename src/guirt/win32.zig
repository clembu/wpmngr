const std = @import("std");
const dx = @import("../bindings/directx.zig");
const w32 = @import("../bindings/win32.zig");
const imgui = @import("../bindings/imgui.zig");

dev: *dx.ID3D11Device,
devctx: *dx.ID3D11DeviceContext,
mainRTV: *dx.ID3D11RenderTargetView,
sc: *dx.IDXGISwapChain,
imctx: imgui.Context,

pub fn init(allocator: std.mem.Allocator, hwnd: w32.HWND) !@This() {
    const sc, const dev, const devctx = try dx.createDeviceAndSwapChain(.{
        .BufferCount = 2,
        .BufferDesc = .{
            .Width = 0,
            .Height = 0,
            .Format = .R8G8B8A8_UNORM,
            .RefreshRate = .{
                .Numerator = 30,
                .Denominator = 1,
            },
            .Scaling = .UNSPECIFIED,
            .ScanlineOrdering = .UNSPECIFIED,
        },
        .Flags = .{ .ALLOW_MODE_SWITCH = true },
        .BufferUsage = .{ .RENDER_TARGET_OUTPUT = true },
        .OutputWindow = hwnd,
        .SampleDesc = .{
            .Count = 1,
            .Quality = 0,
        },
        .Windowed = w32.TRUE,
        .SwapEffect = .DISCARD,
    }, .{
        .driver_type = .HARDWARE,
    });
    errdefer _ = sc.Unknown.Release();
    errdefer _ = devctx.Unknown.Release();
    errdefer _ = dev.Unknown.Release();

    const rtv = blk: {
        const backbfr = try sc.SwapChain.GetBuffer(dx.ID3D11Texture2D, 0);
        defer _ = backbfr.Unknown.Release();
        break :blk try dev.Device.CreateRenderTargetView(@ptrCast(backbfr), null);
    };
    errdefer _ = rtv.Unknown.Release();

    const imctx = try imgui.init(
        allocator,
        .{ .hwnd = hwnd, .device = dev, .device_context = devctx },
    );

    return .{
        .dev = dev,
        .devctx = devctx,
        .sc = sc,
        .mainRTV = rtv,
        .imctx = imctx,
    };
}

pub fn deinit(self: *@This()) void {
    imgui.deinit(self.imctx);
    _ = self.mainRTV.Unknown.Release();
    _ = self.sc.Unknown.Release();
    _ = self.devctx.Unknown.Release();
    _ = self.dev.Unknown.Release();
}

// Frees `buffer` with the runtime's allocator.
// fn upload_texture(self: *@This(), width: u32, height: u32, buffer: []const u8) !Image {
//     var desc = std.mem.zeroes(dx.D3D11_TEXTURE2D_DESC);
//     desc.Width = width;
//     desc.Height = height;
//     desc.MipLevels = 0;
//     desc.ArraySize = 1;
//     desc.Format = .R8G8B8A8_UNORM;
//     desc.SampleDesc.Count = 1;
//     desc.Usage = .DEFAULT;
//     desc.BindFlags = .{ .SHADER_RESOURCE = true, .RENDER_TARGET = true };
//     desc.MiscFlags = .{ .GENERATE_MIPS = true };
//
//     const texture = try self.dev.Device.CreateTexture2D(&desc, null);
//     defer _ = texture.Unknown.Release();
//
//     const t = try self.dev.Device.CreateShaderResourceView(@ptrCast(texture), &desc);
//
//     self.devctx.DeviceContext.UpdateSubresource(
//         @ptrCast(texture),
//         0,
//         null,
//         @ptrCast(buffer.ptr),
//         width * 4,
//         height * width * 4,
//     );
//
//     self.allocator.free(buffer);
//
//     const fmt_support = try self.dev.Device.CheckFormatSupport(desc.Format);
//
//     if (fmt_support.mip_autogen) {
//         self.devctx.DeviceContext.GenerateMips(t);
//     } else {
//         std.log.warn("We do not support mip gen", .{});
//     }
//
//     const sampler = try self.dev.Device.CreateSamplerState(&.{
//         .MinLOD = 0,
//         .MaxLOD = 14,
//         .MipLODBias = 0,
//         .MaxAnisotropy = 16,
//         .ComparisonFunc = .equal,
//         .BorderColor = @splat(0),
//         .AddressW = .clamp,
//         .AddressV = .clamp,
//         .AddressU = .clamp,
//         .Filter = .min_linear_mag_point_mip_linear,
//     });
//
//     return .{
//         .txid = t,
//         .dims = .{
//             @floatFromInt(width),
//             @floatFromInt(height),
//         },
//         .sampler = sampler,
//     };
// }
// const Image = @import("image.zig");
