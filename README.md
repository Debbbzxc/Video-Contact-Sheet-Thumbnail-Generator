# Video Contact Sheet & Thumbnail Generator

A lightweight, automated PowerShell tool that generates professional video contact sheets (screen-caps / preview thumbnails) with overlaid timestamps and a comprehensive metadata footer for videos in a folder.

---

## Features

- **Automated 3×2 Contact Sheet Grid**: Captures 6 evenly distributed frames across each video's timeline.
- **Timestamp Badges**: Semi-transparent timestamp overlays in the bottom-right corner of each frame (`HH:MM:SS`).
- **Aspect Ratio Preservation**: Automatically scales frames while maintaining original aspect ratio with letterboxing/pillarboxing padding.
- **Embedded Cover Art Filtering**: Safely ignores attached poster artwork in video containers when detecting dimensions and video streams.
- **Technical Metadata Footer**: Appends a clear metadata bar displaying:
  - Video file name
  - Duration & Resolution
  - Video Codec & Audio Codec
  - File Size (MB) & Bitrate (Mbps)
- **Batch Processing**: Scans the current folder and generates `.jpg` contact sheets beside each supported video.
- **Automatic Resource Cleanup**: Fully disposes GDI+ bitmaps, fonts, and graphics handles, and wipes temporary frame caches from `%TEMP%`.

---

## Supported Formats

Supports major video container formats:
- `.mp4`, `.mkv`, `.avi`, `.mov`, `.wmv`, `.m4v`, `.webm`

---

## Layout Structure

```
+-----------------------------------------------------------+
|  Frame 1 (Timestamp) |  Frame 2 (Timestamp) |  Frame 3... |
+-----------------------------------------------------------+
|  Frame 4 (Timestamp) |  Frame 5 (Timestamp) |  Frame 6... |
+-----------------------------------------------------------+
|  [Video Title.mp4]                                        |
|  Duration: 01:24:12    Resolution: 1920x1080              |
|  Video: h264           Audio: aac                         |
|  Size: 1250.45 MB      Bitrate: 2.07 Mbps                 |
+-----------------------------------------------------------+
```

---

## Prerequisites

1. **Operating System**: Windows with PowerShell 5.1 or newer.
2. **FFmpeg & FFprobe**: Must be installed and accessible in your system `PATH`.

### Installing FFmpeg on Windows

If you don't already have FFmpeg, install it via any of the following package managers:

- **Windows Package Manager (Winget)**:
  ```powershell
  winget install Gyan.FFmpeg
  ```
- **Scoop**:
  ```powershell
  scoop install ffmpeg
  ```
- **Chocolatey**:
  ```powershell
  choco install ffmpeg
  ```

Verify installation by running:
```powershell
ffmpeg -version
ffprobe -version
```

---

## Usage

1. Open PowerShell and navigate to the directory containing your video files:
   ```powershell
   cd "C:\Path\To\Your\Videos"
   ```

2. Run the script:
   ```powershell
   & "C:\Path\To\ThumbnailGenerator.ps1"
   ```

   *Or, if the script is located in the same folder:*
   ```powershell
   .\ThumbnailGenerator.ps1
   ```

3. If execution policy blocks script execution, run with bypass permissions:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File ".\ThumbnailGenerator.ps1"
   ```

Each video will generate a corresponding `.jpg` file in the same directory (e.g., `sample.mp4` &rarr; `sample.jpg`).

---

## Configuration

You can customize parameters directly at the top of [ThumbnailGenerator.ps1](ThumbnailGenerator.ps1):

| Variable | Default | Description |
| :--- | :--- | :--- |
| `$FrameWidth` | `480` | Width of each individual extracted frame tile (px) |
| `$FrameHeight` | `270` | Height of each individual extracted frame tile (px) |
| `$Columns` | `3` | Number of columns in the grid |
| `$Rows` | `2` | Number of rows in the grid |
| `$FooterHeight` | `115` | Height of the technical metadata footer at the bottom (px) |
| `$VideoExtensions` | `@(".mp4", ...)` | Array of recognized video file extensions |

---

## Troubleshooting

- **`ERROR: ffmpeg was not found in PATH`**:
  Ensure FFmpeg's `bin` folder is added to your Windows environment `PATH` variable, then restart PowerShell.
- **`Execution of scripts is disabled on this system`**:
  Run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` in an elevated PowerShell session, or launch with `-ExecutionPolicy Bypass`.
- **`Video duration unavailable. Skipping video.`**:
  Occurs when a video file is corrupted or unreadable by `ffprobe`.
