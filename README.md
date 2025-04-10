# Wallpaper Manager

:warning: Work In Progress :warning:

## Features
### The plan

My goal with this project is to have a tool giving its users the ability to:
- Curate several catalogs of images they wish to use as wallpapers
- Specify on each image regions that will be the actual wallpapers (like a cropping tool)
- Annotate each image and wallpaper with arbitrary metadata of their choice
- Query the metadatabase for matching images and wallpapers, or even related metadata
- Save such queries as dynamic wallpaper collections
- Have any number of static or dynamic wallpaper collections populate a pool of random wallpapers in a slideshow

### Current state

#### Build
- [x] Windows build: Win32 API and Directx11 backend
- [ ] Linux build

#### Features
- [x] Image region selection view
- [ ] Static Collections
- [ ] Slideshow
- [ ] Custom data types and relationships
- [ ] Image data annotation
- [ ] Wallpaper data annotation
- [ ] Queries
- [ ] Dynamic collections

## Usage

:warning: Again, this tool is early in its development. Don't expect installers or prebuilt binaries.

### Building
There are currently no build-time dependencies, as far as I can tell.
You should be able to do:
```
zig build wpmngr
```

> [!IMPORTANT]
> I have only built this on a Windows machine so far, and do not currently have any conditional compilation facility in the build steps.
> 
> Regardless of the target you supply, the build will try to produce a Windows executable, and likely expect to build *on* a Windows system.

### Running
Once built, you can call the program and give it a filepath for its sqlite DB, and optionally an image to show a rectangle selection view for.
```
zig-out/bin/wpmngr path/to/test/db [path/to/test/image]
```

## License
The code bundles a copy of [Dear Imgui](https://github.com/ocornut/imgui), which includes it's own license.

The code bundles an amalgamation of [SQLite](https://sqlite.org), which is in the public domain

The rest is licensed as per the LICENSE file.
