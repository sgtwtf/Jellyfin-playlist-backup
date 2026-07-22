# Jellyfin Playlist Backup & Restore

A pair of PowerShell scripts for backing up and restoring Jellyfin playlists.

Instead of depending on Jellyfin's internal item IDs, playlists are restored by matching media metadata. This makes backups much more portable between servers, database rebuilds, and migrations.

## Why use this?

These backups are designed to keep working even if:

- You rebuild your Jellyfin database
- You migrate to a new server
- Jellyfin generates different item IDs
- You're restoring to another Jellyfin server with the same media library

Item IDs are still included in the backup for reference, but they are **not** used during restore.

---

# Backup

## What it does

The backup script exports every playlist into its own JSON file.

Backups are organized by user, making it easy to restore individual playlists later.

## Requirements

- PowerShell 5.1 or newer
- Jellyfin API key
- Access to the Jellyfin server
- A folder to store the backups

## Configuration

Before running the script, set:

- Jellyfin server URL
- API key
- Backup folder

## Backup Contents

Each JSON file includes:

- User name
- User ID
- Playlist name
- Playlist ID
- Backup date
- Playlist items

Each playlist item contains information such as:

- Name
- Item ID
- Media type
- Series name
- Season name
- Production year

Example:

```json
{
    "Name": "Episode Name",
    "Id": "MediaId",
    "Type": "Episode",
    "SeriesName": "Series Name",
    "SeasonName": "Season Name",
    "ProductionYear": 2000
}
```

## Folder Layout

```
JellyfinBackups/

├── User1/
│   ├── Playlist1.json
│   └── Playlist2.json
│
├── User2/
│   └── Playlist1.json
│
└── User3/
    └── Playlist1.json
```

## What happens during backup?

The script will:

1. Connect to Jellyfin
2. Retrieve all users
3. Find playlists for each user
4. Export every playlist
5. Save each playlist as a JSON file

## Notes

- Existing backup files are overwritten.
- Playlist order is preserved.
- One JSON file is created per playlist.
- Item IDs are stored for reference only.

---

# Restore

## What it does

The restore script recreates playlists from the JSON backups.

Before making any changes, every playlist item is validated against the destination server to make sure it can be found.

If any media can't be matched, the restore stops without modifying anything.

## Configuration

Set the following before running:

- Destination Jellyfin server URL
- API key
- Backup folder

---

# Media Matching

Since item IDs usually change between servers, media is matched using metadata.

The script searches in this order:

1. **Name + Series + Season**
2. **Name + Series**
3. **Name only**

This approach works well for server migrations and rebuilt libraries.

---

# Validation

Every playlist is checked before any changes are made.

Example:

```
Validation

Matched: 25
Missing: 0
```

If anything is missing, you'll get a report like this:

```
Missing Media

Episode A
Episode B
Episode C
```

Nothing is modified until every item can be matched successfully.

---

# Existing Playlist Comparison

If the destination playlist already exists, the script compares it with the backup.

Example:

```
Comparison

Backup Items    : 25
Playlist Items  : 22
Need To Add     : 3
Would Remove    : 0
```

This gives you a chance to review the differences before deciding what to do.

---

# Restore Options

## Create Playlist

Creates the playlist if it doesn't already exist.

```
Backup
   ↓
New Playlist
```

---

## Add Missing Items

Adds only the items that aren't already in the playlist.

Good for keeping an existing playlist up to date without replacing it.

```
Existing Playlist
        +
Missing Items
        ↓
Updated Playlist
```

---

## Replace Playlist

Deletes the existing playlist and recreates it from the backup.

Use this when you want the destination playlist to exactly match the backup, including item order.

```
Existing Playlist
        ↓
Delete
        ↓
Restore Backup
```

---

## Skip

Makes no changes.

Useful when you're only validating or reviewing differences.

---

# Typical Workflow

```
Source Server
      │
      ▼
Run Backup
      │
      ▼
Copy Backup Files
      │
      ▼
Run Restore
      │
      ▼
Validate Media
      │
      ▼
Review Differences
      │
      ▼
Choose an Action

 • Create
 • Add Missing
 • Replace
 • Skip
```

---

# Recommended Usage

### New Server Migration

Use **Replace Playlist**.

This recreates the playlist exactly as it existed on the source server.

### Keeping Servers in Sync

Use **Add Missing Items**.

Only new items are added, leaving the existing playlist intact.

### Testing

Run validation first, then choose **Skip** if you only want to verify that everything matches.

---

# Safety Features

- Automatically detects playlist owners
- Preserves playlist ownership
- Validates every item before making changes
- Stops if media can't be matched
- Shows playlist differences before updating
- Supports adding only missing items
- Can completely recreate playlists when needed
- JSON backups remain usable even if Jellyfin item IDs change
