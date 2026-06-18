# Advanced-FFmpeg

Advanced-FFmpeg is an FFAStrans custom processor node for building FFmpeg encode commands from a browser-based UI. It focuses on container-aware output creation, codec-safe options, video filters, audio controls, and processor-side runtime expansion.

## Files

- `Advanced-FFmpeg/index.html` - FFAStrans UI.
- `Advanced-FFmpeg/style.css` - UI styles.
- `Advanced-FFmpeg/bin/processor.ps1` - execution processor.
- `Advanced-FFmpeg/node.json` - node metadata and version.
- `Advanced-FFmpeg/help.html` - simple help page.

## Main Features

- Container-aware codec lists for MP4, MOV, MKV, MPEG-TS, and WebM.
- Video encode controls for codec, rate control, bitrate/quality, profile, level, tune, framerate, color mode, GOP, and display mode.
- Video filters for scale, watermark overlay, and timecode burn-in.
- Audio encode controls for codec, sample rate, bitrate, channels, language, track name, and delay.
- Advanced options for hardware acceleration, threads, faststart, brand, codec ID, Force CFR, and extra FFmpeg arguments.
- Options tab with theme selection, preset import/export, generated command visibility, and a compatibility summary.
- Runtime source probing for source timecode and source framerate where needed.
- Runtime metadata date tagging for supported containers.

## FFAStrans Variables

Fields that support FFAStrans variables allow values such as `%s_var%`. FFAStrans expands these during execution. The processor writes the resolved FFmpeg command to outputs before execution.

## External FFmpeg

The FFmpeg path can be:

- A full path to `ffmpeg.exe`
- A directory containing `ffmpeg.exe`
- An FFAStrans variable that expands to either of the above

`ffprobe.exe` is expected next to `ffmpeg.exe`.

## Presets

The Options tab can export and import readable JSON presets. Presets include a schema version so future incompatible preset formats can be rejected safely.

## Development Notes

- Keep JavaScript and CSS compatible with FFAStrans' embedded IE11 environment.
- Keep CSS in `Advanced-FFmpeg/style.css`.
- After every change, bump `Advanced-FFmpeg/node.json` and add a `CHANGELOG.md` entry.
- Validate with the extracted script parse check and the PowerShell parser check before release.
