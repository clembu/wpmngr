const w32 = @import("win32.zig");

pub const WICDecodeOptions = packed struct(w32.DWORD) {
    cache_metadata_on_load: bool = false,
    _unused_2_32: u31 = 0,
};

pub const WICBitmapDitherType = enum(w32.DWORD) {
    none = 0,
    ordered4x4 = 0x1,
    ordered8x8 = 0x2,
    ordered16x16 = 0x3,
    spiral4x4 = 0x4,
    spiral8x8 = 0x5,
    dualSpiral4x4 = 0x6,
    dualSpiral8x8 = 0x7,
    errorDiffusion = 0x8,
};

pub const WICBitmapPaletteType = w32.DWORD;

pub const GUID_WICPixelFormat32bppRGBA = w32.GUID.parse("{f5c7ad2d-6a8d-43dd-a7a8-a29935261ae9}");

pub const WICRect = extern struct {
    x: w32.UINT,
    y: w32.UINT,
    width: w32.UINT,
    height: w32.UINT,
};

// Interfaces

pub const IWICImagingFactory = extern struct {
    __v: *const VTable,

    ImagingFactory: Mixin(@This()) = .{},
    Unknown: w32.IUnknown.Mixin(@This()) = .{},

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub fn CreateDecoderFromFilename(
                m: *@This(),
                filename: w32.LPCWSTR,
                vendor: ?*const w32.GUID,
                access: packed struct(w32.DWORD) {
                    _unused_0_30: u30 = 0,
                    write: bool = false,
                    read: bool = false,
                },
                options: WICDecodeOptions,
            ) !*IWICBitmapDecoder {
                const self: *T = @alignCast(@fieldParentPtr("ImagingFactory", m));
                const vt: *const IWICImagingFactory.VTable = @ptrCast(self.__v);
                const ctx: *IWICImagingFactory = @ptrCast(self);
                const decoder: ?*IWICBitmapDecoder = null;
                const hr = vt.CreateDecoderFromFilename(
                    ctx,
                    filename,
                    vendor,
                    @bitCast(access),
                    options,
                    &decoder,
                );
                if (!w32.SUCCEEDED(hr)) {
                    return error.CreateDecoder;
                }
                return decoder.?;
            }

            pub fn CreateFormatConverter(
                m: *@This(),
            ) !*IWICFormatConverter {
                const self: *T = @alignCast(@fieldParentPtr("ImagingFactory", m));
                const vt: *const IWICImagingFactory.VTable = @ptrCast(self.__v);
                const ctx: *IWICImagingFactory = @ptrCast(self);
                var converter: ?*IWICFormatConverter = null;
                const hr = vt.CreateFormatConverter(ctx, &converter);
                if (!w32.SUCCEEDED(hr)) {
                    return error.CreateFormatConverter;
                }
                return converter.?;
            }
        };
    }

    pub const IID = w32.GUID.parse("{ec5ec8a9-c395-4314-9c77-54d7a935ff70}");
    pub const CLSID = w32.GUID.parse("{cacaf262-9370-4615-a13b-9f5539da4c0a}");
    pub const VTable = extern struct {
        const T = IWICImagingFactory;
        base: w32.IUnknown.VTable,
        CreateDecoderFromFilename: *const fn (*T, w32.LPCWSTR, ?*const w32.GUID, w32.DWORD, WICDecodeOptions, *?*IWICBitmapDecoder) callconv(.winapi) w32.HRESULT,
        CreateDecoderFromStream: *anyopaque,
        CreateDecoderFromFileHandle: *anyopaque,
        CreateComponentInfo: *anyopaque,
        CreateDecoder: *anyopaque,
        CreateEncoder: *anyopaque,
        CreatePalette: *anyopaque,
        CreateFormatConverter: *const fn (*T, *?*IWICFormatConverter) callconv(.winapi) w32.HRESULT,
        CreateBitmapScaler: *anyopaque,
        CreateBitmapClipper: *anyopaque,
        CreateBitmapFlipRotator: *anyopaque,
        CreateStream: *anyopaque,
        CreateColorContext: *anyopaque,
        CreateColorTransformer: *anyopaque,
        CreateBitmap: *anyopaque,
        CreateBitmapFromSource: *anyopaque,
        CreateBitmapFromSourceRect: *anyopaque,
        CreateBitmapFromMemory: *anyopaque,
        CreateBitmapFromHBITMAP: *anyopaque,
        CreateBitmapFromHICON: *anyopaque,
        CreateComponentEnumerator: *anyopaque,
        CreateFastMetadataEncoderFromDecoder: *anyopaque,
        CreateFastMetadataEncoderFromFrameDecode: *anyopaque,
        CreateQueryWriter: *anyopaque,
        CreateQueryWriterFromReader: *anyopaque,
    };
};

pub const IWICBitmapDecoder = extern struct {
    __v: *const VTable,

    BitmapDecoder: Mixin(@This()) = .{},
    Unknown: w32.IUnknown.Mixin(@This()) = .{},

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub fn GetFrame(m: *@This(), idx: u32) !*IWICBitmapFrameDecode {
                const self: *T = @alignCast(@fieldParentPtr("BitmapDecoder", m));
                const vt: *const IWICBitmapDecoder.VTable = @ptrCast(self.__v);
                const ctx: *IWICBitmapDecoder = @ptrCast(self);
                var frame: ?*IWICBitmapFrameDecode = null;
                const hr = vt.GetFrame(ctx, idx, &frame);
                if (!w32.SUCCEEDED(hr)) {
                    return error.GetDecoderFrame;
                }
                return frame.?;
            }
        };
    }

    pub const IID = w32.GUID.parse("{9edde9e7-8dee-47ea-99df-e6faf2ed44bf}");
    pub const VTable = extern struct {
        const T = IWICBitmapDecoder;
        base: w32.IUnknown.VTable,
        QueryCapability: *anyopaque,
        Initialize: *anyopaque,
        GetContainerFormat: *anyopaque,
        GetDecoderInfo: *anyopaque,
        CopyPalette: *anyopaque,
        GetMetadataQueryReader: *anyopaque,
        GetPreview: *anyopaque,
        GetColorContexts: *anyopaque,
        GetThumbnail: *anyopaque,
        GetFrameCount: *anyopaque,
        GetFrame: *const fn (*T, w32.UINT, *?*IWICBitmapFrameDecode) callconv(.winapi) w32.HRESULT,
    };
};

pub const IWICBitmapFrameDecode = extern struct {
    __v: *const VTable,

    Unknown: w32.IUnknown.Mixin(@This()) = .{},

    pub const IID = w32.GUID.parse("{3b16811b-6a43-4ec9-a813-3d930c13b940}");
    pub const VTable = extern struct {
        const T = IWICBitmapFrameDecode;
        base: IWICBitmapSource.VTable,
        GetMetadataQueryReader: *anyopaque,
        GetColorContexts: *anyopaque,
        GetThumbnail: *anyopaque,
    };
};

pub const IWICBitmapSource = extern struct {
    __v: *const VTable,

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub fn GetSize(m: *@This()) !struct { width: u32, height: u32 } {
                const self: *T = @alignCast(@fieldParentPtr("BitmapSource", m));
                const vt: *const IWICBitmapSource.VTable = @ptrCast(self.__v);
                const ctx: *IWICBitmapSource = @ptrCast(self);
                var width: u32 = undefined;
                var height: u32 = undefined;
                const hr = vt.GetSize(ctx, &width, &height);
                if (!w32.SUCCEEDED(hr)) {
                    return error.GetSize;
                }
                return .{ .width = width, .height = height };
            }

            pub fn CopyPixels(
                m: *@This(),
                prc: ?*const WICRect,
                cbStride: w32.UINT,
                pbBuffer: []u8,
            ) !void {
                const self: *T = @alignCast(@fieldParentPtr("BitmapSource", m));
                const vt: *const IWICBitmapSource.VTable = @ptrCast(self.__v);
                const ctx: *IWICBitmapSource = @ptrCast(self);
                const hr = vt.CopyPixels(ctx, prc, cbStride, @intCast(pbBuffer.len), pbBuffer.ptr);
                if (!w32.SUCCEEDED(hr)) {
                    return error.CopyPixels;
                }
            }
        };
    }

    pub const IID = w32.GUID.parse("{00000120-a8f2-4877-ba0a-fd2b6645fb94}");
    pub const VTable = extern struct {
        const T = IWICBitmapSource;
        base: w32.IUnknown.VTable,
        GetSize: *const fn (*T, *w32.UINT, *w32.UINT) callconv(.winapi) w32.HRESULT,
        GetPixelFormat: *anyopaque,
        GetResolution: *anyopaque,
        CopyPalette: *anyopaque,
        CopyPixels: *const fn (*T, ?*const WICRect, w32.UINT, w32.UINT, [*]u8) callconv(.winapi) w32.HRESULT,
    };
};

pub const IWICFormatConverter = extern struct {
    __v: *const VTable,

    FormatConverter: Mixin(@This()) = .{},
    BitmapSource: IWICBitmapSource.Mixin(@This()) = .{},
    Unknown: w32.IUnknown.Mixin(@This()) = .{},

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub fn Initialize(
                m: *@This(),
                pISource: *IWICBitmapSource,
                dstFormat: *const w32.GUID,
                dither: WICBitmapDitherType,
                pIPalette: ?*anyopaque,
                alphaThresholdPercent: f64,
                paletteTranslate: WICBitmapPaletteType,
            ) !void {
                const self: *T = @alignCast(@fieldParentPtr("FormatConverter", m));
                const vt: *const IWICFormatConverter.VTable = @ptrCast(self.__v);
                const ctx: *IWICFormatConverter = @ptrCast(self);
                const hr = vt.Initialize(
                    ctx,
                    pISource,
                    dstFormat,
                    dither,
                    pIPalette,
                    alphaThresholdPercent,
                    paletteTranslate,
                );
                if (!w32.SUCCEEDED(hr)) {
                    return error.FormatConverterInitialize;
                }
            }
        };
    }

    pub const IID = w32.GUID.parse("{00000301-a8f2-4877-ba0a-fd2b6645fb94}");
    pub const VTable = extern struct {
        const T = IWICFormatConverter;
        base: IWICBitmapSource.VTable,
        Initialize: *const fn (*T, *IWICBitmapSource, *const w32.GUID, WICBitmapDitherType, ?*anyopaque, f64, WICBitmapPaletteType) callconv(.winapi) w32.HRESULT,
        CanConvert: *anyopaque,
    };
};
