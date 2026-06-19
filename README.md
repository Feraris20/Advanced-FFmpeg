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
- MP4 and MOV delivery options including faststart, MP4 brand, codec ID, and language metadata.
- Video encode controls for codec, rate control, bitrate/quality, profile, level, tune, framerate, color mode, GOP, and display mode.
- Codec-aware controls for H.264, HEVC, ProRes, AV1, VP9, MPEG-4 Part 2, MPEG-2, MJPEG, copy, and audio-only output where supported by the selected container.
- Video filters for scale, watermark overlay, and timecode burn-in.
- Audio encode controls for codec, sample rate, bitrate, channels, language, track name, and delay.
- Advanced options for hardware acceleration, threads, faststart, brand, codec ID, Force CFR, and extra FFmpeg arguments.
- Options tab with theme selection, preset import/export, generated command visibility, Dry Run controls, and a compatibility summary.
- Runtime source probing for source timecode and source framerate where needed.
- Runtime metadata date tagging for supported containers.
- Optional dry-run execution that writes to FFmpeg's null muxer instead of producing media.
- Optional dry-run batch export for inspecting or re-running the resolved command outside FFAStrans.

## Dry Run

Dry Run changes the generated command to end with `-f null NUL`, so FFmpeg tests decoding, filtering, mapping, and encoding without writing the planned media output.

When dry-run batch export is enabled, the processor writes a resolved `.cmd` file beside the planned output file using the same base filename. In that mode, `s_source` is set to the generated batch file so downstream FFAStrans nodes can receive it. Without batch export, dry-run execution succeeds without producing an output media file.

Dry-run related outputs:

- `s_ffmpeg_command` - the resolved FFmpeg command submitted by the processor.
- `s_dryrun_command` - the resolved null-output command when Dry Run is enabled.
- `s_dryrun_batch` - the generated `.cmd` path when Dry Run Batch is enabled.
- `s_source` - the encoded output path during normal execution, or the dry-run batch file path when batch export is enabled.

## Compatibility Summary

The Options tab includes a read-only compatibility summary for the current settings. It reports the selected container, video/audio codecs, practical delivery settings such as bitrates, languages, sample rate and channels, active filters, dry-run state, and warnings for settings that are ignored or require re-encoding.

## Filters And Timecode

Scale uses FFmpeg's video filter path. Watermark adds an image input and builds a `filter_complex` overlay, including looping image inputs so static and animated watermarks survive longer outputs. Timecode burn-in uses `drawtext` and can use either a manual start timecode or the source media timecode probed at runtime with `ffprobe`.

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

## Runtime Behavior

The processor validates the expanded FFmpeg path, expects `ffprobe.exe` beside `ffmpeg.exe`, resolves runtime placeholders such as source timecode and ISO date metadata, injects progress flags into generated FFmpeg invocations, and writes FFAStrans output variables. On failure it writes `s_job_error_msg`.

## Development Notes

- Keep JavaScript and CSS compatible with FFAStrans' embedded IE11 environment.
- Keep CSS in `Advanced-FFmpeg/style.css`.
- After every change, bump `Advanced-FFmpeg/node.json` and add a `CHANGELOG.md` entry.
- Validate with the extracted script parse check and the PowerShell parser check before release.
