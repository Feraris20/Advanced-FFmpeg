# Advanced-FFmpeg Notes
On  Apple Prores  these should be hidden.
Rate Control:  
Encoding Preset: 
Add  a  dry-run
Export  a  test still
Add  a sample output from  with X seconds  from  this time  to this  time.

## Dynamic FFmpeg Capability Detection

Goal: when a user provides an external FFmpeg build, discover what that build supports so the UI can offer only valid encoders, pixel formats, muxers, filters, and possibly codec-private options.

### Can the processor be triggered from inside the processor?

Not in a useful UI-discovery way. When `bin/processor.ps1` is running, the processor has already been triggered by FFAStrans. From there it can run child processes such as `ffmpeg.exe`, `ffprobe.exe`, or helper PowerShell scripts, but it should not try to trigger the same FFAStrans processor/node again. That would be re-entrant, hard to reason about, and probably outside the intended FFAStrans node lifecycle.

The safer design is:

- The processor can probe FFmpeg during execution.
- The processor can write discovered capabilities to `outputs.json` or to a separate capability cache JSON file.
- A later UI/session can import or read that capability JSON if the host environment allows it.

### Practical Ways To Obtain Capabilities

1. **Processor execution probe**
   - During a real job, run commands like:
     - `ffmpeg -hide_banner -encoders`
     - `ffmpeg -hide_banner -muxers`
     - `ffmpeg -hide_banner -pix_fmts`
     - `ffmpeg -hide_banner -filters`
     - `ffmpeg -hide_banner -h encoder=libx264`
   - Parse the output in PowerShell.
   - Write a compact JSON summary beside the job output or into `outputs.json`.
   - Strong point: works without browser security tricks.
   - Weak point: the UI learns capabilities only after a run, unless we add import/cache behavior.

2. **Manual capability import**
   - Provide a helper script that writes `ffmpeg-capabilities.json`.
   - Add an Options-tab import button later.
   - Strong point: keeps the main UI simple and IE11-safe.
   - Weak point: user must run/import the file.

3. **ActiveX probe in a separate test HTML**
   - In FFAStrans' embedded IE environment, ActiveX may be allowed depending on security settings.
   - A test page can use `WScript.Shell.Exec()` to run FFmpeg and display the detected output.
   - Strong point: gives immediate UI-time discovery if allowed.
   - Weak point: often blocked by IE security policy, should not be used in the main UI unless the environment proves it is safe and reliable.

4. **FFAStrans-provided bridge, if available**
   - If FFAStrans exposes a supported browser-to-host function for running tools or reading files, use that instead of ActiveX.
   - This would be preferable, but needs confirmation from FFAStrans documentation or testing.

### Recommended Direction

For the first release, keep MP4 choices conservative and static. For a later dynamic build, start with a processor/helper PowerShell probe that creates `ffmpeg-capabilities.json`, then add an import path in the Options tab. ActiveX should remain a separate experiment until we prove it works consistently in the target FFAStrans environment.
