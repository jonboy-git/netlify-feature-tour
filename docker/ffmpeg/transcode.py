#!/usr/bin/env python3

import os
import sys
import subprocess
import json
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class TranscodeHandler(FileSystemEventHandler):
    def __init__(self):
        self.input_dir = os.getenv('INPUT_DIR', '/streams/input')
        self.output_dir = os.getenv('OUTPUT_DIR', '/streams/output')
        
        # Transcoding profiles
        self.profiles = {
            '1080p': {
                'resolution': '1920x1080',
                'video_bitrate': '5000k',
                'audio_bitrate': '192k',
                'preset': 'fast'
            },
            '720p': {
                'resolution': '1280x720',
                'video_bitrate': '2500k',
                'audio_bitrate': '128k',
                'preset': 'fast'
            },
            '480p': {
                'resolution': '854x480',
                'video_bitrate': '1000k',
                'audio_bitrate': '128k',
                'preset': 'fast'
            },
            '360p': {
                'resolution': '640x360',
                'video_bitrate': '600k',
                'audio_bitrate': '96k',
                'preset': 'fast'
            }
        }

    def on_created(self, event):
        if not event.is_directory and self.is_video_file(event.src_path):
            print(f"New file detected: {event.src_path}")
            time.sleep(2)  # Wait for file to be fully written
            self.transcode_file(event.src_path)

    def is_video_file(self, filepath):
        video_extensions = ['.mp4', '.avi', '.mov', '.mkv', '.flv', '.wmv', '.webm']
        return any(filepath.lower().endswith(ext) for ext in video_extensions)

    def transcode_file(self, input_path):
        filename = os.path.basename(input_path)
        name, ext = os.path.splitext(filename)
        
        print(f"Starting transcoding for: {filename}")
        
        for quality, profile in self.profiles.items():
            output_path = os.path.join(self.output_dir, f"{name}_{quality}.mp4")
            
            cmd = [
                'ffmpeg',
                '-i', input_path,
                '-c:v', 'libx264',
                '-preset', profile['preset'],
                '-crf', '23',
                '-maxrate', profile['video_bitrate'],
                '-bufsize', str(int(profile['video_bitrate'].replace('k', '')) * 2) + 'k',
                '-vf', f"scale={profile['resolution']}",
                '-c:a', 'aac',
                '-b:a', profile['audio_bitrate'],
                '-movflags', '+faststart',
                '-f', 'mp4',
                '-y',  # Overwrite output files
                output_path
            ]
            
            try:
                print(f"Transcoding to {quality}: {output_path}")
                subprocess.run(cmd, check=True, capture_output=True, text=True)
                print(f"Successfully transcoded to {quality}")
                
                # Generate HLS segments
                self.generate_hls(output_path, quality)
                
            except subprocess.CalledProcessError as e:
                print(f"Error transcoding to {quality}: {e.stderr}")

    def generate_hls(self, input_path, quality):
        """Generate HLS segments for adaptive streaming"""
        name = os.path.splitext(os.path.basename(input_path))[0]
        hls_dir = os.path.join(self.output_dir, 'hls', name.replace(f'_{quality}', ''))
        os.makedirs(hls_dir, exist_ok=True)
        
        playlist_path = os.path.join(hls_dir, f"{quality}.m3u8")
        
        cmd = [
            'ffmpeg',
            '-i', input_path,
            '-codec', 'copy',
            '-hls_time', '10',
            '-hls_list_size', '0',
            '-hls_segment_filename', os.path.join(hls_dir, f"{quality}_%03d.ts"),
            '-f', 'hls',
            '-y',
            playlist_path
        ]
        
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
            print(f"Generated HLS playlist: {playlist_path}")
            
            # Create master playlist if this is the first quality
            if quality == '720p':  # Use 720p as reference
                self.create_master_playlist(hls_dir, name.replace(f'_{quality}', ''))
                
        except subprocess.CalledProcessError as e:
            print(f"Error generating HLS for {quality}: {e.stderr}")

    def create_master_playlist(self, hls_dir, name):
        """Create master HLS playlist for adaptive streaming"""
        master_path = os.path.join(hls_dir, 'master.m3u8')
        
        content = "#EXTM3U\n#EXT-X-VERSION:3\n\n"
        
        for quality, profile in self.profiles.items():
            playlist_file = f"{quality}.m3u8"
            if os.path.exists(os.path.join(hls_dir, playlist_file)):
                bandwidth = int(profile['video_bitrate'].replace('k', '')) * 1000
                resolution = profile['resolution']
                content += f"#EXT-X-STREAM-INF:BANDWIDTH={bandwidth},RESOLUTION={resolution}\n"
                content += f"{playlist_file}\n\n"
        
        with open(master_path, 'w') as f:
            f.write(content)
        
        print(f"Created master playlist: {master_path}")

def main():
    handler = TranscodeHandler()
    observer = Observer()
    observer.schedule(handler, handler.input_dir, recursive=True)
    observer.start()
    
    print(f"Monitoring {handler.input_dir} for new video files...")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    
    observer.join()

if __name__ == "__main__":
    main()