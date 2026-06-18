# Advanced-FFmpeg Agent Notes

## Project Shape

- This is an FFAStrans custom processor node.
- Main UI: `index.html`
- UI styles: `style.css`
- Processor script: `bin/processor.ps1`
- Node metadata: `node.json`
- Help page: `help.html`

The UI targets FFAStrans' embedded IE11 environment. Keep JavaScript and CSS IE11-friendly.

## FFmpeg Location Used During Development

Local FFmpeg path provided by the user:

```text
C:\FFAStrans1.4.1\Processors\ffmpeg\x64\ffmpeg.exe
```

Use the sibling `ffprobe.exe` from the same folder for local probing/tests.

## UI Conventions

- Keep the first screen as the actual processor UI, not a landing page.
- Keep CSS in `style.css`; do not reintroduce a large inline `<style>` block in `index.html`.
- `help.html` is a simple FFAStrans-style help page.
- Official FFmpeg documentation source: https://ffmpeg.org/documentation.html
- The official FFmpeg documentation is regenerated nightly and follows the newest FFmpeg revision; when behavior depends on the installed FFmpeg build, verify with the local `ffmpeg.exe`/`ffprobe.exe` help or smoke tests.
- The UI is initialized through `ffas_init`, restored through `ffas_load_preset`, and saved through `ffas_save_preset`.
- When adding a persistent UI field, add its element ID to the `inputFields` array in `ffas_save_preset`.
- FFAStrans variable picker buttons use:

```html
<input type="submit" value=">" name="open_vars" data-parent="SomeElementId" data-user_vars_only="true" />
```

## Important Runtime Rules

- FFAStrans expands `%s_var%` values at execution time.
- `FFmpegPath` may be:
  - a full path to `ffmpeg.exe`
  - an FFmpeg directory
  - an FFAStrans variable such as `%s_var%`
- `bin/processor.ps1` validates the expanded FFmpeg path and expects `ffprobe.exe` next to `ffmpeg.exe`.
- The processor sets `s_source` to the encoded output path.
- On failure, use `Exit-WithError`, which writes `s_job_error_msg`.

## Command Generation Notes

- `updateCommand()` builds the command stored in `GeneratedCommand`; the visible command panel is hidden by default and controlled from the Options tab.
- 2-pass ABR generates two FFmpeg invocations chained with `&&`:
  - pass 1 writes to `NUL`
  - pass 2 writes the final output
- `bin/processor.ps1` injects progress flags into every command-leading `ffmpeg` token, including chained two-pass commands.
- CQ/constant quantizer mode is implemented as FFmpeg `-qp`, not `-cq`.

## Codec-Specific UI Behavior

- The first release started MP4-focused; MOV is now enabled as the next supported container.
- MP4 and MOV codec options should be kept container-aware and tested against the user's local FFmpeg build when possible.
- Color Mode is rebuilt dynamically per selected codec by `updateColorModes()`.
- Do not offer pixel formats that fail or silently downgrade for the selected codec.
- For codecs that have only one safe Color Mode, do not offer `Keep Original`; select the required pixel format so the command emits `-pix_fmt`.
- `Open GOP` lives in the Advanced tab as a `Default` / `On` dropdown.
- `Open GOP` and `Frame-Packing` are only shown for:
  - `libx264`
  - `libx264rgb`
  - `libx265`
- `Open GOP=Default` must not add any FFmpeg option; `Open GOP=On` adds `open-gop=1` through encoder private options.
- x264 uses `-x264opts`.
- x265 uses `-x265-params`.
- Do not pass x264/x265 private options to hardware encoders, ProRes, copy, AV1, VP9, MPEG, or MJPEG codecs.
- `Faststart` lives in the Advanced tab as a `Default` / `On` dropdown for MP4/MOV. `Default` must not add any FFmpeg option; `On` adds `-movflags +faststart`.
- `Brand` lives in the Advanced tab for MP4. `Default` must not add any FFmpeg option; selected values add `-brand` as a final output option.
- `Codec ID` lives in the Advanced tab and is rebuilt per selected MP4 codec. `Default` must not add any FFmpeg option; selected values add `-tag:v`.
- MOV video codecs are currently conservative: H.264, HEVC, ProRes, MPEG-4 Part 2, MJPEG, and copy.
- In the MOV video codec dropdown, ProRes should appear first because it is a common MOV mastering choice.
- MP4 and MOV offer `VideoCodec=none` for audio-only output; command generation emits `-vn` and video-only controls should be hidden.
- ProRes uses `prores_ks`; do not emit generic CRF/ABR/2-pass options or x264/x265 private options for ProRes.
- ProRes profile choices are Proxy, LT, Standard, HQ, 4444, and 4444 XQ; Standard is selected by default and emits `-profile:v standard`.
- `Force CFR` lives in the Advanced tab as a `Default` / `On` dropdown. `Default` must not add any FFmpeg option; `On` adds `-vsync cfr`.

## Audio Behavior

- MP4 audio codecs include native AAC, optional external `libfdk_aac`, MP3, AC-3, E-AC-3, ALAC, copy, and no audio.
- MOV audio codecs include native AAC, optional external `libfdk_aac`, ALAC, PCM 16-bit, PCM 24-bit, AC-3, E-AC-3, copy, and no audio.
- ALAC and PCM disable bitrate because they are lossless/uncompressed.
- Audio track name writes `-metadata:s:a:0 title=...`.
- Positive audio delay for encoded audio uses `-af adelay=MS:all=1`; delay is not applied to stream-copy audio.
- `AudioDelay` accepts positive numbers, `0`, or FFAStrans variables.
- `AudioTrackName` accepts plain text or FFAStrans variables.

## Options / Preset JSON

- Presets include `presetSchemaVersion`.
- `ffas_save_preset()` still returns base64-encoded JSON for FFAStrans.
- The Options tab exports readable JSON to a file and imports readable JSON from a file using the same schema.
- Opening the Options tab should refresh the Preset JSON textarea from the current UI values.
- Reject presets with a newer `presetSchemaVersion` than the UI supports.
- The Options tab should stay on the right side of the tab bar.
- Do not re-add the visible FFAStrans Output Variables section; processor outputs are written by `bin/processor.ps1`.

## Video Filters

- Scale uses the visible label `Scale`.
- Watermark is an image overlay filter. It adds the watermark image as input 1 and uses `-filter_complex` with `[vout]`.
- The visible watermark path label is `Image path`.
- Watermark image paths should validate common FFmpeg image extensions: PNG, JPG/JPEG, BMP/DIB, TIFF, TGA, GIF, and WEBP. FFAStrans variable paths such as `%s_var%` are allowed because they expand during execution.
- Watermark position uses a 3x3 radio grid like timecode, stored in `WatermarkPosition`.
- `WatermarkXOffset` and `WatermarkYOffset` accept numbers or FFAStrans variables.
- Watermark resize is applied after the base video filter chain, so `fit source` uses the post-Scale dimensions.
- Watermark requires video re-encoding and should be hidden/ignored when `VideoCodec=copy`.
- When watermark uses `-filter_complex`, map filtered video with `-map "[vout]"` and optional source audio with `-map 0:a?`.

## Numeric Variable Fields

- `KeyframeInt`, `MinGOP`, `Threads`, and `AudioDelay` accept numbers or FFAStrans variables.
- When `0` means FFmpeg default, clicking into the field clears the `0`; blank or `0` must not emit an FFmpeg option.
- FFAStrans variable picker buttons placed after inputs use `<`.

## Timecode Behavior

- Timecode burn-in uses FFmpeg `drawtext`.
- `TCFont` uses a basic built-in list of common Windows 7-era font file paths plus `Custom`; do not enumerate local files from the UI.
- `TCFont=Default` must not add a font option.
- Built-in font choices add `fontfile='...'` to `drawtext`.
- Built-in font choices are Arial, Calibri, Consolas, Courier New, and Tahoma.
- Custom installed font names add `font='...'`; no extension is needed for installed font names.
- Custom full font paths add `fontfile='...'`; full paths should include the font extension such as `.ttf`, `.otf`, or `.ttc`.
- Sort `AudioLanguage` by visible language name, not ISO code.
- If `Use original media start timecode` is checked, the UI inserts `__SOURCE_TC__` into the command.
- `bin/processor.ps1` replaces `__SOURCE_TC__` at execution by probing source timecode with `ffprobe`.
- The visible label for `TCStart` is `Start Timecode`.
- `TCStart` accepts only timecode values like `00:00:00:00` or `00:00:00;00`; empty values reset to `00:00:00:00` on change.
- If no valid source timecode is found, `TCSourceFallback` controls behavior:
  - `zero`: start from `00:00:00:00`
  - `manual`: use the `TCStart` field
- If manual fallback is selected but `TCStart` is invalid, processor falls back to `00:00:00:00`.
- `If no source timecode` is hidden unless `Use original media start timecode` is checked.
- The visible label for `TCSize` is `Timecode Size`.
- Custom timecode size is a read-only percent value adjusted with `+` / `-` buttons in steps of `1`.

## Validation Notes

- Custom framerate accepts only:
  - decimal/integer values like `25` or `23.976`
  - rational values like `24000/1001`
  - FFAStrans variables like `%s_var%`
- Invalid custom framerate values are not added to the generated command.
- Field hints use `.ffas-field-hint`; error styling uses `.ffas-input-error`.

## Help Popup

- Inline `[?]` native title tooltips were replaced by a centered modal-style popup.
- Popup CSS lives in `style.css`.
- Keep the help button modern and readable; popup body text should stay large enough to read comfortably.
- Most UI option help is attached dynamically by `initOptionHelp()` from `OPTION_HELP_ITEMS`.
- Option help popups should include short local guidance and a direct official FFmpeg documentation link when the option maps to FFmpeg behavior.
- UI-only options such as Theme, Preset JSON, and command preview visibility should not show a fake FFmpeg documentation link.
- Help buttons should appear after the option control, or after the final FFAStrans variable/file picker button for that control, rather than beside the label.
- Documentation links in help popups should attempt to open normally and copy the URL to the clipboard with visible feedback when the host browser allows it.
- Popup functions:
  - `toggleHelpPopup`
  - `closeHelpPopups`
  - `getHelpOverlay`
- It should remain IE11-friendly.

## Verification

Useful checks:

```powershell
$tokens=$null; $errors=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile('bin\processor.ps1',[ref]$tokens,[ref]$errors); $errors
```

If available, use the provided FFmpeg path to probe encoder/container behavior rather than guessing.

## Editing Preferences

- Keep edits scoped.
- After each change, bump `node.json` version and add a dated entry to `CHANGELOG.md`.
- Do not revert user changes or backup HTML copies.
- Prefer explicit, readable IE11-compatible JavaScript over modern syntax.
- Avoid adding dependencies.
