Add-Type @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class ProcessKillJob
{
    const int JobObjectExtendedLimitInformation = 9;
    const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateJobObject(IntPtr attributes, string name);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetInformationJobObject(
        IntPtr job,
        int infoClass,
        IntPtr info,
        uint infoLength
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AssignProcessToJobObject(
        IntPtr job,
        IntPtr process
    );

    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr handle);

    [StructLayout(LayoutKind.Sequential)]
    struct IO_COUNTERS
    {
        public ulong ReadOperationCount;
        public ulong WriteOperationCount;
        public ulong OtherOperationCount;
        public ulong ReadTransferCount;
        public ulong WriteTransferCount;
        public ulong OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_BASIC_LIMIT_INFORMATION
    {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
    {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    public static IntPtr Create()
    {
        IntPtr job = CreateJobObject(IntPtr.Zero, null);

        if (job == IntPtr.Zero)
            throw new Win32Exception(Marshal.GetLastWin32Error());

        var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        info.BasicLimitInformation.LimitFlags =
            JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

        int size = Marshal.SizeOf(
            typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION)
        );

        IntPtr pointer = Marshal.AllocHGlobal(size);

        try
        {
            Marshal.StructureToPtr(info, pointer, false);

            if (!SetInformationJobObject(
                job,
                JobObjectExtendedLimitInformation,
                pointer,
                (uint)size))
            {
                throw new Win32Exception(
                    Marshal.GetLastWin32Error()
                );
            }
        }
        finally
        {
            Marshal.FreeHGlobal(pointer);
        }

        return job;
    }

    public static void AddProcess(IntPtr job, IntPtr process)
    {
        if (!AssignProcessToJobObject(job, process))
        {
            throw new Win32Exception(
                Marshal.GetLastWin32Error()
            );
        }
    }
}
"@

Write-Output "Starting Advanced-FFmpeg"

if ($args.Count -lt 1 -or -not (Test-Path -LiteralPath $args[0] -PathType Leaf)) {
    Write-Error "Processor input JSON was not found."
    exit 1
}

try {
    $input_json = Get-Content -Raw -Encoding UTF8 -LiteralPath $args[0] | ConvertFrom-Json
}
catch {
    Write-Error "Could not read processor input JSON: $($_.Exception.Message)"
    exit 1
}

$all_inputs = @($input_json.proc_data.inputs)

if (-not ($input_json.proc_data.PSObject.Properties.Name -contains "outputs")) {
    $input_json.proc_data | Add-Member -NotePropertyName outputs -NotePropertyValue @()
}
elseif ($null -eq $input_json.proc_data.outputs) {
    $input_json.proc_data.outputs = @()
}

function Get-InputValue([string]$Id) {
    $item = $all_inputs | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if ($null -eq $item -or $null -eq $item.value) { return "" }
    return [string]$item.value
}

function Add-ProcessorOutput([string]$Name, [string]$Data) {
    $input_json.proc_data.outputs += [pscustomobject]@{
        value = $Name
        data  = $Data
    }
}

function Write-ProcessorJson {
    $input_json | ConvertTo-Json -Depth 100 |
    Out-File -Encoding UTF8 -LiteralPath $input_json.processor_output_filepath
}

function Exit-WithError([string]$Message) {
    Write-Error $Message
    Add-ProcessorOutput "s_job_error_msg" $Message
    Write-ProcessorJson
    exit 1
}

function Convert-ToDouble($Value) {
    $number = 0.0
    [double]::TryParse(
        [string]$Value,
        [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture,
        [ref]$number
    ) | Out-Null
    return $number
}

function Convert-ToFps($Value) {
    $text = ([string]$Value).Trim()

    if ($text -match '^([0-9.]+)\/([0-9.]+)$') {
        $numerator = Convert-ToDouble $matches[1]
        $denominator = Convert-ToDouble $matches[2]
        if ($denominator -ne 0) { return $numerator / $denominator }
    }

    return Convert-ToDouble $text
}

function Get-ValidFpsText($PrimaryValue, $FallbackValue) {
    $primaryText = ([string]$PrimaryValue).Trim()

    if (-not [string]::IsNullOrWhiteSpace($primaryText) -and
        $primaryText -ne "0/0" -and
        (Convert-ToFps $primaryText) -gt 0) {
        return $primaryText
    }

    $fallbackText = ([string]$FallbackValue).Trim()

    if (-not [string]::IsNullOrWhiteSpace($fallbackText) -and
        $fallbackText -ne "0/0" -and
        (Convert-ToFps $fallbackText) -gt 0) {
        return $fallbackText
    }

    return "25"
}

function Format-Eta($Seconds) {
    $Seconds = [Math]::Max(0, [Math]::Ceiling($Seconds))
    $hours = [Math]::Floor($Seconds / 3600)
    $minutes = [Math]::Floor(($Seconds % 3600) / 60)
    $secondsPart = $Seconds % 60
    return "{0:00}:{1:00}:{2:00}" -f $hours, $minutes, $secondsPart
}

function Get-ProgressSeconds($ProgressData) {
    if ($ProgressData.ContainsKey("out_time")) {
        $timeSpan = [TimeSpan]::Zero
        if ([TimeSpan]::TryParse(
                [string]$ProgressData["out_time"],
                [Globalization.CultureInfo]::InvariantCulture,
                [ref]$timeSpan
            )) {
            return [Math]::Max(0, $timeSpan.TotalSeconds)
        }
    }

    if ($ProgressData.ContainsKey("out_time_us")) {
        return [Math]::Max(0, (Convert-ToDouble $ProgressData["out_time_us"]) / 1000000)
    }

    if ($ProgressData.ContainsKey("out_time_ms")) {
        return [Math]::Max(0, (Convert-ToDouble $ProgressData["out_time_ms"]) / 1000000)
    }

    return 0
}

function Convert-ToDrawtextTimecode([string]$Timecode) {
    return $Timecode.Trim() -replace ':', '\:'
}

function Test-TimecodeFormat([string]$Timecode) {
    return $Timecode -match '^\d{1,2}:\d{2}:\d{2}[:;]\d{2,3}$'
}

function Get-TimecodeFallback([string]$Mode, [string]$ManualTimecode) {
    if ($Mode -eq "manual" -and (Test-TimecodeFormat $ManualTimecode)) {
        return $ManualTimecode.Trim()
    }

    if ($Mode -eq "manual") {
        Write-Output "Manual Start TC is empty or unsupported. Falling back to 00:00:00:00."
    }

    return "00:00:00:00"
}

function Get-FirstTimecodeFromProbe($ProbeData) {
    if ($null -eq $ProbeData) { return "" }

    if (
        $ProbeData.PSObject.Properties.Name -contains "format" -and
        $null -ne $ProbeData.format.tags -and
        $ProbeData.format.tags.PSObject.Properties.Name -contains "timecode"
    ) {
        return [string]$ProbeData.format.tags.timecode
    }

    foreach ($probeStream in @($ProbeData.streams)) {
        if (
            $null -ne $probeStream.tags -and
            $probeStream.tags.PSObject.Properties.Name -contains "timecode"
        ) {
            return [string]$probeStream.tags.timecode
        }
    }

    return ""
}

# Values saved by the custom processor UI
$s_FFmpegPath = (Get-InputValue "FFmpegPath").Trim().Trim('"')
$s_GeneratedCommand = (Get-InputValue "GeneratedCommand").Trim()
$s_SourceFilePath = (Get-InputValue "SourceFilePath").Trim().Trim('"')
$s_OutputFilePath = (Get-InputValue "OutputFilePath").Trim().Trim('"')
$s_FramerateMode = (Get-InputValue "Framerate").Trim()
$s_FramerateCustom = (Get-InputValue "FramerateCustom").Trim()
$s_TCStart = (Get-InputValue "TCStart").Trim()
$s_TCSourceFallback = (Get-InputValue "TCSourceFallback").Trim()
$s_SuccessMessage = (Get-InputValue "successmsg").Trim()

if ([string]::IsNullOrWhiteSpace($s_TCSourceFallback)) {
    $s_TCSourceFallback = "zero"
}

if ([string]::IsNullOrWhiteSpace($s_FFmpegPath)) {
    Exit-WithError "FFmpeg path is empty or missing."
}
if ([string]::IsNullOrWhiteSpace($s_GeneratedCommand)) {
    Exit-WithError "Generated command is empty or missing."
}
if ([string]::IsNullOrWhiteSpace($s_SourceFilePath) -or $s_SourceFilePath -match '%s_[^%]+%') {
    Exit-WithError "Source file path is empty or was not expanded by FFAStrans."
}
if ([string]::IsNullOrWhiteSpace($s_OutputFilePath) -or $s_OutputFilePath -match '%s_[^%]+%') {
    Exit-WithError "Output file path is empty or was not expanded by FFAStrans."
}
if (-not (Test-Path -LiteralPath $s_SourceFilePath -PathType Leaf)) {
    Exit-WithError "Source file was not found: $s_SourceFilePath"
}

# Accept either an FFmpeg directory or the full path to ffmpeg.exe
if (Test-Path -LiteralPath $s_FFmpegPath -PathType Leaf) {
    $ffmpegExe = (Resolve-Path -LiteralPath $s_FFmpegPath).Path
    $ffmpegDir = Split-Path -Parent $ffmpegExe
}
else {
    $ffmpegDir = $s_FFmpegPath
    $ffmpegExe = Join-Path $ffmpegDir "ffmpeg.exe"
}

if (-not (Test-Path -LiteralPath $ffmpegExe -PathType Leaf)) {
    Exit-WithError "FFmpeg was not found: $ffmpegExe"
}

$ffmpegExe = (Resolve-Path -LiteralPath $ffmpegExe).Path
$ffmpegDir = Split-Path -Parent $ffmpegExe
$ffprobeExe = Join-Path $ffmpegDir "ffprobe.exe"

if (-not (Test-Path -LiteralPath $ffprobeExe -PathType Leaf)) {
    Exit-WithError "ffprobe.exe was not found: $ffprobeExe"
}

Set-Location -LiteralPath $ffmpegDir
Write-Output "FFmpeg executable: $ffmpegExe"
Write-Output "Reading source metadata..."

$probeOutput = & $ffprobeExe `
    -v error `
    -select_streams v:0 `
    -show_entries "stream=nb_frames,avg_frame_rate,r_frame_rate,duration:format=duration" `
    -of json `
    "$s_SourceFilePath" 2>&1

if ($LASTEXITCODE -ne 0) {
    Exit-WithError "ffprobe failed: $(($probeOutput | Out-String).Trim())"
}

try {
    $probe = (($probeOutput | Out-String) | ConvertFrom-Json)
}
catch {
    Exit-WithError "Could not parse ffprobe output."
}

if ($s_GeneratedCommand -like "*__SOURCE_TC__*") {
    Write-Output "Reading source timecode..."

    $timecodeProbeOutput = & $ffprobeExe `
        -v error `
        -show_entries "stream_tags=timecode:format_tags=timecode" `
        -of json `
        "$s_SourceFilePath" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "ffprobe timecode lookup failed: $(($timecodeProbeOutput | Out-String).Trim())"
    }

    try {
        $timecodeProbe = (($timecodeProbeOutput | Out-String) | ConvertFrom-Json)
    }
    catch {
        Exit-WithError "Could not parse ffprobe timecode output."
    }

    $sourceTimecode = Get-FirstTimecodeFromProbe $timecodeProbe

    if ([string]::IsNullOrWhiteSpace($sourceTimecode)) {
        $sourceTimecode = Get-TimecodeFallback $s_TCSourceFallback $s_TCStart
        Write-Output "No source timecode was found. Starting timecode from $sourceTimecode."
    }

    if (-not (Test-TimecodeFormat $sourceTimecode)) {
        Write-Output "Source timecode has an unsupported format: $sourceTimecode."
        $sourceTimecode = Get-TimecodeFallback $s_TCSourceFallback $s_TCStart
        Write-Output "Starting timecode from $sourceTimecode."
    }

    $drawtextTimecode = Convert-ToDrawtextTimecode $sourceTimecode
    $s_GeneratedCommand = $s_GeneratedCommand.Replace("__SOURCE_TC__", $drawtextTimecode)
    Write-Output "Source timecode: $sourceTimecode"
}

$stream = @($probe.streams)[0]

if ($null -eq $stream) {
    Exit-WithError "No video stream was found."
}

$duration = Convert-ToDouble $stream.duration

if ($duration -le 0) {
    $duration = Convert-ToDouble $probe.format.duration
}

$sourceFps = Convert-ToFps $stream.avg_frame_rate

if ($sourceFps -le 0) {
    $sourceFps = Convert-ToFps $stream.r_frame_rate
}

if ($s_GeneratedCommand -like "*__SOURCE_FPS__*") {
    $sourceFpsText = Get-ValidFpsText $stream.avg_frame_rate $stream.r_frame_rate
    $s_GeneratedCommand = $s_GeneratedCommand.Replace("__SOURCE_FPS__", $sourceFpsText)
    Write-Output "Source FPS for timecode: $sourceFpsText"
}

$outputFps = $sourceFps

if ($s_FramerateMode -eq "custom") {
    $selectedFps = Convert-ToFps $s_FramerateCustom

    if ($selectedFps -gt 0) {
        $outputFps = $selectedFps
    }
}
elseif (-not [string]::IsNullOrWhiteSpace($s_FramerateMode)) {
    $selectedFps = Convert-ToFps $s_FramerateMode

    if ($selectedFps -gt 0) {
        $outputFps = $selectedFps
    }
}

$totalFrames = 0L

if ($duration -gt 0 -and $outputFps -gt 0) {
    $totalFrames = [long][Math]::Round($duration * $outputFps)
}

Write-Output (
    "Estimated: {0:N0} frames | Duration: {1:N2}s | FPS: {2:N3}" -f `
        $totalFrames,
    $duration,
    $outputFps
)

# Replace each command-leading ffmpeg token with progress options.
$commandMatch = [regex]::Match(
    $s_GeneratedCommand,
    '^\s*"?ffmpeg(?:\.exe)?"?',
    [Text.RegularExpressions.RegexOptions]::IgnoreCase
)

if (-not $commandMatch.Success) {
    Exit-WithError "Generated command does not begin with ffmpeg."
}

Add-ProcessorOutput "s_ffmpeg_command" $s_GeneratedCommand
Write-ProcessorJson
Write-Output "Resolved FFmpeg command was written to processor outputs."

$progressPrefix = 'ffmpeg -hide_banner -loglevel error -nostdin -nostats -stats_period 1.7 -progress pipe:1'
$progressCommand = [regex]::Replace(
    $s_GeneratedCommand,
    '(^|\s&&\s)"?ffmpeg(?:\.exe)?"?',
    '${1}' + $progressPrefix,
    [Text.RegularExpressions.RegexOptions]::IgnoreCase
)

$progressData = @{}
$errorLines = New-Object 'System.Collections.Generic.List[string]'
$lastPercent = -1
$lastFrame = -1L

Write-Output "Running Advanced-FFmpeg..."

$jobHandle = [IntPtr]::Zero
$ffmpegProcess = $null

try {
    $jobHandle = [ProcessKillJob]::Create()

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $env:ComSpec
    $processInfo.Arguments = '/D /S /C "' + $progressCommand + ' 2>&1"'
    $processInfo.WorkingDirectory = $ffmpegDir
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true

    $ffmpegProcess = New-Object System.Diagnostics.Process
    $ffmpegProcess.StartInfo = $processInfo

    if (-not $ffmpegProcess.Start()) {
        Exit-WithError "Could not start FFmpeg."
    }

    [ProcessKillJob]::AddProcess(
        $jobHandle,
        $ffmpegProcess.Handle
    )

    while (
        ($line = $ffmpegProcess.StandardOutput.ReadLine()) -ne $null
    ) {
        $line = [string]$line

        # Keep your existing progress parsing code here
        if ($line -match '^([A-Za-z0-9_]+)=(.*)$') {
            $key = $matches[1]
            $value = $matches[2].Trim()

            $progressData[$key] = $value

            if ($key -eq "progress") {
                $isFinished = $value -eq "end"
                $frame = 0L
                [long]::TryParse([string]$progressData["frame"], [ref]$frame) | Out-Null

                $fps = Convert-ToDouble $progressData["fps"]
                $speedText = ([string]$progressData["speed"]).Trim()
                $speedNumber = Convert-ToDouble ($speedText -replace 'x$', '')
                if ([string]::IsNullOrWhiteSpace($speedText)) { $speedText = "N/A" }

                $processedSeconds = Get-ProgressSeconds $progressData
                $percent = 0
                $eta = "--:--:--"
                $finishTime = "--:--:--"

                if ($duration -gt 0) {
                    $percent = [Math]::Min(
                        100,
                        [Math]::Floor(($processedSeconds / $duration) * 100)
                    )
                }
                elseif ($totalFrames -gt 0) {
                    $percent = [Math]::Min(
                        100,
                        [Math]::Floor(($frame / $totalFrames) * 100)
                    )
                }

                if ($speedNumber -gt 0) {
                    $remainingMediaSeconds = [Math]::Max(
                        0,
                        $duration - $processedSeconds
                    )

                    $etaSeconds = $remainingMediaSeconds / $speedNumber
                    $eta = Format-Eta $etaSeconds
                    $finishTime = (Get-Date).AddSeconds($etaSeconds).ToString("HH:mm:ss")
                }

                if ($isFinished) {
                    $percent = 100
                    $eta = "00:00:00"
                    $finishTime = (Get-Date).ToString("HH:mm:ss")
                }

                if ($percent -ne $lastPercent) {
                    Write-Output ("{0}%" -f $percent)
                    $lastPercent = $percent
                }

                if ($frame -ne $lastFrame -or $isFinished) {
                    if ($totalFrames -gt 0) {
                        Write-Output (
                            "{1:N0} / {2:N0} frames, {0}% @ {3:N1} fps, speed {4}, ETA {5} (Finish {6})" -f `
                            $percent,
                            $frame,
                            $totalFrames,
                            $fps,
                            $speedText,
                            $eta,
                            $finishTime
                        )
                    }
                    else {
                        Write-Output (
                            "{0:N0} frames @ {1:N1} fps, speed {2}, ETA {3} (Finish {4})" -f `
                                $frame,
                            $fps,
                            $speedText,
                            $eta,
                            $finishTime
                        )
                    }
                    $lastFrame = $frame
                }

                $progressData = @{}
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($line)) {
            $errorLines.Add($line)
        }
    }
    $ffmpegProcess.WaitForExit()
    $ffmpegExitCode = $ffmpegProcess.ExitCode
}
catch {
    Exit-WithError "Could not run FFmpeg: $($_.Exception.Message)"
}
finally {
    if ($jobHandle -ne [IntPtr]::Zero) {
        [ProcessKillJob]::CloseHandle($jobHandle) | Out-Null
    }

    if ($ffmpegProcess) {
        $ffmpegProcess.Dispose()
    }
}

if ($ffmpegExitCode -ne 0) {
    $errorDetail = ($errorLines | Select-Object -Last 10) -join " | "

    Exit-WithError (
        "FFmpeg failed with exit code $ffmpegExitCode. $errorDetail"
    )
}

if (-not (Test-Path -LiteralPath $s_OutputFilePath -PathType Leaf)) {
    Exit-WithError "FFmpeg completed, but output file was not found: $s_OutputFilePath"
}

$s_OutputFilePath = (Resolve-Path -LiteralPath $s_OutputFilePath).Path
if ($lastPercent -lt 100) { Write-Output "100%" }

Add-ProcessorOutput "s_source" $s_OutputFilePath
if ([string]::IsNullOrWhiteSpace($s_SuccessMessage)) {
    $s_SuccessMessage = "Advanced-FFmpeg completed successfully."
}
Add-ProcessorOutput "s_success" $s_SuccessMessage
Write-ProcessorJson

Write-Output "Done"
exit 0
