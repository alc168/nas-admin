#!/bin/bash
# If Playback starts, kill the scanner to free up the CPU
pkill -f "Plex Media Scanner"
pkill -f "Plex Script Host"
# Optional: Pause qBittorrent container
docker pause qbt-tl
