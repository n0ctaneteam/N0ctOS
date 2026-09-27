# Media Service

`Media.qml` is N0ctOS's centralized media-control and now-playing service.

It gives every shell component one consistent place to discover MPRIS players, select an active player, read normalized track metadata, and send playback commands without touching D-Bus or MPRIS objects directly.

The service supports player discovery, priority-based active-player selection, metadata normalization, capability-aware controls, position monitoring, volume/shuffle/loop/rate handling, player lifecycle operations, URI opening, icons, signals, and IPC status/serialization.

The normal usage pattern is:

```text
Component
    │
    ▼
Media
    │
    ├── active player
    ├── normalized metadata
    └── playback controls
    │
    ▼
Quickshell Mpris
    │
    ▼
D-Bus / MPRIS players
```

---

# 1. What does it do?

`Media.qml` sits between MPRIS-compatible applications and the N0ctOS UI.

A player can expose raw data:

```json
{
    "dbusName": "org.mpris.MediaPlayer2.spotify",
    "identity": "Spotify",
    "desktopEntry": "spotify",
    "trackTitle": "Sunset Drive",
    "trackArtist": "The Midnight",
    "trackAlbum": "Endless Summer",
    "trackArtUrl": "https://i.scdn.co/image/abc123",
    "playbackState": 0,
    "isPlaying": true,
    "position": 102.5,
    "length": 248.0,
    "volume": 0.75
}
```

or minimal/broken data:

```json
{
    "dbusName": "org.mpris.MediaPlayer2.firefox.instance123",
    "identity": "Firefox",
    "trackTitle": "",
    "trackArtist": "",
    "positionSupported": false,
    "volumeSupported": false
}
```

The service normalizes that into safe UI values:

```json
{
    "title": "Sunset Drive",
    "artist": "The Midnight",
    "album": "Endless Summer",
    "artUrl": "https://i.scdn.co/image/abc123",
    "isPlaying": true,
    "positionText": "1:42",
    "lengthText": "4:08",
    "progress": 0.41
}
```

and missing values become safe fallbacks:

```json
{
    "title": "Unknown Title",
    "artist": "Unknown Artist",
    "album": "Unknown Album",
    "artUrl": "",
    "position": 0,
    "length": 0,
    "progress": 0
}
```

The active player is resolved in this order:

```text
playing player in priority order
    ↓
paused player in priority order
    ↓
preferred available player
    ↓
first available player
```

So a component can simply do:

```qml
Media.title
```

```qml
Media.artist
```

```qml
Media.progress
```

```qml
Media.toggle()
```

and not care which MPRIS player is behind it, whether it supports seeking, or whether it disappeared.

If no player exists, safe empty values are returned and control calls become graceful no-ops.

---

# 2. UI API

Import normally:

```qml
import QtQuick
import Quickshell

import qs.services
```

## Core API

### Player model

| How to call                | What does it do                                                        |
| -------------------------- | ---------------------------------------------------------------------- |
| `Media.players`            | Native Quickshell `Mpris.players` model. Use directly as a view model. |
| `Media.playerList`         | Array of currently available players (`Mpris.players.values`).         |
| `Media.playerCount`        | Number of currently available players.                                 |
| `Media.isAvailable`        | `true` when at least one player exists.                                |
| `Media.hasPlayingPlayer`   | `true` when any player is currently playing.                           |
| `Media.hasPausedPlayer`    | `true` when any player is currently paused.                            |
| `Media.playerPriority`     | Ordered list of D-Bus names, most preferred first.                     |
| `Media.priorityCount`      | Length of the priority list.                                           |
| `Media.volumeStep`         | Default volume increment, `0.05`.                                      |
| `Media.seekStep`           | Default seek increment in seconds, `5`.                                |

### Active player

| How to call                    | What does it do                                                                 |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `Media.activePlayer`           | Currently selected player from `selectActivePlayer()`. Null when none exists.   |
| `Media.hasActivePlayer`        | `true` when `activePlayer` is non-null.                                         |
| `Media.activePlayerId`         | D-Bus name of the active player, or `""`.                                       |
| `Media.activePlayerName`       | Human-readable name via `playerName()`: identity, else desktopEntry, else D-Bus. |
| `Media.activePlayerIdentity`   | Raw `identity` string of the active player, or `""`.                            |
| `Media.activePlayerDesktopEntry` | Raw `desktopEntry` string of the active player, or `""`.                      |
| `Media.isPlaying`              | `true` when the active player exists and `isPlaying`.                           |
| `Media.isPaused`               | `true` when the active player state is `Paused`.                                |
| `Media.isStopped`              | `true` when no active player exists or state is `Stopped`.                      |
| `Media.playbackState`          | `"Playing"`, `"Paused"`, or `"Stopped"`. `"Stopped"` when no player.            |

### Track metadata

| How to call              | What does it do                                                                          |
| ------------------------ | ---------------------------------------------------------------------------------------- |
| `Media.trackId`          | Numeric `uniqueId` of the active track, or `0`.                                          |
| `Media.title`            | `trackTitle`, or `"Unknown Title"` when missing.                                         |
| `Media.artist`           | `trackArtist`, or `"Unknown Artist"` when missing.                                       |
| `Media.album`            | `trackAlbum`, or `"Unknown Album"` when missing.                                         |
| `Media.albumArtist`      | `trackAlbumArtist`, or `""` when missing.                                                |
| `Media.artUrl`           | `trackArtUrl`, or `""` when missing.                                                     |
| `Media.trackArtUrl`      | Alias of `artUrl`.                                                                       |
| `Media.trackDisplayText` | `"artist — title"`, or just `title` when artist is unknown.                              |
| `Media.subtitleText`     | `"artist • albumArtist"`, or just `artist` when album artist is missing.                 |
| `Media.metadata`         | Raw active-player metadata map, or `{}`.                                                 |
| `Media.trackUrl`         | `metadata["xesam:url"]`, first array element when array, or `""`.                        |
| `Media.genre`            | `metadata["xesam:genre"]`, first array element when array, or `""`.                      |
| `Media.contentType`      | `metadata["xesam:contentCreated"]`, first array element when array, or `""`.             |

### Position and duration

| How to call                 | What does it do                                                              |
| --------------------------- | ---------------------------------------------------------------------------- |
| `Media.position`            | Current position in seconds, clamped to `>= 0`, or `0` when unsupported.     |
| `Media.length`              | Track duration in seconds, clamped to `>= 0`, or `0` when unsupported.       |
| `Media.isPositionSupported` | `true` when the active player supports position.                             |
| `Media.isLengthSupported`   | `true` when the active player supports length.                               |
| `Media.progress`            | Normalized `position / length` clamped to `0.0–1.0`, or `0` when no length.  |
| `Media.progressPercent`     | `Math.round(progress * 100)`.                                                |
| `Media.positionText`        | Formatted position via `formatDuration()`, for example `"1:42"`.             |
| `Media.lengthText`          | Formatted duration via `formatDuration()`, for example `"4:08"`.             |
| `Media.remainingText`       | Formatted `length - position`, or `""` when no length.                       |

### Capabilities

| How to call               | What does it do                                        |
| ------------------------- | ------------------------------------------------------ |
| `Media.canControl`        | Active player allows control.                          |
| `Media.canPlay`           | Active player can play.                                |
| `Media.canPause`          | Active player can pause.                               |
| `Media.canTogglePlaying`  | Active player can toggle playing.                      |
| `Media.canStop`           | Alias of `canControl` for stop.                        |
| `Media.canSeek`           | Active player can seek.                                |
| `Media.canNext`           | Active player can go next (`canGoNext`).               |
| `Media.canPrevious`       | Active player can go previous (`canGoPrevious`).       |
| `Media.canRaise`          | Active player can raise its window.                    |
| `Media.canQuit`           | Active player can quit.                                |
| `Media.canSetFullscreen`  | Active player can set fullscreen.                                            |

### Volume, shuffle, loop, rate, fullscreen, URIs, icons

| How to call                  | What does it do                                                                              |
| ---------------------------- | -------------------------------------------------------------------------------------------- |
| `Media.isVolumeSupported`    | `true` when the active player supports volume.                                               |
| `Media.volume`               | Normalized `0.0–1.0` volume, clamped, or `0` when unsupported.                               |
| `Media.volumePercent`        | `Math.round(volume * 100)`.                                                                  |
| `Media.volumeText`           | Percent label, for example `"75%"`.                                                          |
| `Media.isShuffleSupported`   | `true` when the active player supports shuffle.                                              |
| `Media.isShuffled`           | `true` when shuffle is supported and enabled.                                                |
| `Media.loopState`            | `"None"`, `"Track"`, or `"Playlist"`. `"None"` when no player.                               |
| `Media.isLoopSupported`      | `true` when the active player supports loop.                                                 |
| `Media.isLoopingTrack`       | `true` when loop is supported and mode is `Track`.                                           |
| `Media.isLoopingPlaylist`    | `true` when loop is supported and mode is `Playlist`.                                        |
| `Media.rate`                 | Playback multiplier, or `1` when no player.                                                  |
| `Media.minRate`              | Player-advertised minimum rate, or `1`.                                                      |
| `Media.maxRate`              | Player-advertised maximum rate, or `1`.                                                      |
| `Media.isFullscreenSupported`| `true` when the active player can set fullscreen.                                            |
| `Media.isFullscreen`         | `true` when fullscreen is supported and enabled.                                             |
| `Media.supportedUriSchemes`  | Active-player URI schemes, or `[]`.                                                          |
| `Media.supportedMimeTypes`   | Active-player MIME types, or `[]`.                                                           |
| `Media.icon`                 | Nerd Font glyph for the active player via `iconForPlayer()`.                                 |
| `Media.iconKey`              | Stable key for the active player via `iconKeyForPlayer()`.                                   |
| `Media.playbackIcon`         | Play/pause glyph for the active player via `playbackIconForPlayer()`.                        |
| `Media.playbackIconKey`      | `"play"` or `"pause"` via `playbackIconKeyForPlayer()`.                                      |

### Playback and player control

| How to call                          | What does it do                                                                                   |
| ------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `Media.play()`                       | Plays the active player when `canPlay`.                                                           |
| `Media.pause()`                      | Pauses the active player when `canPause`.                                                         |
| `Media.toggle()`                     | Toggles playing via `togglePlaying()` when `canTogglePlaying`.                                    |
| `Media.stop()`                       | Stops the active player when `canControl`.                                                        |
| `Media.next()`                       | Skips next when `canGoNext`.                                                                      |
| `Media.previous()`                   | Skips previous when `canGoPrevious`.                                                              |
| `Media.seekForward(seconds)`         | Relative seek `+seconds` when `canSeek`. Ignores non-finite or `<= 0` values.                     |
| `Media.seekBackward(seconds)`        | Relative seek `-seconds` when `canSeek`. Ignores non-finite or `<= 0` values.                     |
| `Media.seekTo(seconds)`              | Absolute seek clamped to `>= 0` and to `length` when supported. Requires `canSeek` + position.    |
| `Media.setVolume(value)`             | Sets normalized `0.0–1.0` volume, clamped. Requires `canControl` + `volumeSupported`.             |
| `Media.setVolumePercent(percent)`    | Sets volume from `0–100` percent. Converts to `setVolume(percent / 100)`.                         |
| `Media.increaseVolumePercent(percent)` | Raises volume by `percent`, defaults to `volumeStep * 100` when non-finite.                     |
| `Media.decreaseVolumePercent(percent)` | Lowers volume by `percent`, defaults to `volumeStep * 100` when non-finite.                     |
| `Media.setShuffle(enabled)`          | Sets shuffle. Requires `canControl` + `shuffleSupported`.                                         |
| `Media.toggleShuffle()`              | Flips `isShuffled` via `setShuffle()`.                                                            |
| `Media.setLoop(mode)`                | Sets loop from `"none"`/`"off"`, `"track"`/`"one"`, `"playlist"`/`"all"`. Ignores unknown modes.  |
| `Media.setRate(value)`               | Sets rate clamped to `[minRate, maxRate]`. Requires `canControl`. Ignores non-finite values.      |
| `Media.raisePlayer()`                | Raises the active player window when `canRaise`.                                                  |
| `Media.quitPlayer()`                 | Quits the active player when `canQuit`.                                                           |
| `Media.setFullscreen(enabled)`       | Sets fullscreen when `canSetFullscreen`.                                                          |
| `Media.toggleFullscreen()`           | Flips `isFullscreen` via `setFullscreen()`.                                                       |
| `Media.openUri(uri)`                 | Opens `uri` on the active player. Ignores empty URIs and missing players.                         |

|Example                                              |Result                                             |
|-----------------------------------------------------|---------------------------------------------------|
|`Media.seekTo(Media.length * 0.5)`                   |position jumps to mid-track                        |
|`Media.setVolumePercent(75)`                         |volume becomes `0.75`                              |
|`Media.increaseVolumePercent(5)`                      |volume rises by 5 %                                |
|`Media.setLoop("track")`                             |loop mode becomes `Track`                          |
|`Media.setRate(1.5)`                                 |rate becomes 1.5x (when the player allows it)      |
|`Media.openUri(uri)`                                 |`uri` opens on the active player                   |

### Player selection and lookup

| How to call                          | What does it do                                                                            |
| ------------------------------------ | ------------------------------------------------------------------------------------------ |
| `Media.initializePriority()`         | Rebuilds priority from live players, preserving known order and appending new D-Bus names. |
| `Media.syncPriorityAfterInsert(player)` | Adds a new player's D-Bus name to priority when missing.                                |
| `Media.removePlayerFromPriority(player)` | Removes a player's D-Bus name from priority.                                         |
| `Media.prioritizePlayer(playerId)`   | Moves `playerId` to the front of priority. Returns `false` when unknown or empty.         |
| `Media.removePriorityById(playerId)` | Removes `playerId` from priority. Returns `false` when unknown or empty.                  |
| `Media.setActivePlayer(playerId)`    | Selects the active player by prioritizing `playerId`.                                      |
| `Media.findPlayer(playerId)`         | Finds a player by exact D-Bus name, or `null`.                                             |
| `Media.findPlayerByName(name)`       | Finds a player by case-insensitive `identity` or `desktopEntry`, or `null`.                |
| `Media.selectActivePlayer()`         | Returns the active player using the 4-step selection order.                                |
| `Media.findPlayingPlayer()`          | Returns any playing player, or `null`.                                                     |
| `Media.findPausedPlayer()`           | Returns any paused player, or `null`.                                                      |

|Example                                                |Result                                     |
|-------------------------------------------------------|-------------------------------------------|
|`Media.setActivePlayer("org.mpris.MediaPlayer2.spotify")` |Spotify becomes the active player          |
|`Media.prioritizePlayer("org.mpris.MediaPlayer2.spotify")` |Spotify moves to the front of priority     |
|`Media.findPlayerByName("spotify")`                    |player object, or `null` when no match     |
|`Media.selectActivePlayer()`                           |active player, or `null` when none exists  |

### Helpers and serialization

| How to call                                    | What does it do                                                                                          |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `Media.playerName(player)`                     | `identity`, else `desktopEntry`, else `dbusName`, else `""`.                                             |
| `Media.metadataValue(key)`                     | Active-player `metadata[key]`, first array element when array, else `""`.                                |
| `Media.metadataValueFromPlayer(player, key)`   | Same lookup for an explicit player.                                                                      |
| `Media.formatDuration(seconds)`                | `"m:ss"`, or `"h:mm:ss"` when `>= 1h`. `"0:00"` for non-finite or negative values.                       |
| `Media.playbackIconForPlayer(player)`          | `"󰏤"` when playing, else `"󰐊"`. `"󰐊"` when no player.                                                   |
| `Media.playbackIconKeyForPlayer(player)`       | `"pause"` when playing, else `"play"`.                                                                   |
| `Media.iconForPlayer(player)`                  | Per-app glyph: Spotify, Firefox/YouTube, VLC, MPV, Rhythmbox/Clementine, else `"󰝚"`.                     |
| `Media.iconKeyForPlayer(player)`               | Per-app key: `"spotify"`, `"browser-media"`, `"vlc"`, `"mpv"`, else `"music"`.                           |
| `Media.playerInfo(player)`                     | Serializable snapshot for one player: id, name, track, state, position, volume, flags, icons.            |
| `Media.activeMetadataInfo()`                   | Serializable active-track snapshot: title, artist, album, albumArtist, artUrl, url, raw metadata.        |
| `Media.statusInfo()`                           | Complete active-player status snapshot consumed by IPC `getStatus`.                                      |

|Example                                              |Result                                             |
|-----------------------------------------------------|---------------------------------------------------|
|`Media.formatDuration(102)`                          |`"1:42"`                                           |
|`Media.metadataValue("xesam:url")`                   |track URL, or `""` when missing                    |
|`Media.playerInfo(Media.activePlayer)`               |`{id, name, track, ...}` serializable snapshot     |

### Signals

| How to use                                | What does it do                                                              |
| ----------------------------------------- | ---------------------------------------------------------------------------- |
| `Media.playerAdded(player)`               | Emitted after an MPRIS player appears.                                       |
| `Media.playerRemoved(player)`             | Emitted after an MPRIS player disappears.                                    |
| `Media.playerListUpdated()`               | Emitted after insert or removal. Rebuild player choosers on this.            |
| `Media.activePlayerChangedExternally()`   | Emitted after insert, removal, prioritization, or playback-state change.     |
| `Media.trackChangedExternally()`          | Emitted on `trackChanged` and `postTrackChanged` for staged metadata.        |
| `Media.playbackChangedExternally()`       | Emitted on playback, volume, shuffle, loop, position, or playing changes.    |

## Value conventions

The third concern after reading and controlling is using the right units.

| Convention            | Meaning                                                                                                   |
| --------------------- | --------------------------------------------------------------------------------------------------------- |
| `volume`              | Normalized QML range `0.0–1.0`. Use with sliders.                                                         |
| `volumePercent`       | Integer `0–100` derived from `volume`. IPC `setVolume` expects this percent range, not `0.0–1.0`.         |
| `position` / `length` | Seconds as `real`. `formatDuration()` converts them to `"m:ss"` or `"h:mm:ss"`.                           |
| `progress`            | Normalized `0.0–1.0`. Use for progress bars and seek sliders.                                             |
| `loopState`           | String `"None"`, `"Track"`, or `"Playlist"`. `setLoop()` accepts friendly aliases.                        |
| `playerId`            | MPRIS D-Bus name, for example `"org.mpris.MediaPlayer2.spotify"`. Priority is stored by this key.         |
| `playerName`          | Human label from identity/desktopEntry/D-Bus fallback. Use for display, not for lookup by default.        |

For example:

```qml
Media.setVolume(
    0.75
)
```

sets normalized volume, while:

```bash
qs ipc call n0ctos-media setVolume 75
```

sets `75%` through the IPC percent convention.

Similarly:

```qml
Media.setLoop(
    "track"
)
```

and:

```qml
Media.setLoop(
    "one"
)
```

both select track repeat, while:

```qml
Media.setLoop(
    "playlist"
)
```

and:

```qml
Media.setLoop(
    "all"
)
```

both select playlist repeat.

### Typical component usage

```qml
readonly property string title:
    Media.title

readonly property string artist:
    Media.artist

readonly property bool playing:
    Media.isPlaying

readonly property real progress:
    Media.progress

readonly property bool canSeek:
    Media.canSeek
```

That is the intended everyday usage.

Components normally should not need to know how MPRIS discovery, D-Bus names, priority, position polling, or capability checks work.

---

# 3. IPC API

IPC target:

```text
n0ctos-media
```

## Core controls

| How to call              | What does it do                                                   |
| ------------------------ | ----------------------------------------------------------------- |
| `play`                   | Plays the active player when `canPlay`.                           |
| `pause`                  | Pauses the active player when `canPause`.                         |
| `toggle`                 | Toggles playing when `canTogglePlaying`.                          |
| `stop`                   | Stops the active player when `canControl`.                        |
| `next`                   | Skips next when `canGoNext`.                                      |
| `previous`               | Skips previous when `canGoPrevious`.                              |
| `seekForward <seconds>`  | Relative forward seek. Ignores non-finite or `<= 0` values.       |
| `seekBackward <seconds>` | Relative backward seek. Ignores non-finite or `<= 0` values.      |
| `seekTo <seconds>`       | Absolute seek clamped to `>= 0` and to `length` when supported.   |

| Example                                               | Result                          |
| ----------------------------------------------------- | ------------------------------- |
| `qs ipc call n0ctos-media play`                       | active player starts playing    |
| `qs ipc call n0ctos-media pause`                      | active player pauses            |
| `qs ipc call n0ctos-media toggle`                     | playing state flips             |
| `qs ipc call n0ctos-media stop`                       | active player stops             |
| `qs ipc call n0ctos-media next`                       | skips to the next track         |
| `qs ipc call n0ctos-media previous`                   | returns to the previous track   |
| `qs ipc call n0ctos-media seekForward 10`             | position moves +10 s            |
| `qs ipc call n0ctos-media seekBackward 10`            | position moves −10 s            |
| `qs ipc call n0ctos-media seekTo 42`                  | position jumps to 42 s          |

`<seconds>` is a number.

For example:

```bash
qs ipc call n0ctos-media seekForward 10
```

Relative number:

```bash
qs ipc call n0ctos-media seekTo 42
```

Absolute number:

```bash
qs ipc call n0ctos-media seekBackward 5
```

Backward number:

```bash
qs ipc call n0ctos-media toggle
```

No argument:

```bash
qs ipc call n0ctos-media next
```

No argument.

## Other operations

| How to call                    | What does it do                                                                                     |
| ------------------------------ | --------------------------------------------------------------------------------------------------- |
| `getStatus`                    | Returns `statusInfo()` as JSON: availability, active player, track, state, volume, flags, icons.    |
| `getPlayer`                    | Returns the active D-Bus name (`activePlayerId`).                                                   |
| `getPlayerName`                | Returns the human-readable active-player name.                                                      |
| `getIcon`                      | Returns the active-player Nerd Font glyph.                                                          |
| `getPlayers`                   | Returns `playerInfo()` for every player as JSON.                                                    |
| `getMetadata`                  | Returns `activeMetadataInfo()` as JSON: title, artist, album, artUrl, url, raw metadata.            |
| `getPriority`                  | Returns the D-Bus-name priority list as JSON.                                                       |
| `setPlayer <playerId>`         | Selects the active player by prioritizing `playerId`.                                               |
| `prioritize <playerId>`        | Moves `playerId` to the front of priority.                                                          |
| `removeFromPriority <playerId>`| Removes `playerId` from priority.                                                                   |
| `setVolume <percent>`          | Sets volume from `0–100` percent via `setVolumePercent()`.                                          |
| `increaseVolume <percent>`     | Raises volume by percent via `increaseVolumePercent()`.                                             |
| `decreaseVolume <percent>`     | Lowers volume by percent via `decreaseVolumePercent()`.                                             |
| `setShuffle <bool>`            | Sets shuffle state.                                                                                 |
| `toggleShuffle`                | Flips shuffle state.                                                                                |
| `setLoop <mode>`               | Sets loop from `"none"`/`"off"`, `"track"`/`"one"`, `"playlist"`/`"all"`.                           |
| `setRate <value>`              | Sets playback rate clamped to `[minRate, maxRate]`.                                                 |
| `raise`                        | Raises the active player window when `canRaise`.                                                    |
| `quit`                         | Quits the active player when `canQuit`.                                                             |
| `setFullscreen <bool>`         | Sets fullscreen state.                                                                              |
| `toggleFullscreen`             | Flips fullscreen state.                                                                             |
| `openUri <uri>`                | Opens `uri` on the active player. Ignores empty URIs.                                               |

| Example                                                                      | Result                                        |
| ---------------------------------------------------------------------------- | --------------------------------------------- |
| `qs ipc call n0ctos-media getStatus`                                         | JSON status object                            |
| `qs ipc call n0ctos-media getPlayers`                                        | JSON array of `playerInfo()` objects          |
| `qs ipc call n0ctos-media getMetadata`                                       | JSON track snapshot (title, artist, album...) |
| `qs ipc call n0ctos-media getPriority`                                       | JSON D-Bus-name priority list                 |
| `qs ipc call n0ctos-media setPlayer org.mpris.MediaPlayer2.spotify`          | Spotify becomes the active player             |
| `qs ipc call n0ctos-media setVolume 75`                                      | volume becomes 75 %                           |
| `qs ipc call n0ctos-media setShuffle true`                                   | shuffle turns on                              |
| `qs ipc call n0ctos-media setLoop track`                                     | loop mode becomes `Track`                     |
| `qs ipc call n0ctos-media setRate 1.5`                                       | rate becomes 1.5x                             |
| `qs ipc call n0ctos-media raise`                                             | player window raised                          |
| `qs ipc call n0ctos-media openUri https://open.spotify.com/track/abc`        | URI opens on the active player                |

Boolean:

```bash
qs ipc call n0ctos-media setShuffle true
```

Percent:

```bash
qs ipc call n0ctos-media setVolume 75
```

String:

```bash
qs ipc call n0ctos-media setLoop track
```

D-Bus name:

```bash
qs ipc call n0ctos-media setPlayer org.mpris.MediaPlayer2.spotify
```

---

# 4. Features / limitations

## Features

### One API for all players

A media widget works without knowing whether the player is:

```text
Spotify
Firefox
VLC
MPV
YouTube player
a local music client
```

The widget simply consumes:

```qml
Media
```

### Priority-based active player

Priority is stored by D-Bus name because it is the actual MPRIS service identifier and is more stable than human-readable identity:

```json
[
    "org.mpris.MediaPlayer2.spotify",
    "org.mpris.MediaPlayer2.firefox.instance123",
    "org.mpris.MediaPlayer2.vlc"
]
```

Selection follows:

```text
1. playing player in priority order
2. paused player in priority order
3. preferred available player
4. first available player
```

This prevents random appearance order from deciding what the top bar shows.

### Normalized track metadata

The service prefers Quickshell's guarded properties:

```text
trackTitle
trackArtist
trackAlbum
trackAlbumArtist
trackArtUrl
```

instead of blindly trusting arbitrary keys inside:

```qml
player.metadata
```

Missing values become:

```text
title = Unknown Title
artist = Unknown Artist
album = Unknown Album
albumArtist =
artUrl =
```

The raw map is still exposed as `Media.metadata` for advanced consumers.

### Raw metadata helpers

Direct MPRIS keys are read safely:

```qml
Media.metadataValue(
    "xesam:url"
)
```

Array values return their first element:

```json
{
    "xesam:genre": ["Electronic"]
}
```

becomes:

```text
Electronic
```

Missing keys return `""` instead of `undefined`.

### Capability-aware controls

Every mutating operation checks its capability first:

```text
canPlay
canPause
canTogglePlaying
canControl
canSeek + positionSupported
volumeSupported
shuffleSupported
loopSupported
canGoNext
canGoPrevious
canRaise
canQuit
canSetFullscreen
```

For example `play()` only runs when:

```text
player && player.canPlay
```

and `seekTo()` only runs when:

```text
player && canSeek && positionSupported
```

Unsupported operations become graceful no-ops.

### Formatted playback time

`formatDuration()` prevents every widget from writing its own formatter:

```text
0 -> 0:00
65 -> 1:05
248 -> 4:08
3661 -> 1:01:01
```

Invalid or negative values become:

```text
0:00
```

The service exposes:

```text
positionText
lengthText
remainingText
```

directly.

### Only the active player is monitored

Quickshell intentionally avoids constantly emitting position changes when nobody is monitoring playback.

The service runs one short timer:

```text
interval: 500
repeat: true
```

only while:

```text
activePlayer && isPlaying && positionSupported
```

On each tick it emits:

```qml
activePlayer.positionChanged()
```

so `position`, `progress`, and time labels stay live without polling every player.

### Staged track-change handling

Some players update metadata in stages.

The service listens to both:

```text
trackChanged
postTrackChanged
```

and re-emits:

```text
trackChangedExternally
```

UI bindings should therefore use reactive service properties rather than snapshotting metadata once.

### Per-player icons

Display glyphs are centralized:

```text
spotify -> 󰓇
firefox / youtube -> 󰗃
vlc -> 󰕼
mpv -> 󰐹
rhythmbox / clementine -> 󰎆
fallback -> 󰝚
```

Stable keys are also exposed:

```text
spotify
browser-media
vlc
mpv
music
```

Playback state has its own pair:

```text
playing -> 󰏤 / pause
paused/stopped -> 󰐊 / play
```

### Serialization for IPC and tools

Three serializers cover external consumers:

```text
playerInfo(player)
activeMetadataInfo()
statusInfo()
```

`playerInfo()` includes:

```json
{
    "id": "org.mpris.MediaPlayer2.spotify",
    "name": "Spotify",
    "title": "Sunset Drive",
    "artist": "The Midnight",
    "position": 102.5,
    "length": 248.0,
    "progress": 0.41,
    "volume": 75,
    "loopState": "None",
    "canSeek": true,
    "icon": "󰓇",
    "iconKey": "spotify"
}
```

`statusInfo()` is the complete active-player snapshot behind IPC `getStatus`.

### No polling of the whole system

Steady state is:

```text
no players -> almost no work
players exist -> react to model changes
active player playing -> 500ms position ticker
active player paused/stopped -> ticker stops
```

There is no:

```text
every 50ms query every player
```

architecture.

### Singleton sharing

Because `Media` is a singleton:

```text
top bar
   │
   ├── media module
   │
notification center
   │
   └── media widget
        │
lock screen
   │
   └── compact player
```

can all read the same active-player state without creating extra MPRIS watchers.

---

## Limitations

### MPRIS support varies

One player may support seeking while another does not:

```text
player A -> supports seeking
player B -> does not

player A -> supports volume
player B -> does not

player A -> supports fullscreen
player B -> does not
```

Always gate UI on:

```qml
Media.canSeek
Media.isVolumeSupported
Media.isShuffleSupported
Media.isLoopSupported
```

rather than assuming support.

### Priority is not persisted through Config

The priority list is in-memory service state initialized from live players.

```text
player selection logic
        ≠
configuration persistence
```

Restarting the shell rebuilds priority from currently available players. Do not assume preferred-player ordering survives restarts.

### Position is only live while playing

`position` is reactive, but continuous updates depend on the 500ms ticker.

When playback is paused or position is unsupported:

```text
ticker stops
progress freezes
time labels freeze
```

This is intentional. Do not create a second global polling loop in a widget.

### QML volume and IPC volume use different units

QML:

```qml
Media.setVolume(
    0.75
)
```

expects `0.0–1.0`.

IPC:

```bash
qs ipc call n0ctos-media setVolume 75
```

expects `0–100` percent and calls `setVolumePercent()` internally.

Mixing the units produces silent clamping, not an error.

### D-Bus names are stable but not friendly

Priority and `findPlayer()` use:

```text
org.mpris.MediaPlayer2.spotify
```

not:

```text
Spotify
```

Browser players can include instance suffixes:

```text
org.mpris.MediaPlayer2.firefox.instance123
```

Use `findPlayerByName()` for human-name lookup and `activePlayerName` for display.

### Artwork and metadata may be missing

Not every player provides:

```text
album art
album name
genre
URL
duration
```

Always provide fallbacks:

```qml
Image {
    source: Media.artUrl !== ""
        ? Media.artUrl
        : "qrc:/ui/assets/default-cover.png"
}
```

and:

```qml
Text {
    text: Media.title || "Nothing Playing"
}
```

### Loop aliases are forgiving but narrow

`setLoop()` only understands:

```text
none / off -> None
track / one -> Track
playlist / all -> Playlist
```

Unknown strings are ignored silently.

It never encodes loop mode as arbitrary strings when the native `MprisLoopState` enum already exists.

### Rate bounds come from the player

The service does not assume:

```text
0.5–2.0
```

It clamps to:

```text
player.minRate – player.maxRate
```

Some players advertise `1–1`, which effectively means rate control is unavailable.

---

# 5. Example use cases

## 5.1 A minimal now-playing card

A basic media card needs only normalized properties:

```qml
import QtQuick
import Quickshell

import qs.services

Item {
    readonly property string title:
        Media.title

    readonly property string artist:
        Media.artist

    readonly property bool playing:
        Media.isPlaying

    readonly property real progress:
        Media.progress
}
```

The component does not need to know whether the data came from:

```text
Spotify
Firefox
VLC
MPV
no player at all
a newly appeared player
a prioritized player
```

It only receives the effective value.

---

## 5.2 A play/pause button with capability checks

Use state plus capability, not hardcoded enablement:

```qml
Button {
    enabled:
        Media.hasActivePlayer &&
        Media.canTogglePlaying

    text:
        Media.playbackIcon

    onClicked:
        Media.toggle()
}
```

Conceptually:

```text
┌────────────────────────────────┐
│  [album art]   Sunset Drive    │
│                The Midnight    │
│                                │
│  ───────────────●──────────    │
│                                │
│        ◀   ❚❚   ▶             │
└────────────────────────────────┘
```

N0ctOS media UIs should prefer Nerd Font Material glyphs via `Media.playbackIcon` and `Media.icon`.

---

## 5.3 Progress bar and seek slider

Use normalized progress for display:

```qml
ProgressBar {
    value:
        Media.progress
}
```

A seek slider maps:

```text
0.0 -> start
1.0 -> end
```

to:

```qml
Media.seekTo(...)
```

For example:

```qml
Slider {
    enabled:
        Media.canSeek &&
        Media.isPositionSupported

    value:
        Media.progress

    onMoved:
        Media.seekTo(
            value * Media.length
        )
}
```

Time labels come for free:

```qml
Text {
    text:
        Media.positionText +
        " / " +
        Media.lengthText
}
```

which may render:

```text
1:42 / 4:08
```

---

## 5.4 Volume control

Use normalized volume for sliders:

```qml
Slider {
    enabled:
        Media.isVolumeSupported

    value:
        Media.volume

    onMoved:
        Media.setVolume(
            value
        )
}
```

A percent label is:

```qml
Text {
    text:
        Media.volumeText
}
```

which may render:

```text
75%
```

Step buttons use the percent helpers:

```qml
Button {
    onClicked:
        Media.increaseVolumePercent(
            5
        )
}
```

---

## 5.5 Shuffle and repeat

Build a shuffle toggle from state plus support:

```qml
Button {
    enabled:
        Media.isShuffleSupported

    text:
        Media.isShuffled
            ? "Shuffle On"
            : "Shuffle Off"

    onClicked:
        Media.toggleShuffle()
}
```

Repeat cycles through the three canonical modes:

```qml
Button {
    enabled:
        Media.isLoopSupported

    text:
        Media.loopState

    onClicked: {
        if (Media.loopState === "None")
            Media.setLoop("track")
        else if (Media.loopState === "Track")
            Media.setLoop("playlist")
        else
            Media.setLoop("none")
    }
}
```

A UI can map loop states to:

```text
off
repeat track
repeat playlist
```

---

## 5.6 A player chooser

Enumerate live players and highlight the active one:

```qml
Column {
    Repeater {
        model:
            Media.playerList

        delegate: Button {
            required property var modelData

            text:
                Media.playerName(
                    modelData
                )

            enabled:
                String(
                    modelData.dbusName || ""
                ) !== Media.activePlayerId

            onClicked:
                Media.setActivePlayer(
                    String(
                        modelData.dbusName || ""
                    )
                )
        }
    }
}
```

Conceptually:

```text
Media
────────────────────
● Spotify
○ Firefox
○ VLC
○ MPV
```

The shell modifies preference through `setActivePlayer()` / `prioritizePlayer()` without each widget implementing MPRIS selection.

---

## 5.7 Reacting to track and playback changes

Track metadata can arrive in stages, so observe service signals:

```qml
Connections {
    target:
        Media

    function onTrackChangedExternally() {
        coverReload()
    }

    function onPlaybackChangedExternally() {
        updateTransport()
    }

    function onPlayerListUpdated() {
        rebuildChooser()
    }
}
```

Do not snapshot:

```qml
player.metadata
```

once and assume it stays complete.

---

## 5.8 Prioritizing a player from QML

Move a player to the front without touching D-Bus:

```qml
Media.prioritizePlayer(
    "org.mpris.MediaPlayer2.spotify"
)
```

Remove it from preference:

```qml
Media.removePriorityById(
    "org.mpris.MediaPlayer2.vlc"
)
```

Find by human name when the D-Bus name is unknown:

```qml
var player =
    Media.findPlayerByName(
        "spotify"
    )

if (player)
    Media.setActivePlayer(
        String(
            player.dbusName || ""
        )
    )
```

The active player re-resolves automatically through `selectActivePlayer()`.

---

## 5.9 Terminal workflow

Inspect the complete snapshot:

```bash
qs ipc call n0ctos-media getStatus
```

List players:

```bash
qs ipc call n0ctos-media getPlayers
```

Read active metadata:

```bash
qs ipc call n0ctos-media getMetadata
```

Control playback:

```bash
qs ipc call n0ctos-media toggle
```

```bash
qs ipc call n0ctos-media next
```

```bash
qs ipc call n0ctos-media previous
```

Seek:

```bash
qs ipc call n0ctos-media seekForward 10
```

```bash
qs ipc call n0ctos-media seekBackward 5
```

```bash
qs ipc call n0ctos-media seekTo 42
```

Set volume in percent:

```bash
qs ipc call n0ctos-media setVolume 75
```

Set shuffle and loop:

```bash
qs ipc call n0ctos-media setShuffle true
```

```bash
qs ipc call n0ctos-media setLoop track
```

Select a player:

```bash
qs ipc call n0ctos-media setPlayer org.mpris.MediaPlayer2.spotify
```

---

# 6. Detailed architecture

This section is for developers working on `Media.qml` and the services/components that consume it.

---

## 6.1 Overall architecture

The service is a shell-friendly abstraction over Quickshell's native MPRIS layer.

```text
Spotify / Firefox / VLC / MPV / etc.
                │
                │ MPRIS / D-Bus
                ▼
┌─────────────────────────┐
│ Quickshell MPRIS layer  │
│ Mpris.players           │
│ MprisPlayer             │
│ MprisPlaybackState      │
│ MprisLoopState          │
└────────────┬────────────┘
             │
             ▼
┌──────────────────────────────┐
│          Media.qml           │
│                              │
│ player discovery             │
│ priority                     │
│ active-player selection      │
│ metadata normalization       │
│ capability handling          │
│ position monitoring          │
│ formatting + icons           │
│ serialization                │
└──────────────┬───────────────┘
               │
               ▼
   N0ctOS UI / IPC clients
```

There are effectively two responsibilities:

```text
Media
    N0ctOS selection, normalization, and control API

Quickshell Mpris
    D-Bus discovery and per-player protocol objects
```

Media should not duplicate D-Bus handling already provided by Quickshell.

---

## 6.2 Player model

The native model is authoritative:

```text
MPRIS service registry
       │
       ▼
Mpris.players
       │
       ├── player A
       ├── player B
       ├── player C
       └── ...
```

The service derives convenience state from it:

```text
Mpris.players
      │
      ├── players
      ├── playerList = values
      ├── playerCount = values.length
      ├── isAvailable = count > 0
      ├── hasPlayingPlayer = findPlayingPlayer() !== null
      └── hasPausedPlayer = findPausedPlayer() !== null
```

It never maintains a second manually synchronized player registry.

---

## 6.3 Active-player selection

MPRIS can contain several players at once:

```text
Spotify -> playing
Firefox -> paused
VLC     -> stopped
```

`selectActivePlayer()` centralizes the choice:

```text
1. walk _playerPriority
   ignore missing players
   return first isPlaying player

2. walk _playerPriority
   return first Paused player

3. walk _playerPriority
   return first available player

4. return available[0]
```

`activePlayer` is a reactive property bound to that function, so insert, removal, playback change, or prioritization automatically re-resolves it.

---

## 6.4 Priority storage

Priority is an in-memory ordered list of D-Bus names:

```json
[
    "org.mpris.MediaPlayer2.spotify",
    "org.mpris.MediaPlayer2.firefox.instance123"
]
```

Lifecycle:

```text
Component.onCompleted
      │
      ▼
initializePriority()
      │
      ├── preserve known order for live players
      └── append new players

player inserted
      │
      ▼
syncPriorityAfterInsert(player)
      │
      ▼
append dbusName when missing

player removed
      │
      ▼
removePlayerFromPriority(player)
      │
      ▼
remove dbusName
```

`prioritizePlayer()` moves an ID to the front and emits:

```text
activePlayerChangedExternally
```

`setActivePlayer()` is the public selection entry point and delegates to `prioritizePlayer()`.

No `Config` document is involved. Priority does not survive restarts.

---

## 6.5 Player identity

MPRIS provides three related but distinct fields:

```text
identity
desktopEntry
D-Bus service name
```

Do not assume:

```text
identity == desktopEntry == D-Bus name
```

`playerName()` implements the display fallback:

```text
identity
  │ non-empty → return identity
  ▼
desktopEntry
  │ non-empty → return desktopEntry
  ▼
dbusName
```

Lookup has two paths:

```text
findPlayer(id)
    exact D-Bus match

findPlayerByName(name)
    case-insensitive identity or desktopEntry match
```

Display should use `activePlayerName`. Stable selection should use `activePlayerId`.

---

## 6.6 Track metadata normalization

The service prefers guarded Quickshell properties:

```text
trackTitle
trackArtist
trackAlbum
trackAlbumArtist
trackArtUrl
```

with UI-safe fallbacks:

```text
Unknown Title
Unknown Artist
Unknown Album
(empty albumArtist)
(empty artUrl)
```

Derived text avoids repetitive widget logic:

```text
trackDisplayText =
    artist known ? "artist — title" : title

subtitleText =
    albumArtist known ? "artist • albumArtist" : artist
```

Raw MPRIS keys use:

```qml
metadataValue(
    key
)
```

which handles:

```text
missing map -> ""
missing key -> ""
null -> ""
[] -> ""
["a", "b"] -> "a"
scalar -> String(value)
```

Exposed raw keys are:

```text
xesam:url -> trackUrl
xesam:genre -> genre
xesam:contentCreated -> contentType
full map -> metadata
```

This gives ordinary widgets:

```text
safe common fields
```

and advanced consumers:

```text
raw extensibility
```

---

## 6.7 Position monitoring

Quickshell intentionally avoids constantly polling position.

Reading:

```qml
player.position
```

gives the current value, but continuous emission requires active monitoring.

The service owns one timer:

```text
Timer {
    interval: 500
    repeat: true
    running: activePlayer && isPlaying && positionSupported
}
```

Behavior:

```text
no active playback
    ↓
no timer activity

active player is playing
    ↓
position monitoring enabled
    ↓
positionChanged() every 500ms

playback stops/pauses
    ↓
monitoring disabled
```

Only the active player is monitored:

```text
active player -> monitored
inactive players -> not polled for position
```

This keeps progress bars, seek sliders, and time labels live without a global high-frequency loop.

---

## 6.8 `seekTo()` semantics

`seekForward()` and `seekBackward()` are relative:

```text
seekForward(10) -> player.seek(+10)
seekBackward(10) -> player.seek(-10)
```

Both require:

```text
player && canSeek
```

and ignore non-finite or `<= 0` inputs.

`seekTo()` is absolute and stricter:

```text
require canSeek + positionSupported
parse Number(seconds), reject non-finite
target = max(0, value)
when lengthSupported: target = min(target, length)
player.position = target
```

The caller does not clamp manually.

---

## 6.9 Volume conventions

MPRIS volume is normalized:

```text
0.0 -> 0%
1.0 -> 100%
```

QML keeps that representation:

```text
volume = clamp(player.volume, 0, 1)
volumePercent = round(volume * 100)
volumeText = volumePercent + "%"
```

`setVolume()` takes normalized input:

```qml
Media.setVolume(
    0.75
)
```

`setVolumePercent()` takes percent input:

```qml
Media.setVolumePercent(
    75
)
```

`increaseVolumePercent()` and `decreaseVolumePercent()` take absolute percent deltas and fall back to:

```text
volumeStep * 100 = 5
```

when the argument is non-finite.

All four require:

```text
canControl + volumeSupported
```

---

## 6.10 Shuffle, loop, and rate

Shuffle is boolean and guarded:

```text
isShuffleSupported = player && shuffleSupported
isShuffled = supported && shuffle
setShuffle(enabled) requires canControl + shuffleSupported
toggleShuffle() = setShuffle(!isShuffled)
```

Loop uses the native enum but exposes strings:

```text
MprisLoopState.None -> "None"
MprisLoopState.Track -> "Track"
MprisLoopState.Playlist -> "Playlist"
```

with derived booleans:

```text
isLoopingTrack
isLoopingPlaylist
```

`setLoop()` lowercases input and maps:

```text
none / off -> None
track / one -> Track
playlist / all -> Playlist
unknown -> ignore
```

Rate is a multiplier bounded by the player:

```text
rate
minRate
maxRate
```

`setRate()` performs:

```text
parse Number(value), reject non-finite
bounded = max(minRate, min(maxRate, value))
player.rate = bounded
```

It requires `canControl` and never assumes a universal range.

---

## 6.11 Capability checks

MPRIS support varies:

```text
player A -> supports seeking
player B -> does not

player A -> supports volume
player B -> does not

player A -> supports fullscreen
player B -> does not
```

Mutating logic follows:

```text
play -> canPlay
pause -> canPause
toggle -> canTogglePlaying
stop -> canControl
next -> canGoNext
previous -> canGoPrevious
seek -> canSeek (+ positionSupported for absolute seek)
volume -> canControl + volumeSupported
shuffle -> canControl + shuffleSupported
loop -> canControl + loopSupported
rate -> canControl + clamp to player bounds
raise -> canRaise
quit -> canQuit
fullscreen -> canSetFullscreen
```

The service prefers graceful no-op behavior over assuming support.

---

## 6.12 Icons

Icons are centralized so widgets do not hardcode per-app checks.

Playback:

```text
no player -> 󰐊 / play
isPlaying -> 󰏤 / pause
paused -> 󰐊 / play
stopped -> 󰐊 / play
```

Per-player glyph from lowercased `identity + desktopEntry`:

```text
spotify -> 󰓇
firefox / youtube -> 󰗃
vlc -> 󰕼
mpv -> 󰐹
rhythmbox / clementine -> 󰎆
fallback -> 󰝚
```

Stable keys:

```text
spotify
browser-media
vlc
mpv
music
```

Widgets should use `Media.icon` / `Media.playbackIcon` for glyphs and `iconKey` variants for theming or testing.

---

## 6.13 Player disappearance

Players appear and disappear dynamically:

```text
Spotify closed
VLC launched
browser tab starts media
browser tab stops media
```

The model connections handle both directions:

```text
objectInsertedPost
    ↓
syncPriorityAfterInsert
    ↓
playerAdded
    ↓
playerListUpdated + activePlayerChangedExternally

objectRemovedPost
    ↓
removePlayerFromPriority
    ↓
playerRemoved
    ↓
playerListUpdated + activePlayerChangedExternally
```

When the active player disappears, `activePlayer` re-resolves instead of retaining a dangling reference.

One broken MPRIS client must not take down the singleton.

---

## 6.14 Serialization

IPC needs plain JSON, not live QML objects.

`playerInfo(player)` snapshots one player:

```json
{
    "id": "org.mpris.MediaPlayer2.spotify",
    "name": "Spotify",
    "identity": "Spotify",
    "desktopEntry": "spotify",
    "trackId": 42,
    "title": "Sunset Drive",
    "artist": "The Midnight",
    "album": "Endless Summer",
    "albumArtist": "",
    "artUrl": "https://i.scdn.co/image/abc123",
    "playbackState": "Playing",
    "isPlaying": true,
    "position": 102.5,
    "length": 248.0,
    "progress": 0.41,
    "progressPercent": 41,
    "positionText": "1:42",
    "lengthText": "4:08",
    "isPositionSupported": true,
    "isLengthSupported": true,
    "volume": 75,
    "isVolumeSupported": true,
    "isShuffled": false,
    "isShuffleSupported": true,
    "loopState": "None",
    "isLoopSupported": true,
    "rate": 1,
    "minRate": 1,
    "maxRate": 1,
    "isFullscreen": false,
    "isFullscreenSupported": false,
    "canControl": true,
    "canPlay": true,
    "canPause": true,
    "canTogglePlaying": true,
    "canSeek": true,
    "canGoNext": true,
    "canGoPrevious": true,
    "canRaise": true,
    "canQuit": true,
    "icon": "󰓇",
    "iconKey": "spotify"
}
```

Note that serialized volume is percent (`75`), while live `Media.volume` is normalized (`0.75`).

`activeMetadataInfo()` snapshots the active track:

```json
{
    "title": "Sunset Drive",
    "artist": "The Midnight",
    "album": "Endless Summer",
    "albumArtist": "",
    "artUrl": "https://i.scdn.co/image/abc123",
    "url": "https://open.spotify.com/track/abc",
    "metadata": {}
}
```

`statusInfo()` is the complete `getStatus` payload: availability, counts, active-player identity, normalized track, playback booleans, position/duration/progress/texts, volume percent, shuffle/loop/rate, fullscreen, capabilities, and icons.

---

## 6.15 IPC architecture

IPC is a thin external interface over the same service API.

Conceptually:

```text
terminal
   │
   ▼
n0ctos-media
   │
   ▼
Media.qml
   │
   ▼
Quickshell Mpris
```

For example:

```bash
qs ipc call n0ctos-media toggle
```

becomes conceptually:

```qml
Media.toggle()
```

and:

```bash
qs ipc call n0ctos-media setVolume 75
```

becomes conceptually:

```qml
Media.setVolumePercent(
    75
)
```

The IPC layer serializes JSON for `getStatus`, `getPlayers`, `getMetadata`, and `getPriority`, and returns plain strings for `getPlayer`, `getPlayerName`, and `getIcon`.

---

## 6.16 Why IPC stays high-level

IPC exposes useful media operations, not internals.

External callers do not need to know about:

```text
raw MprisPlayer objects
D-Bus names unless selecting players
position ticker implementation
trackChanged vs postTrackChanged
metadata array unwrapping
volume normalization internals
MprisPlaybackState enum values
```

They only need:

```text
getStatus
getPlayers
getMetadata
play / pause / toggle / stop / next / previous
seekForward / seekBackward / seekTo
setVolume / increaseVolume / decreaseVolume
setShuffle / toggleShuffle
setLoop
setRate
raise / quit / setFullscreen / toggleFullscreen
openUri
setPlayer / prioritize / removeFromPriority
```

This keeps IPC stable even if the MPRIS implementation changes.

---

## 6.17 Performance model

Media is cheap during idle operation.

Normal runtime work is:

```text
QML binding
    ↓
Media
    ↓
in-memory lookup or delegated MPRIS call
```

rather than:

```text
QML binding
    ↓
D-Bus round-trip per widget
    ↓
per-widget formatting and selection
```

Steady state:

```text
no players -> almost no work
players exist -> react to model changes
active playing -> 500ms ticker
paused/stopped -> ticker stops
```

Position cloning and serialization only happen when `playerInfo()`, `activeMetadataInfo()`, or `statusInfo()` is explicitly requested.

---

## 6.18 No Config dependency

Unlike configuration services, `Media.qml` does not use `Config`.

```text
Media
    MPRIS state
    in-memory priority
    reactive derived values

Config
    configuration documents
    file watching
    persistence
```

There is intentionally no:

```qml
Config.get(...)
Config.set(...)
```

in the media path. Player state comes from D-Bus, not `homeConfig`.

---

## 6.19 Reactive state

Conceptually:

```text
MPRIS player appears/disappears
        │
        ▼
Mpris.players changes
        │
        ▼
Media state reevaluates
        │
        ▼
component bindings reevaluate
```

and:

```text
trackChanged / postTrackChanged
        │
        ▼
trackChangedExternally
        │
        ▼
title / artist / album bindings reevaluate
```

and:

```text
playback / volume / shuffle / loop / position change
        │
        ▼
playbackChangedExternally
        │
        ▼
transport bindings reevaluate
```

A component does not need to manually reload media state.

For example:

```qml
readonly property string title:
    Media.title
```

reacts automatically when the active track changes.

---

## 6.20 Complete selection lifecycle

When a player appears:

```text
MPRIS registry
      │
      ▼
objectInsertedPost
      │
      ▼
syncPriorityAfterInsert
      │
      ▼
playerAdded + playerListUpdated
      │
      ▼
selectActivePlayer()
      │
      ▼
activePlayer changes
      │
      ▼
activePlayerChangedExternally
      │
      ▼
component bindings reevaluate
```

When playback starts elsewhere:

```text
player.isPlaying changes
      │
      ▼
playbackChangedExternally
+ activePlayerChangedExternally
      │
      ▼
selectActivePlayer() prefers playing player
      │
      ▼
top bar switches source
```

Existing priority order is preserved unless explicitly changed.

---

## 6.21 Complete control lifecycle

A control follows:

```text
Component / IPC
      │
      ▼
Media.play() / toggle() / seekTo() / ...
      │
      ▼
capability check
      │
  ┌───┴───┐
 supported unsupported
  │        │
  ▼        ▼
native   graceful
MPRIS    no-op
call
  │
  ▼
player state changes
  │
  ▼
reactive properties + signals
```

Media never bypasses capability flags to force an operation.

---

## 6.22 What UI / service code should not do

Components should not:

```text
create per-widget MPRIS watchers

call D-Bus directly from UI

duplicate active-player selection

assume all players support seek/volume/shuffle/loop

assume artwork always exists

assume metadata fields always exist

poll every player for position

retain dead player references

mutate live MprisPlayer objects bypassing Media

assume QML volume and IPC volume use the same units

hardcode per-app identity checks instead of Media icons
```

Instead:

```qml
Media.title
Media.artist
Media.progress
Media.isPlaying
Media.canSeek
Media.play()
Media.toggle()
Media.seekTo(...)
Media.setVolume(...)
```

should be the normal interface.

---

## 6.23 Final architecture summary

The entire system can be viewed as:

```text
                         Component
                            │
                            │ properties + controls
                            ▼
                    ┌─────────────────┐
                    │      Media      │
                    │                 │
                    │ players         │
                    │ priority        │
                    │ active player   │
                    │ metadata        │
                    │ capabilities    │
                    │ position ticker │
                    │ formatting      │
                    │ icons           │
                    │ serialization   │
                    └────────┬────────┘
                             │
                             │ Quickshell MPRIS API
                             ▼
                    ┌─────────────────┐
                    │  Quickshell     │
                    │  Mpris          │
                    │                 │
                    │ discovery       │
                    │ player objects  │
                    │ playback enums  │
                    └────────┬────────┘
                             │
                             ▼
                      D-Bus / MPRIS players
```

The core rule is:

> **UI components define what media they show; `Media.qml` decides which player is active, how its metadata is normalized, and how it is controlled; Quickshell MPRIS handles D-Bus discovery and protocol.**
