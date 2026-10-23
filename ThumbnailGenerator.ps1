# Video Contact Sheet Generator
# Compatible with Windows PowerShell 5.1
# Requires ffmpeg.exe and ffprobe.exe in PATH

$ErrorActionPreference = "Continue"

$Folder = (Get-Location).Path

$VideoExtensions = @(
    ".mp4", ".mkv", ".avi", ".mov",
    ".wmv", ".m4v", ".webm"
)

$FrameWidth = 480
$FrameHeight = 270
$Columns = 3
$Rows = 2
$FooterHeight = 115

Add-Type -AssemblyName System.Drawing

# Check FFmpeg tools
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: ffmpeg was not found in PATH." -ForegroundColor Red
    exit
}

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: ffprobe was not found in PATH." -ForegroundColor Red
    exit
}

# Find videos in the current folder
$Videos = Get-ChildItem -LiteralPath $Folder -File |
Where-Object {
    $VideoExtensions -contains $_.Extension.ToLowerInvariant()
}

if (-not $Videos) {
    Write-Host "No supported video files found in: $Folder" -ForegroundColor Yellow
    exit
}

foreach ($Video in $Videos) {
    Write-Host "`nProcessing: $($Video.Name)" -ForegroundColor Cyan

    $TempFolder = Join-Path $env:TEMP ("VideoContactSheet_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $TempFolder -Force | Out-Null

    $Bitmap = $null
    $Graphics = $null
    $FooterFont = $null
    $TitleFont = $null
    $TimestampFont = $null
    $TimestampBgBrush = $null

    try {
        # Read video metadata (Filtering out cover art)
        $ProbeOutput = & ffprobe `
            -v error `
            -show_entries format=duration, bit_rate `
            -show_entries stream=codec_type, codec_name, width, height, disposition `
            -of json `
            "$($Video.FullName)" 2>$null

        if ($LASTEXITCODE -ne 0 -or -not $ProbeOutput) {
            Write-Host "Could not read metadata. Skipping video." -ForegroundColor Yellow
            continue
        }

        $Metadata = ($ProbeOutput -join "`n") | ConvertFrom-Json
        $Duration = 0.0

        if ($Metadata.format.duration) {
            $Duration = [double]::Parse(
                [string]$Metadata.format.duration,
                [Globalization.CultureInfo]::InvariantCulture
            )
        }

        if ($Duration -le 0) {
            Write-Host "Video duration unavailable. Skipping video." -ForegroundColor Yellow
            continue
        }

        # Format overall duration
        $TS = [TimeSpan]::FromSeconds($Duration)
        $TotalHours = [int][Math]::Floor($TS.TotalHours)
        $DurationText = "{0:D2}:{1:D2}:{2:D2}" -f $TotalHours, $TS.Minutes, $TS.Seconds

        $VideoStream = $Metadata.streams |
        Where-Object { $_.codec_type -eq "video" -and $_.disposition.attached_pic -ne 1 } |
        Select-Object -First 1

        $AudioStream = $Metadata.streams |
        Where-Object { $_.codec_type -eq "audio" } |
        Select-Object -First 1

        $Resolution = "Unknown"
        $VideoCodec = "Unknown"
        $AudioCodec = "None"

        if ($VideoStream) {
            $Resolution = "$($VideoStream.width)x$($VideoStream.height)"
            $VideoCodec = [string]$VideoStream.codec_name
        }

        if ($AudioStream) {
            $AudioCodec = [string]$AudioStream.codec_name
        }

        $FileSizeMB = [Math]::Round($Video.Length / 1MB, 2)
        $Bitrate = "Unknown"

        if ($Metadata.format.bit_rate) {
            $BitrateMbps = [Math]::Round(([double]$Metadata.format.bit_rate / 1000000), 2)
            $Bitrate = "$BitrateMbps Mbps"
        }

        # Extract six frames and record their timestamps
        $FrameData = @()

        for ($i = 1; $i -le 6; $i++) {
            $TimestampSeconds = [Math]::Floor($Duration * $i / 7)
            $FramePath = Join-Path $TempFolder ("frame{0}.jpg" -f $i)

            & ffmpeg `
                -hide_banner `
                -loglevel error `
                -ss $TimestampSeconds `
                -i "$($Video.FullName)" `
                -frames:v 1 `
                -vf "scale=${FrameWidth}:${FrameHeight}:force_original_aspect_ratio=decrease,pad=${FrameWidth}:${FrameHeight}:(ow-iw)/2:(oh-ih)/2" `
                -q:v 3 `
                -y `
                "$FramePath"

            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $FramePath)) {
                # Format the individual frame's timestamp
                $FrameTS = [TimeSpan]::FromSeconds($TimestampSeconds)
                $FrameHours = [int][Math]::Floor($FrameTS.TotalHours)
                $FrameStampText = "{0:D2}:{1:D2}:{2:D2}" -f $FrameHours, $FrameTS.Minutes, $FrameTS.Seconds

                # Store both the image path and the text
                $FrameData += [PSCustomObject]@{
                    Path = $FramePath
                    Text = $FrameStampText
                }
            }
            else {
                Write-Host "Warning: Could not extract frame $i." -ForegroundColor Yellow
            }
        }

        if ($FrameData.Count -eq 0) {
            Write-Host "No frames extracted. Skipping contact sheet." -ForegroundColor Yellow
            continue
        }

        # Initialize Fonts and Brushes
        $FooterFont = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Regular)
        $TitleFont = New-Object System.Drawing.Font("Arial", 13, [System.Drawing.FontStyle]::Bold)
        $TimestampFont = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Bold)
        
        $WhiteBrush = [System.Drawing.Brushes]::White
        $GrayBrush = [System.Drawing.Brushes]::LightGray
        # Create a semi-transparent black brush (Alpha 180 out of 255)
        $TimestampBgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 0, 0, 0))

        # Create the contact sheet bitmap
        $SheetWidth = $Columns * $FrameWidth
        $SheetHeight = ($Rows * $FrameHeight) + $FooterHeight
        $Bitmap = New-Object System.Drawing.Bitmap($SheetWidth, $SheetHeight)
        $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
        
        $Graphics.Clear([System.Drawing.Color]::Black)
        $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

        # Draw frames in a grid with timestamps
        for ($index = 0; $index -lt $FrameData.Count; $index++) {
            $FrameInfo = $FrameData[$index]
            $FrameImage = $null
            
            try {
                $FrameImage = [System.Drawing.Image]::FromFile($FrameInfo.Path)
                $Column = $index % $Columns
                $Row = [int][Math]::Floor($index / $Columns)

                $X = $Column * $FrameWidth
                $Y = $Row * $FrameHeight

                # Draw the image
                $Graphics.DrawImage($FrameImage, $X, $Y, $FrameWidth, $FrameHeight)

                # --- Draw the Timestamp Overlay ---
                $TextSize = $Graphics.MeasureString($FrameInfo.Text, $TimestampFont)
                
                # Padding around the text and margin from the edge
                $PadX = 8
                $PadY = 4
                $Margin = 5 
                
                # Calculate Bottom-Right position
                $BgX = $X + $FrameWidth - $TextSize.Width - $PadX - $Margin
                $BgY = $Y + $FrameHeight - $TextSize.Height - $PadY - $Margin
                
                # Draw the semi-transparent black background
                $Graphics.FillRectangle($TimestampBgBrush, $BgX, $BgY, $TextSize.Width + $PadX, $TextSize.Height + $PadY)
                
                # Draw the white text on top of the background
                $Graphics.DrawString($FrameInfo.Text, $TimestampFont, $WhiteBrush, $BgX + ($PadX / 2), $BgY + ($PadY / 2))
            }
            finally {
                if ($FrameImage) { $FrameImage.Dispose() }
            }
        }

        # Draw metadata footer
        $FooterY = $Rows * $FrameHeight
        $Graphics.DrawString($Video.Name, $TitleFont, $WhiteBrush, 10, ($FooterY + 8))

        $Line1 = "Duration: $DurationText    Resolution: $Resolution"
        $Line2 = "Video: $VideoCodec    Audio: $AudioCodec"
        $Line3 = "Size: $FileSizeMB MB    Bitrate: $Bitrate"

        $Graphics.DrawString($Line1, $FooterFont, $GrayBrush, 10, ($FooterY + 36))
        $Graphics.DrawString($Line2, $FooterFont, $GrayBrush, 10, ($FooterY + 58))
        $Graphics.DrawString($Line3, $FooterFont, $GrayBrush, 10, ($FooterY + 80))

        # Save JPG beside the original video
        $OutputPath = Join-Path $Folder ($Video.BaseName + ".jpg")
        
        if (Test-Path -LiteralPath $OutputPath) {
            Write-Host "Overwriting existing file: $($Video.BaseName).jpg" -ForegroundColor DarkGray
        }

        $Bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        Write-Host "Created: $OutputPath" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR processing $($Video.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Clean up GDI+ resources to prevent memory leaks
        if ($Graphics) { $Graphics.Dispose() }
        if ($Bitmap) { $Bitmap.Dispose() }
        if ($FooterFont) { $FooterFont.Dispose() }
        if ($TitleFont) { $TitleFont.Dispose() }
        if ($TimestampFont) { $TimestampFont.Dispose() }
        if ($TimestampBgBrush) { $TimestampBgBrush.Dispose() }
        
        if (Test-Path -LiteralPath $TempFolder) {
            Remove-Item -LiteralPath $TempFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "`nFinished processing videos in: $Folder" -ForegroundColor Cyan