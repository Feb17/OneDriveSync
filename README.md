# OneDriveSync

A native macOS menu bar app for syncing local folders to Microsoft OneDrive.

OneDriveSync keeps the workflow simple:
- add one or more OneDrive accounts
- map local folders to remote paths
- run manual sync or scheduled sync
- monitor progress and cancel running tasks

## Features

- Multiple OneDrive accounts in one app
- Folder-level mapping to remote destinations
- Manual sync and `Sync All`
- Scheduled sync (15m, 30m, 1h, daily)
- Live progress and status updates
- Cancel in-progress sync
- Notifications for success and error states
- Launch at login
- Update check via GitHub Releases

## Requirements

- macOS 14.0+
- A Microsoft OneDrive account

## Installation

### Download

Get the latest build from:
- https://github.com/Feb17/OneDriveSync/releases

### Build from source

1. Clone the repository.
2. Open `OneDriveSync.xcodeproj` in Xcode.
3. Build and run the `OneDriveSync` scheme.

## First-time setup

1. Launch the app from Xcode or the built `.app`.
2. Open the menu bar app and add a OneDrive account.
3. Complete the interactive `rclone config` flow (browser login + drive selection).
4. Add folders in Settings and choose remote destinations.

## Usage

- `Sync All`: sync all enabled folders
- Per-folder sync: sync an individual folder from its action menu
- Schedule: choose interval in Settings
- Open in OneDrive: open mapped remote location when available

## Project notes

- Sync engine: bundled `rclone`
- Provider: `onedrive`
- Local settings keys:
  - `OneDriveSync.Folders`
  - `OneDriveSync.Settings`

## Acknowledgement

This project references the design and workflow ideas of:
- https://github.com/saihgupr/GoogleDriveSync

## Support

- Issues: https://github.com/Feb17/OneDriveSync/issues
