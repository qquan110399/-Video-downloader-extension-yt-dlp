import sys
import os
import json
import struct
import subprocess
import re
import threading

# Set stdin/stdout to binary mode for Windows
if sys.platform == "win32":
    import msvcrt
    msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)
    msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)

stdout_lock = threading.Lock()

def read_message():
    raw_length = sys.stdin.buffer.read(4)
    if not raw_length or len(raw_length) < 4:
        return None
    message_length = struct.unpack('<I', raw_length)[0]
    message = sys.stdin.buffer.read(message_length).decode('utf-8')
    return json.loads(message)

def send_message(message):
    with stdout_lock:
        encoded = json.dumps(message).encode('utf-8')
        sys.stdout.buffer.write(struct.pack('<I', len(encoded)))
        sys.stdout.buffer.write(encoded)
        sys.stdout.buffer.flush()

def get_ffmpeg_path():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None

def choose_folder(initial_dir=None):
    # Try Tkinter first
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        folder = filedialog.askdirectory(
            title="Select Download Folder",
            initialdir=initial_dir if (initial_dir and os.path.isdir(initial_dir)) else os.path.join(os.path.expanduser("~"), "Downloads")
        )
        root.destroy()
        if folder:
            return os.path.normpath(folder)
    except Exception:
        pass

    # Fallback to PowerShell FolderBrowserDialog
    try:
        ps_cmd = (
            '[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null; '
            '$d = New-Object System.Windows.Forms.FolderBrowserDialog; '
            '$d.Description = "Select Download Folder"; '
            'if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Host -NoNewline $d.SelectedPath }'
        )
        res = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_cmd],
            capture_output=True,
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        path = res.stdout.strip()
        if path and os.path.isdir(path):
            return os.path.normpath(path)
    except Exception:
        pass

    return None

def handle_download(url, quality, custom_dir=None):
    if custom_dir and os.path.isdir(custom_dir):
        downloads_dir = custom_dir
    else:
        downloads_dir = os.path.join(os.path.expanduser("~"), "Downloads")

    output_template = os.path.join(downloads_dir, "%(title)s.%(ext)s")

    cmd = [sys.executable, "-u", "-m", "yt_dlp", "--newline", "--no-playlist", "-o", output_template]

    ffmpeg_exe = get_ffmpeg_path()
    if ffmpeg_exe and os.path.exists(ffmpeg_exe):
        cmd.extend(["--ffmpeg-location", ffmpeg_exe])

    cmd.extend(["--js-runtimes", "node"])

    if quality == "mp3":
        cmd.extend(["-x", "--audio-format", "mp3"])
    else:
        # Enforce MP4 H.264 output for video downloads
        cmd.extend([
            "-S", "vcodec:h264,acodec:m4a",
            "--merge-output-format", "mp4",
            "--recode-video", "mp4"
        ])
        if quality == "1080p":
            cmd.extend(["-f", "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"])
        elif quality == "720p":
            cmd.extend(["-f", "bestvideo[height<=720]+bestaudio/best[height<=720]/best"])
        else:
            cmd.extend(["-f", "bestvideo+bestaudio/best"])

    cmd.append(url)

    send_message({"status": "downloading", "percent": 0, "text": "Starting download..."})

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )

        last_filename = None

        for line in iter(process.stdout.readline, ''):
            if not line:
                break
            line_str = line.strip()
            if not line_str:
                continue

            if "Destination:" in line_str:
                last_filename = line_str.split("Destination:", 1)[1].strip().strip('"')
            elif "[Merger] Merging formats into" in line_str:
                last_filename = line_str.split("[Merger] Merging formats into", 1)[1].strip().strip('"')

            percent_match = re.search(r'\[download\]\s+(\d+(?:\.\d+)?)%', line_str)
            if percent_match:
                percent = float(percent_match.group(1))
                speed_match = re.search(r'at\s+([\d\.\w/]+)', line_str)
                eta_match = re.search(r'ETA\s+([\d:]+)', line_str)
                
                speed = speed_match.group(1) if speed_match else ""
                eta = eta_match.group(1) if eta_match else ""
                
                send_message({
                    "status": "downloading",
                    "percent": percent,
                    "speed": speed,
                    "eta": eta,
                    "text": f"Downloading ({percent:.1f}%)"
                })
            else:
                send_message({"log": line_str})

        process.wait()

        if process.returncode == 0:
            send_message({"status": "finished", "filename": last_filename or downloads_dir})
        else:
            send_message({"status": "error", "error": f"yt-dlp exited with code {process.returncode}"})

    except Exception as e:
        send_message({"status": "error", "error": str(e)})

def main():
    while True:
        try:
            msg = read_message()
            if msg is None:
                break

            action = msg.get("action")
            if action == "ping":
                ver = "unknown"
                try:
                    import yt_dlp
                    ver = yt_dlp.version.__version__
                except Exception:
                    pass
                send_message({"status": "pong", "version": ver})

            elif action == "select_folder":
                initial_dir = msg.get("initial_dir")
                folder = choose_folder(initial_dir)
                if folder:
                    send_message({"status": "folder_selected", "path": folder})
                else:
                    send_message({"status": "folder_selection_cancelled"})

            elif action == "download":
                url = msg.get("url")
                quality = msg.get("quality", "best")
                custom_dir = msg.get("download_dir")
                handle_download(url, quality, custom_dir)

        except Exception as e:
            send_message({"status": "error", "error": str(e)})
            break

if __name__ == "__main__":
    main()
