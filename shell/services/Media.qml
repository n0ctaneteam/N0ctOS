pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    // ============================================================
    // CONSTANTS
    // ============================================================

    readonly property real volumeStep:
        0.05

    readonly property real seekStep:
        5

    // ============================================================
    // PLAYER MODEL
    // ============================================================

    /*
     * Native MPRIS player model.
     *
     * Public UI can use:
     *
     *     model: Media.players
     */
    readonly property var players:
        Mpris.players

    readonly property var playerList:
        Mpris.players.values

    readonly property int playerCount:
        Mpris.players.values.length

    readonly property bool isAvailable:
        root.playerCount > 0

    readonly property bool hasPlayingPlayer:
        root.findPlayingPlayer() !== null

    readonly property bool hasPausedPlayer:
        root.findPausedPlayer() !== null

    // ============================================================
    // PLAYER PRIORITY
    // ============================================================

    /*
     * Priority is stored by dbusName because it is the actual
     * MPRIS service identifier and is more stable than the
     * human-readable identity.
     */
    property var _playerPriority: []

    readonly property var playerPriority:
        root._playerPriority

    readonly property int priorityCount:
        root._playerPriority.length

    // ============================================================
    // ACTIVE PLAYER
    // ============================================================

    /*
     * Selection order:
     *
     * 1. Playing player in priority order
     * 2. Paused player in priority order
     * 3. Preferred available player
     * 4. First available player
     */
    readonly property var activePlayer:
        root.selectActivePlayer()

    readonly property bool hasActivePlayer:
        !!root.activePlayer

    readonly property string activePlayerId:
        root.activePlayer
            ? String(
                  root.activePlayer.dbusName || ""
              )
            : ""

    readonly property string activePlayerName:
        root.activePlayer
            ? root.playerName(
                  root.activePlayer
              )
            : ""

    readonly property string activePlayerIdentity:
        root.activePlayer
            ? String(
                  root.activePlayer.identity || ""
              )
            : ""

    readonly property string activePlayerDesktopEntry:
        root.activePlayer
            ? String(
                  root.activePlayer.desktopEntry || ""
              )
            : ""

    readonly property bool isPlaying:
        !!root.activePlayer &&
        root.activePlayer.isPlaying

    readonly property bool isPaused:
        !!root.activePlayer &&
        root.activePlayer.playbackState ===
            MprisPlaybackState.Paused

    readonly property bool isStopped:
        !root.activePlayer ||
        root.activePlayer.playbackState ===
            MprisPlaybackState.Stopped

    readonly property string playbackState:
        root.activePlayer
            ? MprisPlaybackState.toString(
                  root.activePlayer.playbackState
              )
            : "Stopped"

    // ============================================================
    // ACTIVE TRACK
    // ============================================================

    readonly property int trackId:
        root.activePlayer
            ? Number(
                  root.activePlayer.uniqueId
              )
            : 0

    readonly property string title:
        root.activePlayer &&
        String(
            root.activePlayer.trackTitle || ""
        ) !== ""
            ? String(
                  root.activePlayer.trackTitle
              )
            : "Unknown Title"

    readonly property string artist:
        root.activePlayer &&
        String(
            root.activePlayer.trackArtist || ""
        ) !== ""
            ? String(
                  root.activePlayer.trackArtist
              )
            : "Unknown Artist"

    readonly property string album:
        root.activePlayer &&
        String(
            root.activePlayer.trackAlbum || ""
        ) !== ""
            ? String(
                  root.activePlayer.trackAlbum
              )
            : "Unknown Album"

    readonly property string albumArtist:
        root.activePlayer &&
        String(
            root.activePlayer.trackAlbumArtist || ""
        ) !== ""
            ? String(
                  root.activePlayer.trackAlbumArtist
              )
            : ""

    readonly property string artUrl:
        root.activePlayer
            ? String(
                  root.activePlayer.trackArtUrl || ""
              )
            : ""

    readonly property string trackArtUrl:
        root.artUrl

    readonly property string trackDisplayText:
        root.artist !== "Unknown Artist"
            ? root.artist +
              " — " +
              root.title
            : root.title

    readonly property string subtitleText:
        root.albumArtist !== ""
            ? root.artist +
              " • " +
              root.albumArtist
            : root.artist

    readonly property var metadata:
        root.activePlayer
            ? root.activePlayer.metadata
            : ({})

    // ============================================================
    // TRACK URL / RAW METADATA HELPERS
    // ============================================================

    readonly property string trackUrl:
        root.metadataValue(
            "xesam:url"
        )

    readonly property string genre:
        root.metadataValue(
            "xesam:genre"
        )

    readonly property string contentType:
        root.metadataValue(
            "xesam:contentCreated"
        )

    // ============================================================
    // POSITION
    // ============================================================

    /*
     * MPRIS positions are seconds.
     *
     * Quickshell intentionally avoids constantly polling this
     * property. The Timer below emits positionChanged() only while
     * the active player is actually playing.
     */
    readonly property real position:
        root.activePlayer &&
        root.activePlayer.positionSupported
            ? Math.max(
                  0,
                  Number(
                      root.activePlayer.position
                  )
              )
            : 0

    readonly property real length:
        root.activePlayer &&
        root.activePlayer.lengthSupported
            ? Math.max(
                  0,
                  Number(
                      root.activePlayer.length
                  )
              )
            : 0

    readonly property bool isPositionSupported:
        !!root.activePlayer &&
        root.activePlayer.positionSupported

    readonly property bool isLengthSupported:
        !!root.activePlayer &&
        root.activePlayer.lengthSupported

    readonly property real progress:
        root.length > 0
            ? Math.max(
                  0,
                  Math.min(
                      1,
                      root.position /
                      root.length
                  )
              )
            : 0

    readonly property int progressPercent:
        Math.round(
            root.progress * 100
        )

    readonly property string positionText:
        root.formatDuration(
            root.position
        )

    readonly property string lengthText:
        root.formatDuration(
            root.length
        )

    readonly property string remainingText:
        root.length > 0
            ? root.formatDuration(
                  Math.max(
                      0,
                      root.length -
                      root.position
                  )
              )
            : ""

    Timer {
        id: positionTicker

        interval: 500
        repeat: true

        running:
            !!root.activePlayer &&
            root.activePlayer.isPlaying &&
            root.activePlayer.positionSupported

        onTriggered: {
            if (
                root.activePlayer &&
                root.activePlayer.positionSupported
            ) {
                root.activePlayer.positionChanged()
            }
        }
    }

    // ============================================================
    // PLAYBACK CAPABILITIES
    // ============================================================

    readonly property bool canControl:
        !!root.activePlayer &&
        root.activePlayer.canControl

    readonly property bool canPlay:
        !!root.activePlayer &&
        root.activePlayer.canPlay

    readonly property bool canPause:
        !!root.activePlayer &&
        root.activePlayer.canPause

    readonly property bool canTogglePlaying:
        !!root.activePlayer &&
        root.activePlayer.canTogglePlaying

    readonly property bool canStop:
        root.canControl

    readonly property bool canSeek:
        !!root.activePlayer &&
        root.activePlayer.canSeek

    readonly property bool canNext:
        !!root.activePlayer &&
        root.activePlayer.canGoNext

    readonly property bool canPrevious:
        !!root.activePlayer &&
        root.activePlayer.canGoPrevious

    readonly property bool canRaise:
        !!root.activePlayer &&
        root.activePlayer.canRaise

    readonly property bool canQuit:
        !!root.activePlayer &&
        root.activePlayer.canQuit

    readonly property bool canSetFullscreen:
        !!root.activePlayer &&
        root.activePlayer.canSetFullscreen

    // ============================================================
    // VOLUME
    // ============================================================

    readonly property bool isVolumeSupported:
        !!root.activePlayer &&
        root.activePlayer.volumeSupported

    readonly property real volume:
        root.activePlayer &&
        root.activePlayer.volumeSupported
            ? Math.max(
                  0,
                  Math.min(
                      1,
                      Number(
                          root.activePlayer.volume
                      )
                  )
              )
            : 0

    readonly property int volumePercent:
        Math.round(
            root.volume * 100
        )

    readonly property string volumeText:
        String(
            root.volumePercent
        ) + "%"

    // ============================================================
    // SHUFFLE / LOOP
    // ============================================================

    readonly property bool isShuffleSupported:
        !!root.activePlayer &&
        root.activePlayer.shuffleSupported

    readonly property bool isShuffled:
        !!root.activePlayer &&
        root.activePlayer.shuffleSupported &&
        root.activePlayer.shuffle

    readonly property string loopState:
        root.activePlayer
            ? MprisLoopState.toString(
                  root.activePlayer.loopState
              )
            : "None"

    readonly property bool isLoopSupported:
        !!root.activePlayer &&
        root.activePlayer.loopSupported

    readonly property bool isLoopingTrack:
        !!root.activePlayer &&
        root.activePlayer.loopSupported &&
        root.activePlayer.loopState ===
            MprisLoopState.Track

    readonly property bool isLoopingPlaylist:
        !!root.activePlayer &&
        root.activePlayer.loopSupported &&
        root.activePlayer.loopState ===
            MprisLoopState.Playlist

    // ============================================================
    // RATE
    // ============================================================

    readonly property real rate:
        root.activePlayer
            ? Number(
                  root.activePlayer.rate
              )
            : 1

    readonly property real minRate:
        root.activePlayer
            ? Number(
                  root.activePlayer.minRate
              )
            : 1

    readonly property real maxRate:
        root.activePlayer
            ? Number(
                  root.activePlayer.maxRate
              )
            : 1

    // ============================================================
    // FULLSCREEN
    // ============================================================

    readonly property bool isFullscreenSupported:
        !!root.activePlayer &&
        root.activePlayer.canSetFullscreen

    readonly property bool isFullscreen:
        !!root.activePlayer &&
        root.activePlayer.canSetFullscreen &&
        root.activePlayer.fullscreen

    // ============================================================
    // URI SUPPORT
    // ============================================================

    readonly property var supportedUriSchemes:
        root.activePlayer
            ? root.activePlayer.supportedUriSchemes
            : []

    readonly property var supportedMimeTypes:
        root.activePlayer
            ? root.activePlayer.supportedMimeTypes
            : []

    // ============================================================
    // ICON
    // ============================================================

    readonly property string icon:
        root.iconForPlayer(
            root.activePlayer
        )

    readonly property string iconKey:
        root.iconKeyForPlayer(
            root.activePlayer
        )

    readonly property string playbackIcon:
        root.playbackIconForPlayer(
            root.activePlayer
        )

    readonly property string playbackIconKey:
        root.playbackIconKeyForPlayer(
            root.activePlayer
        )

    // ============================================================
    // SIGNALS
    // ============================================================

    signal playerAdded(var player)
    signal playerRemoved(var player)

    signal activePlayerChangedExternally()
    signal playerListUpdated()
    signal trackChangedExternally()
    signal playbackChangedExternally()

    // ============================================================
    // PLAYER MODEL TRACKING
    // ============================================================

    Connections {
        target: Mpris.players

        function onObjectInsertedPost(
            player,
            index
        ) {
            root.syncPriorityAfterInsert(
                player
            )

            root.playerAdded(
                player
            )

            root.playerListUpdated()
            root.activePlayerChangedExternally()
        }

        function onObjectRemovedPost(
            player,
            index
        ) {
            root.removePlayerFromPriority(
                player
            )

            root.playerRemoved(
                player
            )

            root.playerListUpdated()
            root.activePlayerChangedExternally()
        }
    }

    // ============================================================
    // ACTIVE PLAYER SIGNAL TRACKING
    // ============================================================

    Connections {
        target:
            root.activePlayer

        function onTrackChanged() {
            root.trackChangedExternally()
        }

        function onPostTrackChanged() {
            root.trackChangedExternally()
        }

        function onPlaybackStateChanged() {
            root.playbackChangedExternally()
            root.activePlayerChangedExternally()
        }

        function onIsPlayingChanged() {
            root.playbackChangedExternally()
            root.activePlayerChangedExternally()
        }

        function onVolumeChanged() {
            root.playbackChangedExternally()
        }

        function onShuffleChanged() {
            root.playbackChangedExternally()
        }

        function onLoopStateChanged() {
            root.playbackChangedExternally()
        }

        function onPositionChanged() {
            root.playbackChangedExternally()
        }
    }

    // ============================================================
    // INITIALIZATION
    // ============================================================

    Component.onCompleted: {
        root.initializePriority()
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-media"

        // --------------------------------------------------------
        // GLOBAL STATUS
        // --------------------------------------------------------

        function getStatus(): string {
            return JSON.stringify(
                root.statusInfo()
            )
        }

        function getPlayer(): string {
            return root.activePlayerId
        }

        function getPlayerName(): string {
            return root.activePlayerName
        }

        function getIcon(): string {
            return root.icon
        }

        // --------------------------------------------------------
        // PLAYER PRIORITY
        // --------------------------------------------------------

        function getPriority(): string {
            return JSON.stringify(
                root.playerPriority
            )
        }

        function setPlayer(
            playerId: string
        ) {
            root.setActivePlayer(
                playerId
            )
        }

        function prioritize(
            playerId: string
        ) {
            root.prioritizePlayer(
                playerId
            )
        }

        function removeFromPriority(
            playerId: string
        ) {
            root.removePriorityById(
                playerId
            )
        }

        // --------------------------------------------------------
        // PLAYBACK
        // --------------------------------------------------------

        function play() {
            root.play()
        }

        function pause() {
            root.pause()
        }

        function toggle() {
            root.toggle()
        }

        function stop() {
            root.stop()
        }

        function next() {
            root.next()
        }

        function previous() {
            root.previous()
        }

        // --------------------------------------------------------
        // SEEK
        // --------------------------------------------------------

        function seekForward(
            seconds: real
        ) {
            root.seekForward(
                seconds
            )
        }

        function seekBackward(
            seconds: real
        ) {
            root.seekBackward(
                seconds
            )
        }

        function seekTo(
            seconds: real
        ) {
            root.seekTo(
                seconds
            )
        }

        // --------------------------------------------------------
        // VOLUME
        // --------------------------------------------------------

        function setVolume(
            percent: real
        ) {
            root.setVolumePercent(
                percent
            )
        }

        function increaseVolume(
            percent: real
        ) {
            root.increaseVolumePercent(
                percent
            )
        }

        function decreaseVolume(
            percent: real
        ) {
            root.decreaseVolumePercent(
                percent
            )
        }

        // --------------------------------------------------------
        // SHUFFLE / LOOP
        // --------------------------------------------------------

        function setShuffle(
            enabled: bool
        ) {
            root.setShuffle(
                enabled
            )
        }

        function toggleShuffle() {
            root.toggleShuffle()
        }

        function setLoop(
            mode: string
        ) {
            root.setLoop(
                mode
            )
        }

        // --------------------------------------------------------
        // RATE
        // --------------------------------------------------------

        function setRate(
            value: real
        ) {
            root.setRate(
                value
            )
        }

        // --------------------------------------------------------
        // PLAYER WINDOW
        // --------------------------------------------------------

        function raise() {
            root.raisePlayer()
        }

        function quit() {
            root.quitPlayer()
        }

        function setFullscreen(
            enabled: bool
        ) {
            root.setFullscreen(
                enabled
            )
        }

        function toggleFullscreen() {
            root.toggleFullscreen()
        }

        // --------------------------------------------------------
        // OPEN URI
        // --------------------------------------------------------

        function openUri(
            uri: string
        ) {
            root.openUri(
                uri
            )
        }

        // --------------------------------------------------------
        // PLAYER DATA
        // --------------------------------------------------------

        function getPlayers(): string {
            const result = []

            for (
                let i = 0;
                i < root.playerList.length;
                ++i
            ) {
                result.push(
                    root.playerInfo(
                        root.playerList[i]
                    )
                )
            }

            return JSON.stringify(
                result
            )
        }

        function getMetadata(): string {
            return JSON.stringify(
                root.activeMetadataInfo()
            )
        }
    }

    // ============================================================
    // PLAYER SELECTION
    // ============================================================

    function initializePriority() {
        const current =
            []

        const available =
            root.playerList

        /*
         * Preserve any already-known order.
         */
        for (
            let i = 0;
            i < root._playerPriority.length;
            ++i
        ) {
            const id =
                String(
                    root._playerPriority[i] || ""
                )

            if (
                id !== "" &&
                root.findPlayer(
                    id
                )
            ) {
                current.push(
                    id
                )
            }
        }

        /*
         * Append new players.
         */
        for (
            let i = 0;
            i < available.length;
            ++i
        ) {
            const player =
                available[i]

            if (!player)
                continue

            const id =
                String(
                    player.dbusName || ""
                )

            if (
                id !== "" &&
                current.indexOf(id) < 0
            ) {
                current.push(
                    id
                )
            }
        }

        root._playerPriority =
            current
    }

    function syncPriorityAfterInsert(
        player
    ) {
        if (!player)
            return

        const id =
            String(
                player.dbusName || ""
            )

        if (id === "")
            return

        if (
            root._playerPriority.indexOf(
                id
            ) >= 0
        ) {
            return
        }

        const list =
            root._playerPriority.slice()

        list.push(id)

        root._playerPriority =
            list
    }

    function removePlayerFromPriority(
        player
    ) {
        if (!player)
            return

        root.removePriorityById(
            String(
                player.dbusName || ""
            )
        )
    }

    function prioritizePlayer(
        playerId
    ) {
        const id =
            String(
                playerId || ""
            )

        if (id === "")
            return false

        const player =
            root.findPlayer(
                id
            )

        if (!player)
            return false

        const list =
            root._playerPriority.slice()

        const oldIndex =
            list.indexOf(id)

        if (oldIndex >= 0)
            list.splice(
                oldIndex,
                1
            )

        list.unshift(id)

        root._playerPriority =
            list

        root.activePlayerChangedExternally()

        return true
    }

    function removePriorityById(
        playerId
    ) {
        const id =
            String(
                playerId || ""
            )

        if (id === "")
            return false

        const list =
            root._playerPriority.slice()

        const index =
            list.indexOf(id)

        if (index < 0)
            return false

        list.splice(
            index,
            1
        )

        root._playerPriority =
            list

        return true
    }

    function setActivePlayer(
        playerId
    ) {
        return root.prioritizePlayer(
            playerId
        )
    }

    function findPlayer(
        playerId
    ) {
        const wanted =
            String(
                playerId || ""
            )

        if (wanted === "")
            return null

        for (
            let i = 0;
            i < root.playerList.length;
            ++i
        ) {
            const player =
                root.playerList[i]

            if (
                player &&
                String(
                    player.dbusName || ""
                ) === wanted
            ) {
                return player
            }
        }

        return null
    }

    function findPlayerByName(
        name
    ) {
        const wanted =
            String(
                name || ""
            ).toLowerCase()

        if (wanted === "")
            return null

        for (
            let i = 0;
            i < root.playerList.length;
            ++i
        ) {
            const player =
                root.playerList[i]

            if (!player)
                continue

            const identity =
                String(
                    player.identity || ""
                ).toLowerCase()

            const desktopEntry =
                String(
                    player.desktopEntry || ""
                ).toLowerCase()

            if (
                identity === wanted ||
                desktopEntry === wanted
            ) {
                return player
            }
        }

        return null
    }

    function selectActivePlayer() {
        const available =
            root.playerList

        if (
            available.length === 0
        ) {
            return null
        }

        /*
         * 1. Prefer a playing player according to priority.
         */
        for (
            let i = 0;
            i < root._playerPriority.length;
            ++i
        ) {
            const player =
                root.findPlayer(
                    root._playerPriority[i]
                )

            if (
                player &&
                player.isPlaying
            ) {
                return player
            }
        }

        /*
         * 2. Then prefer a paused player according to priority.
         */
        for (
            let i = 0;
            i < root._playerPriority.length;
            ++i
        ) {
            const player =
                root.findPlayer(
                    root._playerPriority[i]
                )

            if (
                player &&
                player.playbackState ===
                    MprisPlaybackState.Paused
            ) {
                return player
            }
        }

        /*
         * 3. Preferred available player.
         */
        for (
            let i = 0;
            i < root._playerPriority.length;
            ++i
        ) {
            const player =
                root.findPlayer(
                    root._playerPriority[i]
                )

            if (player)
                return player
        }

        /*
         * 4. Final fallback.
         */
        return available[0]
    }

    function findPlayingPlayer() {
        for (
            let i = 0;
            i < root.playerList.length;
            ++i
        ) {
            const player =
                root.playerList[i]

            if (
                player &&
                player.isPlaying
            ) {
                return player
            }
        }

        return null
    }

    function findPausedPlayer() {
        for (
            let i = 0;
            i < root.playerList.length;
            ++i
        ) {
            const player =
                root.playerList[i]

            if (
                player &&
                player.playbackState ===
                    MprisPlaybackState.Paused
            ) {
                return player
            }
        }

        return null
    }

    // ============================================================
    // PLAYBACK CONTROL
    // ============================================================

    function play() {
        const player =
            root.activePlayer

        if (
            player &&
            player.canPlay
        ) {
            player.play()
        }
    }

    function pause() {
        const player =
            root.activePlayer

        if (
            player &&
            player.canPause
        ) {
            player.pause()
        }
    }

    function toggle() {
        const player =
            root.activePlayer

        if (
            player &&
            player.canTogglePlaying
        ) {
            player.togglePlaying()
        }
    }

    function stop() {
        const player =
            root.activePlayer

        if (
            player &&
            player.canControl
        ) {
            player.stop()
        }
    }

    function next() {
        const player =
            root.activePlayer

        if (
            player &&
            player.canGoNext
        ) {
            player.next()
        }
    }

    function previous() {
        const player =
            root.activePlayer

        if (
            player &&
            player.canGoPrevious
        ) {
            player.previous()
        }
    }

    // ============================================================
    // SEEK CONTROL
    // ============================================================

    function seekForward(
        seconds
    ) {
        const player =
            root.activePlayer

        if (
            player &&
            player.canSeek
        ) {
            const value =
                Number(seconds)

            if (
                isFinite(value) &&
                value > 0
            ) {
                player.seek(
                    value
                )
            }
        }
    }

    function seekBackward(
        seconds
    ) {
        const player =
            root.activePlayer

        if (
            player &&
            player.canSeek
        ) {
            const value =
                Number(seconds)

            if (
                isFinite(value) &&
                value > 0
            ) {
                player.seek(
                    -value
                )
            }
        }
    }

    function seekTo(
        seconds
    ) {
        const player =
            root.activePlayer

        if (
            !player ||
            !player.canSeek ||
            !player.positionSupported
        ) {
            return
        }

        const value =
            Number(seconds)

        if (
            !isFinite(value)
        ) {
            return
        }

        let target =
            Math.max(
                0,
                value
            )

        if (
            player.lengthSupported
        ) {
            target =
                Math.min(
                    target,
                    Number(
                        player.length
                    )
                )
        }

        player.position =
            target
    }

    // ============================================================
    // VOLUME CONTROL
    // ============================================================

    function setVolume(
        value
    ) {
        const player =
            root.activePlayer

        if (
            !player ||
            !player.canControl ||
            !player.volumeSupported
        ) {
            return
        }

        const normalized =
            Math.max(
                0,
                Math.min(
                    1,
                    Number(value)
                )
            )

        player.volume =
            normalized
    }

    function setVolumePercent(
        percent
    ) {
        const value =
            Number(percent)

        if (
            !isFinite(value)
        ) {
            return
        }

        root.setVolume(
            value / 100
        )
    }

    function increaseVolumePercent(
        percent
    ) {
        const player =
            root.activePlayer

        if (
            !player ||
            !player.canControl ||
            !player.volumeSupported
        ) {
            return
        }

        let amount =
            Number(percent)

        if (
            !isFinite(amount)
        ) {
            amount =
                root.volumeStep * 100
        }

        root.setVolume(
            root.volume +
            (
                Math.abs(amount) /
                100
            )
        )
    }

    function decreaseVolumePercent(
        percent
    ) {
        const player =
            root.activePlayer

        if (
            !player ||
            !player.canControl ||
            !player.volumeSupported
        ) {
            return
        }

        let amount =
            Number(percent)

        if (
            !isFinite(amount)
        ) {
            amount =
                root.volumeStep * 100
        }

        root.setVolume(
            root.volume -
            (
                Math.abs(amount) /
                100
            )
        )
    }

    // ============================================================
    // SHUFFLE
    // ============================================================

    function setShuffle(
        enabled
    ) {
        const player =
            root.activePlayer

        if (
            !player ||
            !player.canControl ||
            !player.shuffleSupported
        ) {
            return
        }

        player.shuffle =
            Boolean(enabled)
    }

    function toggleShuffle() {
        root.setShuffle(
            !root.isShuffled
        )
    }

    // ============================================================
    // LOOP
    // ============================================================

    function setLoop(
        mode
    ) {
        const player =
            root.activePlayer

        if (
            !player ||
            !player.canControl ||
            !player.loopSupported
        ) {
            return
        }

        const value =
            String(
                mode || ""
            ).toLowerCase()

        switch (value) {
        case "none":
        case "off":
            player.loopState =
                MprisLoopState.None
            break

        case "track":
        case "one":
            player.loopState =
                MprisLoopState.Track
            break

        case "playlist":
        case "all":
            player.loopState =
                MprisLoopState.Playlist
            break

        default:
            break
        }
    }

    // ============================================================
    // RATE
    // ============================================================

    function setRate(
        value
    ) {
        const player =
            root.activePlayer

        if (
            !player ||
            !player.canControl
        ) {
            return
        }

        const rate =
            Number(value)

        if (
            !isFinite(rate)
        ) {
            return
        }

        const bounded =
            Math.max(
                Number(
                    player.minRate
                ),
                Math.min(
                    Number(
                        player.maxRate
                    ),
                    rate
                )
            )

        player.rate =
            bounded
    }

    // ============================================================
    // PLAYER WINDOW CONTROL
    // ============================================================

    function raisePlayer() {
        const player =
            root.activePlayer

        if (
            player &&
            player.canRaise
        ) {
            player.raise()
        }
    }

    function quitPlayer() {
        const player =
            root.activePlayer

        if (
            player &&
            player.canQuit
        ) {
            player.quit()
        }
    }

    function setFullscreen(
        enabled
    ) {
        const player =
            root.activePlayer

        if (
            player &&
            player.canSetFullscreen
        ) {
            player.fullscreen =
                Boolean(enabled)
        }
    }

    function toggleFullscreen() {
        root.setFullscreen(
            !root.isFullscreen
        )
    }

    // ============================================================
    // URI CONTROL
    // ============================================================

    function openUri(
        uri
    ) {
        const player =
            root.activePlayer

        if (!player)
            return

        const value =
            String(
                uri || ""
            )

        if (
            value === ""
        ) {
            return
        }

        player.openUri(
            value
        )
    }

    // ============================================================
    // TEXT HELPERS
    // ============================================================

    function playerName(
        player
    ) {
        if (!player)
            return ""

        const identity =
            String(
                player.identity || ""
            ).trim()

        if (
            identity !== ""
        ) {
            return identity
        }

        const desktopEntry =
            String(
                player.desktopEntry || ""
            ).trim()

        if (
            desktopEntry !== ""
        ) {
            return desktopEntry
        }

        return String(
            player.dbusName || ""
        )
    }

    function metadataValue(
        key
    ) {
        if (
            !root.metadata
        ) {
            return ""
        }

        const value =
            root.metadata[key]

        if (
            value === undefined ||
            value === null
        ) {
            return ""
        }

        if (
            Array.isArray(value)
        ) {
            if (
                value.length === 0
            ) {
                return ""
            }

            return String(
                value[0]
            )
        }

        return String(
            value
        )
    }

    // ============================================================
    // DURATION FORMATTER
    // ============================================================

    function formatDuration(
        seconds
    ) {
        const value =
            Number(seconds)

        if (
            !isFinite(value) ||
            value < 0
        ) {
            return "0:00"
        }

        const totalSeconds =
            Math.floor(
                value
            )

        const hours =
            Math.floor(
                totalSeconds / 3600
            )

        const minutes =
            Math.floor(
                (
                    totalSeconds %
                    3600
                ) / 60
            )

        const secs =
            totalSeconds % 60

        const minuteText =
            hours > 0
                ? String(
                      minutes
                  ).padStart(
                      2,
                      "0"
                  )
                : String(
                      minutes
                  )

        const secondText =
            String(
                secs
            ).padStart(
                2,
                "0"
            )

        if (
            hours > 0
        ) {
            return (
                String(hours) +
                ":" +
                minuteText +
                ":" +
                secondText
            )
        }

        return (
            minuteText +
            ":" +
            secondText
        )
    }

    // ============================================================
    // ICON HELPERS
    // ============================================================

    function playbackIconForPlayer(
        player
    ) {
        if (!player)
            return "󰐊"

        if (
            player.isPlaying
        ) {
            return "󰏤"
        }

        if (
            player.playbackState ===
                MprisPlaybackState.Paused
        ) {
            return "󰐊"
        }

        return "󰐊"
    }

    function playbackIconKeyForPlayer(
        player
    ) {
        if (!player)
            return "play"

        if (
            player.isPlaying
        ) {
            return "pause"
        }

        if (
            player.playbackState ===
                MprisPlaybackState.Paused
        ) {
            return "play"
        }

        return "play"
    }

    function iconForPlayer(
        player
    ) {
        if (!player)
            return "󰝚"

        const text =
            (
                String(
                    player.identity || ""
                ) +
                " " +
                String(
                    player.desktopEntry || ""
                )
            ).toLowerCase()

        if (
            text.indexOf("spotify") >= 0
        ) {
            return "󰓇"
        }

        if (
            text.indexOf("firefox") >= 0 ||
            text.indexOf("youtube") >= 0
        ) {
            return "󰗃"
        }

        if (
            text.indexOf("vlc") >= 0
        ) {
            return "󰕼"
        }

        if (
            text.indexOf("mpv") >= 0
        ) {
            return "󰐹"
        }

        if (
            text.indexOf("rhythmbox") >= 0
        ) {
            return "󰎆"
        }

        if (
            text.indexOf("clementine") >= 0
        ) {
            return "󰎆"
        }

        return "󰝚"
    }

    function iconKeyForPlayer(
        player
    ) {
        if (!player)
            return "music"

        const text =
            (
                String(
                    player.identity || ""
                ) +
                " " +
                String(
                    player.desktopEntry || ""
                )
            ).toLowerCase()

        if (
            text.indexOf("spotify") >= 0
        ) {
            return "spotify"
        }

        if (
            text.indexOf("firefox") >= 0 ||
            text.indexOf("youtube") >= 0
        ) {
            return "browser-media"
        }

        if (
            text.indexOf("vlc") >= 0
        ) {
            return "vlc"
        }

        if (
            text.indexOf("mpv") >= 0
        ) {
            return "mpv"
        }

        return "music"
    }

    // ============================================================
    // PLAYER SERIALIZATION
    // ============================================================

    function playerInfo(
        player
    ) {
        if (!player)
            return {}

        const length =
            Number(
                player.length
            )

        const position =
            Number(
                player.position
            )

        const progress =
            player.lengthSupported &&
            isFinite(length) &&
            length > 0
                ? Math.max(
                      0,
                      Math.min(
                          1,
                          position /
                          length
                      )
                  )
                : 0

        return {
            id:
                String(
                    player.dbusName || ""
                ),

            name:
                root.playerName(
                    player
                ),

            identity:
                String(
                    player.identity || ""
                ),

            desktopEntry:
                String(
                    player.desktopEntry || ""
                ),

            trackId:
                Number(
                    player.uniqueId
                ),

            title:
                String(
                    player.trackTitle || ""
                ),

            artist:
                String(
                    player.trackArtist || ""
                ),

            album:
                String(
                    player.trackAlbum || ""
                ),

            albumArtist:
                String(
                    player.trackAlbumArtist || ""
                ),

            artUrl:
                String(
                    player.trackArtUrl || ""
                ),

            playbackState:
                MprisPlaybackState.toString(
                    player.playbackState
                ),

            isPlaying:
                !!player.isPlaying,

            position:
                position,

            length:
                length,

            progress:
                progress,

            progressPercent:
                Math.round(
                    progress * 100
                ),

            positionText:
                root.formatDuration(
                    position
                ),

            lengthText:
                root.formatDuration(
                    length
                ),

            isPositionSupported:
                !!player.positionSupported,

            isLengthSupported:
                !!player.lengthSupported,

            volume:
                player.volumeSupported
                    ? Number(
                          player.volume
                      ) * 100
                    : 0,

            isVolumeSupported:
                !!player.volumeSupported,

            isShuffled:
                player.shuffleSupported
                    ? !!player.shuffle
                    : false,

            isShuffleSupported:
                !!player.shuffleSupported,

            loopState:
                MprisLoopState.toString(
                    player.loopState
                ),

            isLoopSupported:
                !!player.loopSupported,

            rate:
                Number(
                    player.rate
                ),

            minRate:
                Number(
                    player.minRate
                ),

            maxRate:
                Number(
                    player.maxRate
                ),

            isFullscreen:
                player.canSetFullscreen
                    ? !!player.fullscreen
                    : false,

            isFullscreenSupported:
                !!player.canSetFullscreen,

            canControl:
                !!player.canControl,

            canPlay:
                !!player.canPlay,

            canPause:
                !!player.canPause,

            canTogglePlaying:
                !!player.canTogglePlaying,

            canSeek:
                !!player.canSeek,

            canGoNext:
                !!player.canGoNext,

            canGoPrevious:
                !!player.canGoPrevious,

            canRaise:
                !!player.canRaise,

            canQuit:
                !!player.canQuit,

            icon:
                root.iconForPlayer(
                    player
                ),

            iconKey:
                root.iconKeyForPlayer(
                    player
                )
        }
    }

    // ============================================================
    // ACTIVE METADATA SERIALIZATION
    // ============================================================

    function activeMetadataInfo() {
        const player =
            root.activePlayer

        if (!player) {
            return {
                title: "",
                artist: "",
                album: "",
                albumArtist: "",
                artUrl: "",
                url: "",
                metadata: {}
            }
        }

        return {
            title:
                String(
                    player.trackTitle || ""
                ),

            artist:
                String(
                    player.trackArtist || ""
                ),

            album:
                String(
                    player.trackAlbum || ""
                ),

            albumArtist:
                String(
                    player.trackAlbumArtist || ""
                ),

            artUrl:
                String(
                    player.trackArtUrl || ""
                ),

            url:
                root.metadataValueFromPlayer(
                    player,
                    "xesam:url"
                ),

            metadata:
                player.metadata
        }
    }

    function metadataValueFromPlayer(
        player,
        key
    ) {
        if (
            !player ||
            !player.metadata
        ) {
            return ""
        }

        const value =
            player.metadata[key]

        if (
            value === undefined ||
            value === null
        ) {
            return ""
        }

        if (
            Array.isArray(value)
        ) {
            return value.length > 0
                ? String(
                      value[0]
                  )
                : ""
        }

        return String(
            value
        )
    }

    // ============================================================
    // COMPLETE STATUS
    // ============================================================

    function statusInfo() {
        return {
            isAvailable:
                root.isAvailable,

            playerCount:
                root.playerCount,

            activePlayer:
                root.activePlayerId,

            activePlayerName:
                root.activePlayerName,

            activePlayerIdentity:
                root.activePlayerIdentity,

            title:
                root.title,

            artist:
                root.artist,

            album:
                root.album,

            albumArtist:
                root.albumArtist,

            artUrl:
                root.artUrl,

            playbackState:
                root.playbackState,

            isPlaying:
                root.isPlaying,

            isPaused:
                root.isPaused,

            isStopped:
                root.isStopped,

            position:
                root.position,

            length:
                root.length,

            progress:
                root.progress,

            progressPercent:
                root.progressPercent,

            positionText:
                root.positionText,

            lengthText:
                root.lengthText,

            remainingText:
                root.remainingText,

            volume:
                root.volumePercent,

            isVolumeSupported:
                root.isVolumeSupported,

            isShuffled:
                root.isShuffled,

            isShuffleSupported:
                root.isShuffleSupported,

            loopState:
                root.loopState,

            isLoopSupported:
                root.isLoopSupported,

            rate:
                root.rate,

            minRate:
                root.minRate,

            maxRate:
                root.maxRate,

            isFullscreen:
                root.isFullscreen,

            isFullscreenSupported:
                root.isFullscreenSupported,

            canControl:
                root.canControl,

            canPlay:
                root.canPlay,

            canPause:
                root.canPause,

            canTogglePlaying:
                root.canTogglePlaying,

            canSeek:
                root.canSeek,

            canNext:
                root.canNext,

            canPrevious:
                root.canPrevious,

            canRaise:
                root.canRaise,

            canQuit:
                root.canQuit,

            icon:
                root.icon,

            iconKey:
                root.iconKey,

            playbackIcon:
                root.playbackIcon,

            playbackIconKey:
                root.playbackIconKey
        }
    }
}