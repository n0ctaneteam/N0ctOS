pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // ============================================================
    // CONFIGURATION
    // ============================================================

    readonly property int step:
        root.normalizeStep(
            Config.get(
                "audio.step",
                5
            )
        )

    readonly property var outputPriority:
        root.normalizePriority(
            Config.get(
                "audio.outputPriority",
                []
            )
        )

    readonly property var inputPriority:
        root.normalizePriority(
            Config.get(
                "audio.inputPriority",
                []
            )
        )

    // ============================================================
    // PIPEWIRE STATE
    // ============================================================

    readonly property bool isReady:
        Pipewire.ready

    readonly property var allNodes:
        Pipewire.nodes

    // ============================================================
    // AUDIO NODE MODELS
    // ============================================================

    ScriptModel {
        id: audioNodeModel

        values:
            Pipewire.nodes.values.filter(
                function(node) {
                    return (
                        node &&
                        node.audio !== null
                    )
                }
            )
    }

    /*
     * Bind only audio nodes because volume,
     * mute, channels and properties are
     * invalid until a node is tracked.
     */
    PwObjectTracker {
        objects:
            audioNodeModel.values
    }

    ScriptModel {
        id: outputModel

        values:
            audioNodeModel.values.filter(
                function(node) {
                    return (
                        node &&
                        !node.isStream &&
                        node.isSink &&
                        node.audio !== null
                    )
                }
            )
    }

    ScriptModel {
        id: inputModel

        values:
            audioNodeModel.values.filter(
                function(node) {
                    return (
                        node &&
                        !node.isStream &&
                        !node.isSink &&
                        node.audio !== null
                    )
                }
            )
    }

    ScriptModel {
        id: streamModel

        values:
            audioNodeModel.values.filter(
                function(node) {
                    return (
                        node &&
                        node.isStream &&
                        node.audio !== null
                    )
                }
            )
    }

    readonly property var outputs:
        outputModel

    readonly property var inputs:
        inputModel

    readonly property var streams:
        streamModel

    readonly property var outputList:
        outputModel.values

    readonly property var inputList:
        inputModel.values

    readonly property var streamList:
        streamModel.values

    readonly property var devices:
        audioNodeModel

    readonly property var deviceList:
        audioNodeModel.values

    // ============================================================
    // DEFAULT DEVICES
    // ============================================================

    readonly property var defaultOutput:
        Pipewire.defaultAudioSink

    readonly property var defaultInput:
        Pipewire.defaultAudioSource

    readonly property var preferredOutput:
        root._preferred(
            root.outputList,
            root.outputPriority
        )

    readonly property var preferredInput:
        root._preferred(
            root.inputList,
            root.inputPriority
        )

    // ============================================================
    // OUTPUT STATE
    // ============================================================

    readonly property real volume:
        root._nodeVolume(
            root.defaultOutput
        )

    readonly property real percent:
        root.volume

    readonly property int percentRounded:
        Math.round(
            root.percent
        )

    readonly property string percentText:
        String(
            root.percentRounded
        ) + "%"

    readonly property bool isMuted:
        root._nodeMuted(
            root.defaultOutput
        )

    readonly property bool hasOutput:
        !!root.defaultOutput

    readonly property string outputName:
        root.displayName(
            root.defaultOutput
        )

    readonly property string outputIcon:
        root.icon(
            root.defaultOutput
        )

    // ============================================================
    // INPUT STATE
    // ============================================================

    readonly property real inputVolume:
        root._nodeVolume(
            root.defaultInput
        )

    readonly property int inputPercent:
        Math.round(
            root.inputVolume
        )

    readonly property string inputPercentText:
        String(
            root.inputPercent
        ) + "%"

    readonly property bool isInputMuted:
        root._nodeMuted(
            root.defaultInput
        )

    readonly property bool hasInput:
        !!root.defaultInput

    readonly property string inputName:
        root.displayName(
            root.defaultInput
        )

    readonly property string inputIcon:
        root.icon(
            root.defaultInput
        )

    // ============================================================
    // SIGNALS
    // ============================================================

    signal outputChanged(var node)
    signal inputChanged(var node)
    signal streamChanged(var node)

    // ============================================================
    // PIPEWIRE MODEL CHANGES
    // ============================================================

    Connections {
        target: Pipewire.nodes

        function onObjectInsertedPost(
            node,
            index
        ) {
            if (!node)
                return

            if (node.isStream)
                root.streamChanged(node)
        }

        function onObjectRemovedPost(
            node,
            index
        ) {
            /*
             * PipeWire owns node lifetimes.
             * We intentionally don't retain removed nodes.
             */
        }
    }

    Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged() {
            root.outputChanged(
                Pipewire.defaultAudioSink
            )
        }

        function onDefaultAudioSourceChanged() {
            root.inputChanged(
                Pipewire.defaultAudioSource
            )
        }
    }

    // ============================================================
    // CONFIG REACTIVITY
    // ============================================================

    Connections {
        target: Config

        function onExternalReload() {
            /*
             * Properties such as outputPriority are
             * binding-driven, so no explicit reload
             * operation is necessary.
             */
        }
    }

    // ============================================================
    // NODE RESOLUTION
    // ============================================================

    function nodeForId(
        id
    ) {
        const numeric =
            Number(id)

        if (!isFinite(numeric))
            return null

        for (
            let i = 0;
            i < root.deviceList.length;
            ++i
        ) {
            const node =
                root.deviceList[i]

            if (
                node &&
                Number(node.id) ===
                    numeric
            ) {
                return node
            }
        }

        return null
    }

    function nodeForName(
        name
    ) {
        if (!name)
            return null

        const value =
            String(name)

        for (
            let i = 0;
            i < root.deviceList.length;
            ++i
        ) {
            const node =
                root.deviceList[i]

            if (!node)
                continue

            if (
                String(node.name) ===
                    value ||
                root.displayName(node) ===
                    value
            ) {
                return node
            }
        }

        return null
    }

    function resolveNode(
        value
    ) {
        if (!value)
            return null

        if (
            typeof value ===
            "object"
        ) {
            if (
                value.audio !== undefined
            ) {
                return value
            }

            return null
        }

        const asString =
            String(value)

        if (
            /^\d+$/.test(
                asString
            )
        ) {
            return root.nodeForId(
                Number(asString)
            )
        }

        return root.nodeForName(
            asString
        )
    }

    // ============================================================
    // DEFAULT / PRIORITY
    // ============================================================

    function _preferred(
        nodes,
        priority
    ) {
        for (
            let i = 0;
            i < priority.length;
            ++i
        ) {
            const wanted =
                priority[i]

            for (
                let j = 0;
                j < nodes.length;
                ++j
            ) {
                const node =
                    nodes[j]

                if (
                    node &&
                    (
                        String(node.name) ===
                            wanted ||
                        String(node.id) ===
                            wanted
                    )
                ) {
                    return node
                }
            }
        }

        return nodes.length > 0
            ? nodes[0]
            : null
    }

    function setOutput(
        value
    ) {
        const node =
            root.resolveNode(
                value
            )

        if (
            !node ||
            !node.isSink ||
            node.isStream
        ) {
            return false
        }

        /*
         * Set the native PipeWire preference.
         */
        Pipewire.preferredDefaultAudioSink =
            node

        /*
         * Also ask WirePlumber to set the
         * current default immediately.
         *
         * This is an action, not a polling mechanism.
         */
        Quickshell.execDetached({
            command: [
                "wpctl",
                "set-default",
                String(node.id)
            ]
        })

        /*
         * Promote the selected device to
         * N0ctOS's own priority list.
         */
        root._promotePriority(
            "audio.outputPriority",
            node
        )

        return true
    }

    function setInput(
        value
    ) {
        const node =
            root.resolveNode(
                value
            )

        if (
            !node ||
            node.isSink ||
            node.isStream
        ) {
            return false
        }

        Pipewire.preferredDefaultAudioSource =
            node

        Quickshell.execDetached({
            command: [
                "wpctl",
                "set-default",
                String(node.id)
            ]
        })

        root._promotePriority(
            "audio.inputPriority",
            node
        )

        return true
    }

    function setOutputPriority(
        values
    ) {
        const normalized =
            root.normalizePriority(
                values
            )

        return Config.set(
            "audio.outputPriority",
            normalized
        )
    }

    function setInputPriority(
        values
    ) {
        const normalized =
            root.normalizePriority(
                values
            )

        return Config.set(
            "audio.inputPriority",
            normalized
        )
    }

    function _promotePriority(
        path,
        node
    ) {
        if (!node)
            return false

        const current =
            path ===
            "audio.outputPriority"
                ? root.outputPriority
                : root.inputPriority

        const identity =
            String(node.name)

        const updated = [
            identity
        ]

        for (
            let i = 0;
            i < current.length;
            ++i
        ) {
            if (
                current[i] !==
                    identity
            ) {
                updated.push(
                    current[i]
                )
            }
        }

        return Config.set(
            path,
            updated
        )
    }

    // ============================================================
    // VOLUME
    // ============================================================

    function _nodeAudio(
        node
    ) {
        if (
            !node ||
            node.audio === null
        ) {
            return null
        }

        return node.audio
    }

    function _nodeVolume(
        node
    ) {
        const audio =
            root._nodeAudio(
                node
            )

        if (!audio)
            return 0

        return Math.max(
            0,
            Number(audio.volume) * 100
        )
    }

    function _nodeMuted(
        node
    ) {
        const audio =
            root._nodeAudio(
                node
            )

        if (!audio)
            return false

        return !!audio.muted
    }

    function setVolume(
        node,
        percent
    ) {
        const target =
            root.resolveNode(
                node
            )

        if (!target)
            return false

        const audio =
            root._nodeAudio(
                target
            )

        if (!audio)
            return false

        let value =
            Number(percent)

        if (!isFinite(value))
            return false

        /*
         * PipeWire permits amplification beyond
         * 100%, so don't artificially force the
         * service to 100%.
         */
        value =
            Math.max(
                0,
                Math.min(
                    200,
                    value
                )
            )

        audio.volume =
            value / 100

        return true
    }

    function increase(
        node,
        amount
    ) {
        const target =
            root.resolveNode(
                node
            )

        if (!target)
            return false

        let delta =
            Number(amount)

        if (
            !isFinite(delta) ||
            delta <= 0
        ) {
            delta =
                root.step
        }

        return root.setVolume(
            target,
            root._nodeVolume(target) +
                delta
        )
    }

    function decrease(
        node,
        amount
    ) {
        const target =
            root.resolveNode(
                node
            )

        if (!target)
            return false

        let delta =
            Number(amount)

        if (
            !isFinite(delta) ||
            delta <= 0
        ) {
            delta =
                root.step
        }

        return root.setVolume(
            target,
            root._nodeVolume(target) -
                delta
        )
    }

    function setOutputVolume(
        percent
    ) {
        return root.setVolume(
            root.defaultOutput,
            percent
        )
    }

    function setInputVolume(
        percent
    ) {
        return root.setVolume(
            root.defaultInput,
            percent
        )
    }

    // ============================================================
    // MUTE
    // ============================================================

    function setMute(
        node,
        muted
    ) {
        const target =
            root.resolveNode(
                node
            )

        if (!target)
            return false

        const audio =
            root._nodeAudio(
                target
            )

        if (!audio)
            return false

        audio.muted =
            !!muted

        return true
    }

    function toggleMute(
        node
    ) {
        const target =
            root.resolveNode(
                node
            )

        if (!target)
            return false

        return root.setMute(
            target,
            !root._nodeMuted(
                target
            )
        )
    }

    function toggleOutputMute() {
        return root.toggleMute(
            root.defaultOutput
        )
    }

    function toggleInputMute() {
        return root.toggleMute(
            root.defaultInput
        )
    }

    // ============================================================
    // PROFILE / ROUTE
    // ============================================================

    /*
     * Quickshell exposes the live node model, but
     * profile/route mutation is currently handled
     * cleanly through wpctl.
     */
    function setProfile(
        node,
        index
    ) {
        const target =
            root.resolveNode(
                node
            )

        if (!target)
            return false

        const value =
            Number(index)

        if (!Number.isInteger(value))
            return false

        Quickshell.execDetached({
            command: [
                "wpctl",
                "set-profile",
                String(target.id),
                String(value)
            ]
        })

        return true
    }

    function setRoute(
        node,
        index
    ) {
        const target =
            root.resolveNode(
                node
            )

        if (!target)
            return false

        const value =
            Number(index)

        if (!Number.isInteger(value))
            return false

        Quickshell.execDetached({
            command: [
                "wpctl",
                "set-route",
                String(target.id),
                String(value)
            ]
        })

        return true
    }

    // ============================================================
    // UI HELPERS
    // ============================================================

    function displayName(
        node
    ) {
        if (!node)
            return ""

        if (
            node.nickname &&
            String(node.nickname).length > 0
        ) {
            return String(
                node.nickname
            )
        }

        if (
            node.description &&
            String(node.description).length > 0
        ) {
            return String(
                node.description
            )
        }

        if (
            node.properties
        ) {
            const applicationName =
                String(
                    node.properties[
                        "application.name"
                    ] || ""
                )

            if (applicationName)
                return applicationName

            const mediaName =
                String(
                    node.properties[
                        "media.name"
                    ] || ""
                )

            if (mediaName)
                return mediaName
        }

        return String(
            node.name || ""
        )
    }

    function applicationName(
        node
    ) {
        if (
            !node ||
            !node.properties
        ) {
            return ""
        }

        return String(
            node.properties[
                "application.name"
            ] || ""
        )
    }

    function mediaName(
        node
    ) {
        if (
            !node ||
            !node.properties
        ) {
            return ""
        }

        return String(
            node.properties[
                "media.name"
            ] || ""
        )
    }

    function mediaTitle(
        node
    ) {
        if (
            !node ||
            !node.properties
        ) {
            return ""
        }

        return String(
            node.properties[
                "media.title"
            ] || ""
        )
    }

    function mediaArtist(
        node
    ) {
        if (
            !node ||
            !node.properties
        ) {
            return ""
        }

        return String(
            node.properties[
                "media.artist"
            ] || ""
        )
    }

    function applicationIconName(
        node
    ) {
        if (
            !node ||
            !node.properties
        ) {
            return ""
        }

        return String(
            node.properties[
                "application.icon-name"
            ] || ""
        )
    }

    function icon(
        node
    ) {
        if (!node)
            return "󰋋"

        if (
            node.isStream
        ) {
            return root._nodeMuted(node)
                ? "󰖁"
                : "󰕾"
        }

        if (
            node.isSink
        ) {
            return root._nodeMuted(node)
                ? "󰖁"
                : "󰕾"
        }

        return root._nodeMuted(node)
            ? "󰍭"
            : "󰍬"
    }

    function isOutput(
        node
    ) {
        return (
            !!node &&
            node.audio !== null &&
            !node.isStream &&
            node.isSink
        )
    }

    function isInput(
        node
    ) {
        return (
            !!node &&
            node.audio !== null &&
            !node.isStream &&
            !node.isSink
        )
    }

    function isStream(
        node
    ) {
        return (
            !!node &&
            node.audio !== null &&
            node.isStream
        )
    }

    function isDefaultOutput(
        node
    ) {
        return (
            !!node &&
            node === root.defaultOutput
        )
    }

    function isDefaultInput(
        node
    ) {
        return (
            !!node &&
            node === root.defaultInput
        )
    }

    // ============================================================
    // NORMALIZATION
    // ============================================================

    function normalizeStep(
        value
    ) {
        let result =
            Number(value)

        if (!isFinite(result))
            result = 5

        return Math.max(
            1,
            Math.min(
                100,
                result
            )
        )
    }

    function normalizePriority(
        value
    ) {
        const result = []

        if (!Array.isArray(value))
            return result

        for (
            let i = 0;
            i < value.length;
            ++i
        ) {
            if (
                value[i] === null ||
                value[i] === undefined
            ) {
                continue
            }

            const item =
                String(value[i])

            if (
                !item ||
                result.indexOf(item) !== -1
            ) {
                continue
            }

            result.push(item)
        }

        return result
    }

    // ============================================================
    // SERIALIZATION
    // ============================================================

    function nodeInfo(
        node
    ) {
        if (!node)
            return {}

        return {
            id:
                Number(node.id),

            name:
                String(node.name || ""),

            displayName:
                root.displayName(node),

            description:
                String(
                    node.description || ""
                ),

            nickname:
                String(
                    node.nickname || ""
                ),

            type:
                String(
                    node.type || ""
                ),

            isStream:
                !!node.isStream,

            isSink:
                !!node.isSink,

            isOutput:
                root.isOutput(node),

            isInput:
                root.isInput(node),

            isDefaultOutput:
                root.isDefaultOutput(
                    node
                ),

            isDefaultInput:
                root.isDefaultInput(
                    node
                ),

            isMuted:
                root._nodeMuted(
                    node
                ),

            percent:
                Math.round(
                    root._nodeVolume(
                        node
                    )
                ),

            applicationName:
                root.applicationName(
                    node
                ),

            mediaName:
                root.mediaName(
                    node
                ),

            mediaTitle:
                root.mediaTitle(
                    node
                ),

            mediaArtist:
                root.mediaArtist(
                    node
                ),

            applicationIconName:
                root.applicationIconName(
                    node
                ),

            icon:
                root.icon(node)
        }
    }

    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target: "n0ctos-audio"

        // --------------------------------------------------------
        // Global state
        // --------------------------------------------------------

        function ready(): bool {
            return root.isReady
        }

        function get(): string {
            return JSON.stringify({
                isReady:
                    root.isReady,

                hasOutput:
                    root.hasOutput,

                output:
                    root.outputName,

                percent:
                    root.percentRounded,

                isMuted:
                    root.isMuted,

                hasInput:
                    root.hasInput,

                input:
                    root.inputName,

                inputPercent:
                    root.inputPercent,

                isInputMuted:
                    root.isInputMuted
            })
        }

        // --------------------------------------------------------
        // Outputs
        // --------------------------------------------------------

        function outputs(): string {
            return JSON.stringify(
                root.outputList.map(
                    function(node) {
                        return root.nodeInfo(
                            node
                        )
                    }
                )
            )
        }

        function setOutput(
            name: string
        ): bool {
            return root.setOutput(
                name
            )
        }

        function setOutputVolume(
            percent: real
        ): bool {
            return root.setOutputVolume(
                percent
            )
        }

        function increase(
            percent: real
        ): bool {
            return root.increase(
                root.defaultOutput,
                percent
            )
        }

        function decrease(
            percent: real
        ): bool {
            return root.decrease(
                root.defaultOutput,
                percent
            )
        }

        function mute(
            value: bool
        ): bool {
            return root.setMute(
                root.defaultOutput,
                value
            )
        }

        function toggleMute(): bool {
            return root.toggleOutputMute()
        }

        // --------------------------------------------------------
        // Inputs
        // --------------------------------------------------------

        function inputs(): string {
            return JSON.stringify(
                root.inputList.map(
                    function(node) {
                        return root.nodeInfo(
                            node
                        )
                    }
                )
            )
        }

        function setInput(
            name: string
        ): bool {
            return root.setInput(
                name
            )
        }

        function setInputVolume(
            percent: real
        ): bool {
            return root.setInputVolume(
                percent
            )
        }

        function muteInput(
            value: bool
        ): bool {
            return root.setMute(
                root.defaultInput,
                value
            )
        }

        function toggleInputMute(): bool {
            return root.toggleInputMute()
        }

        // --------------------------------------------------------
        // Streams / applications
        // --------------------------------------------------------

        function streams(): string {
            return JSON.stringify(
                root.streamList.map(
                    function(node) {
                        return root.nodeInfo(
                            node
                        )
                    }
                )
            )
        }

        function setNodeVolume(
            id: int,
            percent: real
        ): bool {
            return root.setVolume(
                root.nodeForId(id),
                percent
            )
        }

        function setNodeMute(
            id: int,
            value: bool
        ): bool {
            return root.setMute(
                root.nodeForId(id),
                value
            )
        }

        // --------------------------------------------------------
        // Profiles / routes
        // --------------------------------------------------------

        function setProfile(
            id: int,
            index: int
        ): bool {
            return root.setProfile(
                root.nodeForId(id),
                index
            )
        }

        function setRoute(
            id: int,
            index: int
        ): bool {
            return root.setRoute(
                root.nodeForId(id),
                index
            )
        }

        // --------------------------------------------------------
        // Priority
        // --------------------------------------------------------

        function getOutputPriority(): string {
            return JSON.stringify(
                root.outputPriority
            )
        }

        function getInputPriority(): string {
            return JSON.stringify(
                root.inputPriority
            )
        }

        function setOutputPriority(
            json: string
        ): bool {
            try {
                return root.setOutputPriority(
                    JSON.parse(json)
                )
            } catch (error) {
                return false
            }
        }

        function setInputPriority(
            json: string
        ): bool {
            try {
                return root.setInputPriority(
                    JSON.parse(json)
                )
            } catch (error) {
                return false
            }
        }
    }
}