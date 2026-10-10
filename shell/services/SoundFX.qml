pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import QtMultimedia

import qs.services

Singleton {
    id: root


    // ============================================================
    // PUBLIC STATE
    // ============================================================

    readonly property string profile: {
        Config.revision
        return root._currentProfile()
    }

    readonly property bool isEnabled: {
        Config.revision
        return root._currentProfileEnabled()
    }

    readonly property real masterVolume: {
        Config.revision
        return root._masterVolume()
    }


    /*
        All currently existing playback voices.

        One-shot:
            multiple allowed

        Loop:
            one per sound name
    */
    property var voices:
        []


    readonly property int activeVoiceCount:
        root._activeVoiceCount()


    readonly property var looping:
        root._loopingNames()


    readonly property var loaded:
        root._loadedNames()


    // ============================================================
    // SIGNALS
    // ============================================================

    signal soundStarted(
        string name
    )

    signal soundFinished(
        string name
    )

    signal loopStarted(
        string name
    )

    signal loopStopped(
        string name
    )

    signal playbackError(
        string name,
        string errorString
    )

    signal configurationChanged()


    // ============================================================
    // DEFAULTS
    // ============================================================

    readonly property real defaultMasterVolume:
        1.0

    readonly property bool defaultProfileEnabled:
        true


    // ============================================================
    // GET SFX
    // ============================================================

    /*
        getSFX("click")

            -> whole sound object


        getSFX("click.path")

            -> path


        getSFX({
            name: "click",
            profile: "gaming"
        })

            -> whole sound from gaming


        getSFX({
            name: "click",
            property: "path",
            profile: "gaming"
        })

            -> path from gaming


        Sound names are intentionally the public namespace.

        There is no:

            sound.click
            sounds.click
            soundfx.sounds.click

        externally.
    */
    function getSFX(
        obj
    ) {
        var target =
            root._parseTarget(
                obj
            )


        if (
            target.name === ""
        ) {
            return null
        }


        var profile =
            root._profileName(
                target.profile
            )


        var sounds =
            root._soundsForProfile(
                profile
            )


        /*
            `target.name` is the sound object itself.

                getSFX("1")
                    -> sounds["1"]

                getSFX("1.path")
                    -> sounds["1"].path

            The previous implementation looked only at
            `target.property`, which is empty for `getSFX("1")`.
            That returned the entire `sounds` object instead of
            the requested sound and made `_definition()` fail.
        */
        var value =
            root._deepGet(
                sounds,
                target.name,
                null
            )


        if (
            target.property !== ""
        ) {
            value =
                root._deepGet(
                    value,
                    target.property,
                    null
                )
        }


        return value
    }


    // ============================================================
    // SET SFX
    // ============================================================

    /*
        Whole object:

            setSFX(
                "click",
                {
                    path: "...",
                    volume: 0.8,
                    preload: true,
                    enabled: true
                }
            )


        Single property:

            setSFX(
                "click.path",
                "/usr/share/N0ctOS/sounds/click.mp3"
            )


        Scoped profile:

            setSFX(
                {
                    name: "click",
                    profile: "gaming"
                },
                {...}
            )


        IMPORTANT:

            Config.set() is used directly.

        Therefore a missing object/path is automatically created.
    */
    function setSFX(
        obj,
        data
    ) {
        var target =
            root._parseTarget(
                obj
            )


        if (
            target.name === ""
        ) {
            return false
        }


        var profile =
            root._profileName(
                target.profile
            )


        var configPath =
            root._soundConfigPath(
                profile,
                target.name,
                target.property
            )


        Config.set(
            configPath,
            data
        )


        return true
    }


    // ============================================================
    // IS ENABLED
    // ============================================================

    /*
        isEnabled("click")

        isEnabled({
            name: "click",
            profile: "gaming"
        })
    */
    function isSFXEnabled(
        obj
    ) {
        var target =
            root._parseTarget(
                obj
            )


        target.property =
            "enabled"


        return Boolean(
            root.getSFX(
                target
            )
        )
    }


    // ============================================================
    // STATUS
    // ============================================================

    function getStatus() {
        return {
            ready:
                Boolean(
                    Config.isReady
                ),

            profile:
                root._currentProfile(),

            isEnabled:
                root._currentProfileEnabled(),

            masterVolume:
                root._masterVolume(),

            activeVoiceCount:
                root._activeVoiceCount(),

            looping:
                root._loopingNames(),

            loaded:
                root._loadedNames()
        }
    }


    // ============================================================
    // PROFILE API
    // ============================================================

    /*
        Create a profile.

        Returns false if it already exists.
    */
    function createProfile(
        name,
        data
    ) {
        var profileName =
            root._cleanProfileName(
                name
            )


        if (
            profileName === ""
        ) {
            return false
        }


        if (
            root._hasProfile(
                profileName
            )
        ) {
            return false
        }


        if (
            !data ||
            typeof data !== "object" ||
            Array.isArray(
                data
            )
        ) {
            return false
        }


        Config.set(
            "soundfx.profiles." +
            profileName,
            data
        )


        return true
    }


    function getProfile(
        name
    ) {
        var profileName =
            root._cleanProfileName(
                name
            )


        if (
            profileName === ""
        ) {
            return null
        }


        return Config.get(
            "soundfx.profiles." +
            profileName,
            null
        )
    }


    function renameProfile(
        from,
        to
    ) {
        var source =
            root._cleanProfileName(
                from
            )

        var destination =
            root._cleanProfileName(
                to
            )


        if (
            source === "" ||
            destination === "" ||
            source === destination
        ) {
            return false
        }


        if (
            !root._hasProfile(
                source
            )
        ) {
            return false
        }


        if (
            root._hasProfile(
                destination
            )
        ) {
            return false
        }


        var data =
            root.getProfile(
                source
            )


        if (
            data === null ||
            data === undefined
        ) {
            return false
        }


        /*
            Write the new profile first.

            Then remove the old one.
        */
        Config.set(
            "soundfx.profiles." +
            destination,
            data
        )


        Config.remove(
            "soundfx.profiles." +
            source
        )


        if (
            root._currentProfile() === source
        ) {
            Config.set(
                "soundfx.profile",
                destination
            )
        }


        return true
    }


    function selectProfile(
        name
    ) {
        var profileName =
            root._cleanProfileName(
                name
            )


        if (
            profileName === ""
        ) {
            return false
        }


        if (
            !root._hasProfile(
                profileName
            )
        ) {
            return false
        }


        if (
            root._currentProfile() !== profileName
        ) {
            root._stopAllVoices()
        }


        Config.set(
            "soundfx.profile",
            profileName
        )


        return true
    }


    function removeProfile(
        name
    ) {
        var profileName =
            root._cleanProfileName(
                name
            )


        if (
            profileName === ""
        ) {
            return false
        }


        /*
            Keep the default profile as the permanent fallback.
        */
        if (
            profileName === "default"
        ) {
            return false
        }


        if (
            !root._hasProfile(
                profileName
            )
        ) {
            return false
        }


        var current =
            root._currentProfile()


        if (
            current === profileName
        ) {
            Config.set(
                "soundfx.profile",
                "default"
            )

            root._stopAllVoices()
        }


        Config.remove(
            "soundfx.profiles." +
            profileName
        )


        return true
    }


    // ============================================================
    // MASTER VOLUME
    // ============================================================

    /*
        No 0..1 cap.

        The configured value is retained exactly.

        Qt AudioOutput applies its own final playback range.
    */
    function setMasterVolume(
        value
    ) {
        var volume =
            Number(
                value
            )


        if (
            !isFinite(
                volume
            )
        ) {
            return false
        }


        Config.set(
            "soundfx.masterVolume",
            volume
        )


        return true
    }


    function getMasterVolume() {
        return root._masterVolume()
    }


    // ============================================================
    // PLAY ONE-SHOT
    // ============================================================

    function play(
        name
    ) {
        var soundName =
            String(
                name === undefined ||
                name === null
                    ? ""
                    : name
            )


        if (
            soundName === ""
        ) {
            return false
        }


        if (
            !root._currentProfileEnabled()
        ) {
            return false
        }


        var definition =
            root._definition(
                soundName
            )


        if (
            !definition ||
            !definition.enabled ||
            definition.path === ""
        ) {
            return false
        }


        /*
            Reuse an idle retained/preloaded voice first.
        */
        var voice =
            root._findIdleVoice(
                soundName,
                false
            )


        /*
            A preloaded voice can be busy.

            In that case, create a second temporary voice so
            one-shots are allowed to overlap.
        */
        if (
            !voice
        ) {
            voice =
                root._createVoice(
                    soundName,
                    false,
                    definition.preload
                )
        }


        if (
            !voice
        ) {
            return false
        }


        voice.configure(
            definition,
            false,
            definition.preload
        )


        if (
            !voice.start()
        ) {
            return false
        }


        root.soundStarted(
            soundName
        )


        return true
    }


    // ============================================================
    // LOOP
    // ============================================================

    function loop(
        name
    ) {
        var soundName =
            String(
                name === undefined ||
                name === null
                    ? ""
                    : name
            )


        if (
            soundName === ""
        ) {
            return false
        }


        if (
            !root._currentProfileEnabled()
        ) {
            return false
        }


        var definition =
            root._definition(
                soundName
            )


        if (
            !definition ||
            !definition.enabled ||
            definition.path === ""
        ) {
            return false
        }


        /*
            Exactly one loop voice per sound.
        */
        var existing =
            root._findLoopVoice(
                soundName
            )


        if (
            existing
        ) {
            if (
                existing.busy
            ) {
                return true
            }


            existing.configure(
                definition,
                true,
                definition.preload
            )


            if (
                existing.start()
            ) {
                root.loopStarted(
                    soundName
                )

                return true
            }


            return false
        }


        var voice =
            root._createVoice(
                soundName,
                true,
                definition.preload
            )


        if (
            !voice
        ) {
            return false
        }


        voice.configure(
            definition,
            true,
            definition.preload
        )


        if (
            !voice.start()
        ) {
            return false
        }


        root.loopStarted(
            soundName
        )


        return true
    }


    function stop(
        name
    ) {
        var voice =
            root._findLoopVoice(
                String(
                    name
                )
            )


        if (
            !voice
        ) {
            return false
        }


        voice.stopLoop()


        return true
    }


    function stopAllLoops() {
        var copy =
            root.voices.slice()


        for (
            var i = 0;
            i < copy.length;
            ++i
        ) {
            var voice =
                copy[i]


            if (
                voice &&
                voice.isLoop
            ) {
                voice.stopLoop()
            }
        }


        return true
    }


    function isLooping(
        name
    ) {
        var voice =
            root._findLoopVoice(
                String(
                    name
                )
            )


        return Boolean(
            voice &&
            voice.busy
        )
    }


    // ============================================================
    // TARGET PARSING
    // ============================================================

    /*
        Supported:

            "click"

            "click.path"

            {
                name: "click",
                profile: "gaming"
            }

            {
                name: "click",
                property: "path",
                profile: "gaming"
            }

        The string form is intentionally the simple/common form.
    */
    function _parseTarget(
        obj
    ) {
        var result = {
            name:
                "",

            property:
                "",

            profile:
                undefined
        }


        // --------------------------------------------------------
        // Object target
        // --------------------------------------------------------

        if (
            obj &&
            typeof obj === "object" &&
            !Array.isArray(
                obj
            )
        ) {
            if (
                obj.name !== undefined &&
                obj.name !== null
            ) {
                var rawName =
                    String(
                        obj.name
                    )
            } else if (
                obj.path !== undefined &&
                obj.path !== null &&
                obj.property === undefined
            ) {
                var rawName =
                    String(
                        obj.path
                    )
            } else {
                var rawName =
                    ""
            }


            /*
                A structured target may use:

                    name
                    property

                and optionally:

                    profile
            */
            result.name =
                rawName


            if (
                obj.property !== undefined &&
                obj.property !== null
            ) {
                result.property =
                    String(
                        obj.property
                    )
            }


            if (
                obj.profile !== undefined &&
                obj.profile !== null &&
                String(
                    obj.profile
                ).trim() !== ""
            ) {
                result.profile =
                    String(
                        obj.profile
                    )
            }


            /*
                Convenience:

                    {
                        path: "click.volume",
                        profile: "gaming"
                    }

                when no name/property is supplied.
            */
            if (
                result.name.indexOf(
                    "."
                ) >= 0 &&
                result.property === ""
            ) {
                root._splitTargetPath(
                    result
                )
            }


            return result
        }


        // --------------------------------------------------------
        // String target
        // --------------------------------------------------------

        var value =
            obj === undefined ||
            obj === null
                ? ""
                : String(
                    obj
                )


        result.name =
            value


        if (
            value.indexOf(
                "."
            ) >= 0
        ) {
            root._splitTargetPath(
                result
            )
        }


        return result
    }


    function _splitTargetPath(
        target
    ) {
        var value =
            String(
                target.name
            )


        var index =
            value.indexOf(
                "."
            )


        if (
            index < 0
        ) {
            return
        }


        target.name =
            value.slice(
                0,
                index
            )


        target.property =
            value.slice(
                index + 1
            )
    }


    // ============================================================
    // CONFIG HELPERS
    // ============================================================

    function _cleanProfileName(
        name
    ) {
        if (
            name === undefined ||
            name === null
        ) {
            return ""
        }


        return String(
            name
        ).trim()
    }


    function _profileName(
        requested
    ) {
        var explicit =
            root._cleanProfileName(
                requested
            )


        if (
            explicit !== ""
        ) {
            return explicit
        }


        var selected =
            Config.get(
                "soundfx.profile",
                "default"
            )


        var result =
            root._cleanProfileName(
                selected
            )


        if (
            result === ""
        ) {
            return "default"
        }


        return result
    }


    function _hasProfile(
        name
    ) {
        return Config.has(
            "soundfx.profiles." +
            name
        )
    }


    function _profileObject(
        name
    ) {
        var value =
            Config.get(
                "soundfx.profiles." +
                name,
                null
            )


        if (
            !value ||
            typeof value !== "object" ||
            Array.isArray(
                value
            )
        ) {
            return null
        }


        return value
    }


    function _soundsForProfile(
        profile
    ) {
        var profileObject =
            root._profileObject(
                profile
            )


        if (
            !profileObject
        ) {
            return {}
        }


        var sounds =
            profileObject.sounds


        if (
            !sounds ||
            typeof sounds !== "object" ||
            Array.isArray(
                sounds
            )
        ) {
            return {}
        }


        return sounds
    }


    function _currentProfile() {
        return root._profileName()
    }


    function _currentProfileObject() {
        return root._profileObject(
            root._currentProfile()
        )
    }


    function _currentProfileEnabled() {
        var profileObject =
            root._currentProfileObject()


        if (
            !profileObject
        ) {
            return true
        }


        return (
            profileObject.enabled !== false
        )
    }


    function _masterVolume() {
        var value =
            Number(
                Config.get(
                    "soundfx.masterVolume",
                    root.defaultMasterVolume
                )
            )


        if (
            !isFinite(
                value
            )
        ) {
            return root.defaultMasterVolume
        }


        /*
            NO CLAMP.
        */
        return value
    }


    function _definition(
        name
    ) {
        var value =
            root.getSFX(
                String(
                    name
                )
            )


        if (
            !value ||
            typeof value !== "object" ||
            Array.isArray(
                value
            )
        ) {
            return null
        }


        var path =
            value.path === undefined ||
            value.path === null
                ? ""
                : String(
                    value.path
                )


        var volume =
            Number(
                value.volume
            )


        if (
            !isFinite(
                volume
            )
        ) {
            volume =
                1.0
        }


        return {
            name:
                String(
                    name
                ),

            path:
                path,

            volume:
                volume,

            preload:
                value.preload === true,

            enabled:
                value.enabled !== false
        }
    }


    function _soundConfigPath(
        profile,
        name,
        property
    ) {
        var result =
            "soundfx.profiles." +
            String(
                profile
            ) +
            ".sounds." +
            String(
                name
            )


        if (
            property !== undefined &&
            property !== null &&
            String(
                property
            ) !== ""
        ) {
            result +=
                "." +
                String(
                    property
                )
        }


        return result
    }


    function _deepGet(
        object,
        path,
        fallback
    ) {
        if (
            path === undefined ||
            path === null ||
            String(
                path
            ) === ""
        ) {
            return object
        }


        var current =
            object


        var parts =
            String(
                path
            ).split(
                "."
            )


        for (
            var i = 0;
            i < parts.length;
            ++i
        ) {
            var key =
                parts[i]


            if (
                current === undefined ||
                current === null ||
                typeof current !== "object" ||
                current[key] === undefined
            ) {
                return fallback
            }


            current =
                current[key]
        }


        return current
    }


    // ============================================================
    // VOICE COMPONENT
    // ============================================================

    Component {
        id:
            voiceComponent


        Item {
            id:
                voice


            visible: false
            width: 1
            height: 1


            property string soundName:
                ""

            property bool isLoop:
                false

            property bool keepLoaded:
                false

            property bool busy:
                false

            property bool started:
                false

            property bool stale:
                false

            property var definition:
                null

            // These explicitly expose the child objects to the parent
            // service. Child QML ids are lexical, so callers outside this
            // Item should not rely on voice.player / voice.releaseTimer.
            readonly property var playerObject:
                player

            readonly property var releaseTimerObject:
                releaseTimer


            function configure(
                newDefinition,
                loopMode,
                retainLoaded
            ) {
                /*
                    Stop old playback before changing source.
                */
                started =
                    false

                busy =
                    false

                stale =
                    false


                player.stop()

                player.source =
                    ""


                definition = {
                    name:
                        String(
                            newDefinition.name
                        ),

                    path:
                        String(
                            newDefinition.path
                        ),

                    volume:
                        Number(
                            newDefinition.volume
                        ),

                    preload:
                        Boolean(
                            newDefinition.preload
                        ),

                    enabled:
                        Boolean(
                            newDefinition.enabled
                        )
                }


                if (
                    !isFinite(
                        definition.volume
                    )
                ) {
                    definition.volume =
                        1.0
                }


                soundName =
                    definition.name

                isLoop =
                    Boolean(
                        loopMode
                    )

                keepLoaded =
                    Boolean(
                        retainLoaded
                    )


                /*
                    enabled ALWAYS wins over preload.
                */
                if (
                    !definition.enabled ||
                    definition.path === ""
                ) {
                    return false
                }


                player.loops =
                    isLoop
                        ? MediaPlayer.Infinite
                        : 1


                player.source =
                        definition.path

                return true
            }


            function start() {
                if (
                    !definition ||
                    !definition.enabled ||
                    definition.path === ""
                ) {
                    return false
                }


                releaseTimer.stop()


                player.loops =
                    isLoop
                        ? MediaPlayer.Infinite
                        : 1


                stale =
                    false

                busy =
                    true

                started =
                    true


                player.play()


                return true
            }


            function stopLoop() {
                if (
                    !isLoop
                ) {
                    return false
                }


                var wasBusy =
                    busy


                started =
                    false

                busy =
                    false


                player.stop()


                if (
                    wasBusy
                ) {
                    root.loopStopped(
                        soundName
                    )
                }


                if (
                    !keepLoaded
                ) {
                    releaseTimer.restart()
                }


                return true
            }


            AudioOutput {
                id:
                    output


                /*
                    Sound-specific volume multiplied by the
                    configured global master volume.

                    SoundFX itself does NOT cap masterVolume.
                */
                volume:
                    (
                        voice.definition
                            ? Number(
                                voice.definition.volume
                            )
                            : 1.0
                    ) *
                    Number(
                        root.masterVolume
                    )
            }


            MediaPlayer {
                id:
                    player


                audioOutput:
                    output


                onPlaybackStateChanged: {
                    if (
                        playbackState !==
                        MediaPlayer.StoppedState
                    ) {
                        return
                    }


                    /*
                        stopLoop() and configure() intentionally
                        clear started before calling stop().
                    */
                    if (
                        !voice.started
                    ) {
                        return
                    }


                    voice.started =
                        false

                    var wasBusy =
                        voice.busy

                    voice.busy =
                        false


                    if (
                        voice.isLoop
                    ) {
                        if (
                            wasBusy
                        ) {
                            root.loopStopped(
                                voice.soundName
                            )
                        }


                        if (
                            voice.stale ||
                            !voice.keepLoaded
                        ) {
                            releaseTimer.restart()
                        }


                        return
                    }


                    if (
                        wasBusy
                    ) {
                        root.soundFinished(
                            voice.soundName
                        )
                    }


                    if (
                        voice.stale ||
                        !voice.keepLoaded
                    ) {
                        /*
                            Lazy voices remain available for one
                            second after becoming idle.
                        */
                        releaseTimer.restart()
                    }
                }


                onErrorOccurred: function(
                    error,
                    errorString
                ) {
                    root.playbackError(
                        voice.soundName,
                        String(
                            errorString
                        )
                    )


                    voice.started =
                        false

                    voice.busy =
                        false


                    if (
                        voice.stale ||
                        !voice.keepLoaded
                    ) {
                        releaseTimer.restart()
                    }
                }
            }


            Timer {
                id:
                    releaseTimer


                interval:
                    1000


                repeat:
                    false


                onTriggered: {
                    if (
                        voice.busy
                    ) {
                        return
                    }


                    root._destroyVoice(
                        voice
                    )
                }
            }
        }
    }


    // ============================================================
    // VOICE MANAGEMENT
    // ============================================================

    function _createVoice(
        name,
        loopMode,
        retainLoaded
    ) {
        var voice =
            voiceComponent.createObject(
                root,
                {}
            )


        if (
            !voice
        ) {
            console.warn(
                "[SoundFX] failed to create voice:",
                name
            )

            return null
        }


        voice.soundName =
            String(
                name
            )

        voice.isLoop =
            Boolean(
                loopMode
            )

        voice.keepLoaded =
            Boolean(
                retainLoaded
            )


        var next =
            root.voices.slice()


        next.push(
            voice
        )


        root.voices =
            next


        return voice
    }


    function _destroyVoice(
        voice
    ) {
        if (
            !voice
        ) {
            return
        }


        if (
            voice.busy
        ) {
            return
        }


        var next =
            root.voices.slice()


        var index =
            next.indexOf(
                voice
            )


        if (
            index >= 0
        ) {
            next.splice(
                index,
                1
            )

            root.voices =
                next
        }


        try {
            voice.destroy()
        } catch (error) {
            console.warn(
                "[SoundFX] voice destruction failed:",
                error
            )
        }
    }


    function _findLoopVoice(
        name
    ) {
        var target =
            String(
                name
            )


        for (
            var i = 0;
            i < root.voices.length;
            ++i
        ) {
            var voice =
                root.voices[i]


            if (
                voice &&
                voice.isLoop &&
                voice.soundName === target
            ) {
                return voice
            }
        }


        return null
    }


    function _findIdleVoice(
        name,
        loopMode
    ) {
        var target =
            String(
                name
            )


        for (
            var i = 0;
            i < root.voices.length;
            ++i
        ) {
            var voice =
                root.voices[i]


            if (
                !voice ||
                voice.busy ||
                voice.isLoop !== Boolean(
                    loopMode
                )
            ) {
                continue
            }


            if (
                voice.soundName === target
            ) {
                return voice
            }
        }


        return null
    }


    // ============================================================
    // VOICE STATE
    // ============================================================

    function _activeVoiceCount() {
        var count =
            0


        for (
            var i = 0;
            i < root.voices.length;
            ++i
        ) {
            var voice =
                root.voices[i]


            if (
                voice &&
                voice.busy
            ) {
                ++count
            }
        }


        return count
    }


    function _loopingNames() {
        var result =
            []


        for (
            var i = 0;
            i < root.voices.length;
            ++i
        ) {
            var voice =
                root.voices[i]


            if (
                voice &&
                voice.isLoop &&
                voice.busy
            ) {
                if (
                    result.indexOf(
                        voice.soundName
                    ) < 0
                ) {
                    result.push(
                        voice.soundName
                    )
                }
            }
        }


        return result
    }


    function _loadedNames() {
        var result =
            []


        for (
            var i = 0;
            i < root.voices.length;
            ++i
        ) {
            var voice =
                root.voices[i]


            if (
                voice &&
                voice.definition &&
                voice.definition.path !== ""
            ) {
                if (
                    result.indexOf(
                        voice.soundName
                    ) < 0
                ) {
                    result.push(
                        voice.soundName
                    )
                }
            }
        }


        return result
    }


    function _stopAllVoices() {
        var copy =
            root.voices.slice()


        for (
            var i = 0;
            i < copy.length;
            ++i
        ) {
            var voice =
                copy[i]


            if (
                !voice
            ) {
                continue
            }


            voice.started =
                false

            voice.busy =
                false


            voice.playerObject.stop()

            voice.playerObject.source =
                ""


            root._destroyVoice(
                voice
            )
        }
    }


    // ============================================================
    // PRELOAD RECONCILIATION
    // ============================================================

    function _reconcile() {
        if (
            !Config.isReady
        ) {
            return
        }


        /*
            Global profile disabled:
            everything gets released.
        */
        if (
            !root._currentProfileEnabled()
        ) {
            root._stopAllVoices()

            root.configurationChanged()

            return
        }


        var sounds =
            root._soundsForProfile(
                root._currentProfile()
            )


        var names =
            Object.keys(
                sounds
            )


        var desired =
            ({})
        

        // --------------------------------------------------------
        // Desired preloads
        // --------------------------------------------------------

        for (
            var i = 0;
            i < names.length;
            ++i
        ) {
            var name =
                names[i]


            var definition =
                root._definition(
                    name
                )


            /*
                enabled overrides preload.

                    enabled=false
                    preload=true

                NEVER gets preloaded.
            */
            if (
                !definition ||
                !definition.enabled ||
                !definition.preload ||
                definition.path === ""
            ) {
                continue
            }


            desired[
                name
            ] = true


            var existing =
                root._findIdleVoice(
                    name,
                    false
                )


            if (
                existing &&
                existing.keepLoaded
            ) {
                /*
                    Keep it.

                    If the definition changed, reconfigure it.
                */
                var oldPath =
                    existing.definition
                        ? String(
                            existing.definition.path
                        )
                        : ""

                var oldVolume =
                    existing.definition
                        ? Number(
                            existing.definition.volume
                        )
                        : NaN

                var oldPreload =
                    existing.definition
                        ? Boolean(
                            existing.definition.preload
                        )
                        : false

                var oldEnabled =
                    existing.definition
                        ? Boolean(
                            existing.definition.enabled
                        )
                        : false

                if (
                    oldPath !== definition.path ||
                    oldVolume !== definition.volume ||
                    oldPreload !== definition.preload ||
                    oldEnabled !== definition.enabled
                ) {
                    existing.configure(
                        definition,
                        false,
                        true
                    )
                }


                continue
            }


            /*
                A busy loop/one-shot is not converted into a
                preload voice in the middle of playback.
            */
            var preloadVoice =
                null


            for (
                var j = 0;
                j < root.voices.length;
                ++j
            ) {
                var candidate =
                    root.voices[j]


                if (
                    candidate &&
                    !candidate.isLoop &&
                    candidate.soundName === name &&
                    candidate.keepLoaded
                ) {
                    preloadVoice =
                        candidate

                    break
                }
            }


            if (
                preloadVoice
            ) {
                continue
            }


            var newVoice =
                root._createVoice(
                    name,
                    false,
                    true
                )


            if (
                newVoice
            ) {
                newVoice.configure(
                    definition,
                    false,
                    true
                )
            }
        }


        // --------------------------------------------------------
        // Disable/remove stale voices
        // --------------------------------------------------------

        var copy =
            root.voices.slice()


        for (
            var k = 0;
            k < copy.length;
            ++k
        ) {
            var voice =
                copy[k]


            if (
                !voice
            ) {
                continue
            }


            var currentDefinition =
                root._definition(
                    voice.soundName
                )


            /*
                Sound disappeared or was disabled.

                This is stronger than preload:

                    enabled=false

                means it should not remain loaded or playing.
            */
            if (
                !currentDefinition ||
                !currentDefinition.enabled ||
                currentDefinition.path === ""
            ) {
                voice.stale =
                    true


                if (
                    voice.isLoop
                ) {
                    voice.started =
                        false

                    voice.busy =
                        false

                    voice.playerObject.stop()

                    root.loopStopped(
                        voice.soundName
                    )

                    root._destroyVoice(
                        voice
                    )
                } else if (
                    !voice.busy
                ) {
                    root._destroyVoice(
                        voice
                    )
                }


                continue
            }


            /*
                Existing retained preload whose preload setting
                changed to false must stop being retained.
            */
            if (
                voice.keepLoaded &&
                !currentDefinition.preload
            ) {
                voice.keepLoaded =
                    false


                if (
                    voice.isLoop
                ) {
                    /*
                        A running loop can continue; once stopped,
                        lazy-release behavior applies.
                    */
                    if (
                        !voice.busy
                    ) {
                        voice.releaseTimerObject.restart()
                    }
                } else if (
                    !voice.busy
                ) {
                    /*
                        Release after the normal one-second idle
                        delay rather than immediately.
                    */
                    voice.releaseTimerObject.restart()
                }
            }


            /*
                Preloaded sound was removed from desired preload
                set but is still valid.

                It can remain until the one-second lazy lifecycle
                takes over after its next idle state.
            */
            if (
                voice.keepLoaded &&
                !desired[
                    voice.soundName
                ] &&
                !voice.busy
            ) {
                voice.keepLoaded =
                    false

                voice.releaseTimerObject.restart()
            }
        }


        root.configurationChanged()
    }


    // ============================================================
    // CONFIG REACTIVITY
    // ============================================================

    Connections {
        target:
            Config


        function onIsReadyChanged() {
            if (
                Config.isReady
            ) {
                root._reconcile()
            }
        }


        function onRevisionChanged() {
            if (
                Config.isReady
            ) {
                root._reconcile()
            }
        }
    }


    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target:
            "n0ctos-soundfx"


        // ========================================================
        // STATUS
        // ========================================================

        function getStatus(): string {
            return JSON.stringify(
                root.getStatus()
            )
        }


        // ========================================================
        // PLAY / LOOP / STOP
        // ========================================================

        /*
            One-shot playback:

                qs ipc call n0ctos-soundfx play click

            Start a loop:

                qs ipc call n0ctos-soundfx loop ambient

            Stop a loop:

                qs ipc call n0ctos-soundfx stop ambient

            Stop every active loop:

                qs ipc call n0ctos-soundfx stopAllLoops

            Check whether a sound currently has a running loop:

                qs ipc call n0ctos-soundfx isLooping ambient

            `play()` intentionally has no matching stop IPC because
            one-shot voices are not interceptable by the public API.
        */
        function play(
            name: string
        ): bool {
            return root.play(
                name
            )
        }


        function loop(
            name: string
        ): bool {
            return root.loop(
                name
            )
        }


        function stop(
            name: string
        ): bool {
            return root.stop(
                name
            )
        }


        function stopAllLoops(): bool {
            return root.stopAllLoops()
        }


        function isLooping(
            name: string
        ): bool {
            return root.isLooping(
                name
            )
        }


        // ========================================================
        // MASTER VOLUME GETTER
        // ========================================================

        function getMasterVolume(): real {
            return root.getMasterVolume()
        }


        // ========================================================
        // SET SFX
        // ========================================================

        /*
            Normal:

                qs ipc call \
                    n0ctos-soundfx \
                    setSFX \
                    click \
                    '{"path":"/usr/share/N0ctOS/sounds/click.mp3","volume":0.8,"preload":true,"enabled":true}'


            Nested property:

                qs ipc call \
                    n0ctos-soundfx \
                    setSFX \
                    click.path \
                    '"/usr/share/N0ctOS/sounds/click.mp3"'


            Specific profile:

                qs ipc call \
                    n0ctos-soundfx \
                    setSFX \
                    '{"name":"click","profile":"gaming"}' \
                    '{"path":"/usr/share/N0ctOS/sounds/click.mp3","volume":0.8,"preload":true,"enabled":true}'
        */
        function setSFX(
            obj: string,
            dataJson: string
        ): bool {
            var target =
                obj

            var data


            /*
                Allow the first IPC argument to be either:

                    click
                    click.path

                or a structured target:

                    {"name":"click","profile":"gaming"}
            */
            try {
                var parsedTarget =
                    JSON.parse(
                        obj
                    )

                if (
                    parsedTarget &&
                    typeof parsedTarget === "object" &&
                    !Array.isArray(
                        parsedTarget
                    )
                ) {
                    target =
                        parsedTarget
                }
            } catch (error) {
                /*
                    Plain string target.
                */
            }


            try {
                data =
                    JSON.parse(
                        dataJson
                    )
            } catch (error) {
                console.warn(
                    "[SoundFX] invalid SFX JSON:",
                    dataJson
                )

                return false
            }


            return root.setSFX(
                target,
                data
            )
        }


        // ========================================================
        // GET SFX
        // ========================================================

        /*
            Whole sound:

                qs ipc call n0ctos-soundfx getSFX click

            Nested value:

                qs ipc call n0ctos-soundfx getSFX click.path

            Specific profile:

                qs ipc call \
                    n0ctos-soundfx \
                    getSFX \
                    '{"name":"click","profile":"gaming"}'

            Specific profile + property:

                qs ipc call \
                    n0ctos-soundfx \
                    getSFX \
                    '{"name":"click","property":"path","profile":"gaming"}'
        */
        function getSFX(
            obj: string
        ): string {
            var request =
                obj


            /*
                The public parser also accepts JSON structured
                targets.

                    {
                        name: ...,
                        profile: ...
                    }
            */
            try {
                var parsed =
                    JSON.parse(
                        request
                    )


                if (
                    parsed &&
                    typeof parsed === "object" &&
                    !Array.isArray(
                        parsed
                    )
                ) {
                    request =
                        parsed
                }
            } catch (error) {
                /*
                    Normal string target.
                */
            }


            return JSON.stringify(
                root.getSFX(
                    request
                )
            )
        }


        // ========================================================
        // IS ENABLED
        // ========================================================

        function isEnabled(
            obj: string
        ): bool {
            var request =
                obj


            try {
                var parsed =
                    JSON.parse(
                        request
                    )


                if (
                    parsed &&
                    typeof parsed === "object" &&
                    !Array.isArray(
                        parsed
                    )
                ) {
                    request =
                        parsed
                }
            } catch (error) {
            }


            return root.isSFXEnabled(
                request
            )
        }


        // ========================================================
        // CREATE PROFILE
        // ========================================================

        function createProfile(
            name: string,
            dataJson: string
        ): bool {
            var data


            try {
                data =
                    JSON.parse(
                        dataJson
                    )
            } catch (error) {
                console.warn(
                    "[SoundFX] invalid profile JSON:",
                    dataJson
                )

                return false
            }


            return root.createProfile(
                name,
                data
            )
        }


        // ========================================================
        // GET PROFILE
        // ========================================================

        function getProfile(
            name: string
        ): string {
            return JSON.stringify(
                root.getProfile(
                    name
                )
            )
        }


        // ========================================================
        // RENAME PROFILE
        // ========================================================

        function renameProfile(
            from: string,
            to: string
        ): bool {
            return root.renameProfile(
                from,
                to
            )
        }


        // ========================================================
        // SELECT PROFILE
        // ========================================================

        function selectProfile(
            name: string
        ): bool {
            return root.selectProfile(
                name
            )
        }


        // ========================================================
        // REMOVE PROFILE
        // ========================================================

        function removeProfile(
            name: string
        ): bool {
            return root.removeProfile(
                name
            )
        }


        // ========================================================
        // MASTER VOLUME
        // ========================================================

        function setMasterVolume(
            value: real
        ): bool {
            return root.setMasterVolume(
                value
            )
        }
    }


    // ============================================================
    // INITIALIZATION
    // ============================================================

    Component.onCompleted: {
        if (
            Config.isReady
        ) {
            if (
                !root._hasProfile(
                    "default"
                )
            ) {
                Config.set(
                    "soundfx.profiles.default",
                    {
                        enabled: true,
                        sounds: {}
                    }
                )
            }

            root._reconcile()
        }
    }
}