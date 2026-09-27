pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io


Singleton {
    id: root


    // ============================================================
    // PUBLIC STATE
    // ============================================================

    /*
     * Config state.
     *
     * Animations exclusively uses homeConfig.
     */
    readonly property bool ready:
        Config.ready

    readonly property bool writing:
        Config.writing

    readonly property bool dirty:
        Config.dirty

    readonly property int revision:
        Config.revision


    /*
     * Currently selected global animation profile.
     *
     * Stored at:
     *
     *     animations.profile
     */
    readonly property string profile:
        root._profileName


    /*
     * Effective profile name.
     *
     * If animations.profile is invalid/missing, "full" is used
     * when available, otherwise the first valid profile.
     */
    readonly property string effectiveProfileName:
        root._effectiveProfileName


    /*
     * All configured profiles.
     */
    readonly property var profiles:
        root._clone(
            root._validProfiles
        )


    /*
     * All configured global overrides.
     */
    readonly property var overrides:
        root._clone(
            root._validOverrides
        )


    /*
     * The currently selected profile before overrides.
     */
    readonly property var activeProfile:
        root._clone(
            root._activeProfile
        )


    /*
     * Active profile + global overrides.
     *
     * Overrides recursively replace/extend profile values.
     */
    readonly property var resolved:
        root._clone(
            root._resolved
        )


    // ============================================================
    // INTERNAL CONFIG STATE
    // ============================================================

    /*
     * Directly bind to Config's reactive homeConfig document.
     */
    readonly property var _configData:
        Config.data


    /*
     * animations section.
     */
    readonly property var _animations:
        (
            root._configData &&
            typeof root._configData === "object" &&
            root._configData.animations &&
            typeof root._configData.animations === "object" &&
            !Array.isArray(root._configData.animations)
        )
            ? root._configData.animations
            : ({ })


    /*
     * Raw profile object from configuration.
     */
    readonly property var _rawProfiles:
        (
            root._animations.profiles &&
            typeof root._animations.profiles === "object" &&
            !Array.isArray(root._animations.profiles)
        )
            ? root._animations.profiles
            : ({ })


    /*
     * Raw overrides object from configuration.
     */
    readonly property var _rawOverrides:
        (
            root._animations.overrides &&
            typeof root._animations.overrides === "object" &&
            !Array.isArray(root._animations.overrides)
        )
            ? root._animations.overrides
            : ({ })


    /*
     * Only object-valued profiles are accepted.
     */
    readonly property var _validProfiles:
        root._sanitizeProfiles(
            root._rawProfiles
        )


    /*
     * Overrides may contain arbitrary JSON values.
     */
    readonly property var _validOverrides:
        root._sanitizeObject(
            root._rawOverrides
        )


    /*
     * Stored profile selection.
     */
    readonly property string _profileName:
        (
            typeof root._animations.profile ===
                "string" &&
            root._animations.profile.trim().length > 0
        )
            ? root._animations.profile.trim()
            : "full"


    /*
     * Profile actually used by the service.
     */
    readonly property string _effectiveProfileName:
        root._getEffectiveProfileName(
            root._profileName,
            root._validProfiles
        )


    /*
     * Current base profile before overrides.
     */
    readonly property var _activeProfile:
        (
            root._effectiveProfileName.length > 0 &&
            root._validProfiles[
                root._effectiveProfileName
            ]
        )
            ? root._validProfiles[
                root._effectiveProfileName
            ]
            : ({ })


    /*
     * Final animation configuration.
     */
    readonly property var _resolved:
        root._deepMerge(
            root._activeProfile,
            root._validOverrides
        )


    // ============================================================
    // BUILT-IN DEFAULT PROFILES
    // ============================================================

    /*
     * These only initialize missing configuration.
     *
     * Existing profiles are preserved.
     */
    readonly property var defaultProfiles: ({
        none: {
            cxtmenu: {
                enabled: false
            },

            hyprland: {
                enabled: false
            },

            launcher: {
                enabled: false
            }
        },

        minimal: {
            cxtmenu: {
                enabled: false
            },

            hyprland: {
                enabled: true
            },

            launcher: {
                enabled: false
            }
        },

        full: {
            cxtmenu: {
                enabled: true
            },

            hyprland: {
                enabled: true
            },

            launcher: {
                enabled: true
            }
        }
    })


    // ============================================================
    // CONFIG INITIALIZATION
    // ============================================================

    Connections {
        target:
            Config


        function onReadyChanged() {
            if (
                Config.ready
            ) {
                root.ensureDefaults()
            }
        }
    }


    Component.onCompleted: {
        if (
            Config.ready
        ) {
            root.ensureDefaults()
        }
    }


    /*
     * Ensure the basic animation configuration exists.
     *
     * Missing built-in profiles are added.
     * Existing profiles are never overwritten.
     */
    function ensureDefaults() {
        if (!Config.ready)
            return false


        let changed =
            false


        const current =
            Config.get(
                "animations",
                {},
                "homeConfig"
            )


        if (
            !root._isObject(
                current
            )
        ) {
            return false
        }


        const section =
            root._clone(
                current
            )


        /*
         * --------------------------------------------------------
         * PROFILES
         * --------------------------------------------------------
         */

        if (
            !root._isObject(
                section.profiles
            )
        ) {
            section.profiles =
                root._clone(
                    root.defaultProfiles
                )

            changed = true
        } else {
            for (
                const name in root.defaultProfiles
            ) {
                if (
                    !Object.prototype.hasOwnProperty.call(
                        section.profiles,
                        name
                    )
                ) {
                    section.profiles[name] =
                        root._clone(
                            root.defaultProfiles[name]
                        )

                    changed = true
                }
            }
        }


        /*
         * --------------------------------------------------------
         * ACTIVE PROFILE
         * --------------------------------------------------------
         */

        let selected =
            (
                typeof section.profile ===
                    "string"
            )
                ? section.profile.trim()
                : ""


        if (
            selected.length === 0 ||
            !root._isObject(
                section.profiles[
                    selected
                ]
            )
        ) {
            if (
                root._isObject(
                    section.profiles.full
                )
            ) {
                selected =
                    "full"
            } else {
                const valid =
                    root._sanitizeProfiles(
                        section.profiles
                    )

                const names =
                    Object.keys(
                        valid
                    )

                selected =
                    names.length > 0
                        ? names[0]
                        : ""
            }


            if (
                selected.length > 0
            ) {
                section.profile =
                    selected
            } else {
                delete section.profile
            }


            changed = true
        }


        /*
         * --------------------------------------------------------
         * OVERRIDES
         * --------------------------------------------------------
         */

        if (
            section.overrides !== undefined &&
            !root._isObject(
                section.overrides
            )
        ) {
            section.overrides =
                {}

            changed = true
        }


        if (!changed)
            return true


        return Config.set(
            "animations",
            section,
            "homeConfig"
        )
    }


    // ============================================================
    // GENERAL HELPERS
    // ============================================================

    function _isObject(
        value
    ) {
        return (
            value !== null &&
            typeof value === "object" &&
            !Array.isArray(value)
        )
    }


    function _clone(
        value
    ) {
        if (
            value === undefined
        ) {
            return undefined
        }


        if (
            value === null ||
            typeof value !== "object"
        ) {
            return value
        }


        try {
            return JSON.parse(
                JSON.stringify(
                    value
                )
            )
        } catch (error) {
            console.warn(
                "[Animations] Failed to clone value:",
                error
            )

            return ({ })
        }
    }


    /*
     * Clone an object while guaranteeing an object result.
     */
    function _sanitizeObject(
        value
    ) {
        if (
            !root._isObject(
                value
            )
        ) {
            return ({ })
        }


        return root._clone(
            value
        )
    }


    /*
     * Profiles themselves must be objects.
     */
    function _sanitizeProfiles(
        value
    ) {
        const result =
            { }


        if (
            !root._isObject(
                value
            )
        ) {
            return result
        }


        const names =
            Object.keys(
                value
            )


        for (
            let i = 0;
            i < names.length;
            ++i
        ) {
            const name =
                names[i]


            if (
                root._isObject(
                    value[name]
                )
            ) {
                result[name] =
                    root._clone(
                        value[name]
                    )
            }
        }


        return result
    }


    /*
     * Split a dot-separated configuration path.
     *
     * Example:
     *
     *     cxtmenu.fadeDuration
     *
     * becomes:
     *
     *     ["cxtmenu", "fadeDuration"]
     */
    function _splitPath(
        path
    ) {
        if (
            path === undefined ||
            path === null
        ) {
            return []
        }


        const text =
            String(
                path
            ).trim()


        if (
            text.length === 0
        ) {
            return []
        }


        const raw =
            text.split(".")


        const parts =
            []


        for (
            let i = 0;
            i < raw.length;
            ++i
        ) {
            const part =
                raw[i].trim()


            if (
                part.length === 0
            ) {
                return []
            }


            parts.push(
                part
            )
        }


        return parts
    }


    /*
     * Return:
     *
     *     {
     *         found: true/false,
     *         value: ...
     *     }
     */
    function _getAt(
        object,
        path
    ) {
        const parts =
            root._splitPath(
                path
            )


        if (
            parts.length === 0 ||
            object === undefined ||
            object === null
        ) {
            return {
                found: false,
                value: undefined
            }
        }


        let current =
            object


        for (
            let i = 0;
            i < parts.length;
            ++i
        ) {
            if (
                current === null ||
                current === undefined ||
                typeof current !== "object" ||
                !Object.prototype.hasOwnProperty.call(
                    current,
                    parts[i]
                )
            ) {
                return {
                    found: false,
                    value: undefined
                }
            }


            current =
                current[
                    parts[i]
                ]
        }


        return {
            found: true,
            value: current
        }
    }


    /*
     * Set a nested value into a normal JavaScript object.
     *
     * Missing intermediate objects are created.
     */
    function _setAt(
        object,
        path,
        value
    ) {
        const parts =
            root._splitPath(
                path
            )


        if (
            parts.length === 0 ||
            !root._isObject(
                object
            )
        ) {
            return false
        }


        let current =
            object


        for (
            let i = 0;
            i < parts.length - 1;
            ++i
        ) {
            const key =
                parts[i]


            if (
                !root._isObject(
                    current[key]
                )
            ) {
                current[key] =
                    {}
            }


            current =
                current[key]
        }


        current[
            parts[
                parts.length - 1
            ]
        ] =
            root._clone(
                value
            )


        return true
    }


    /*
     * Remove a nested value.
     *
     * Empty parent objects are cleaned up.
     */
    function _removeAt(
        object,
        path
    ) {
        const parts =
            root._splitPath(
                path
            )


        if (
            parts.length === 0 ||
            !root._isObject(
                object
            )
        ) {
            return false
        }


        return root._removeAtParts(
            object,
            parts,
            0
        )
    }


    function _removeAtParts(
        object,
        parts,
        index
    ) {
        if (
            !root._isObject(
                object
            ) ||
            index >= parts.length
        ) {
            return false
        }


        const key =
            parts[index]


        if (
            !Object.prototype.hasOwnProperty.call(
                object,
                key
            )
        ) {
            return false
        }


        if (
            index ===
                parts.length - 1
        ) {
            delete object[key]

            return true
        }


        const child =
            object[key]


        if (
            !root._isObject(
                child
            )
        ) {
            return false
        }


        const removed =
            root._removeAtParts(
                child,
                parts,
                index + 1
            )


        if (
            removed &&
            Object.keys(
                child
            ).length === 0
        ) {
            delete object[key]
        }


        return removed
    }


    /*
     * Recursive merge.
     *
     * Objects merge recursively.
     * Arrays and primitive values from "overlay" replace the base.
     */
    function _deepMerge(
        base,
        overlay
    ) {
        const result =
            root._isObject(
                base
            )
                ? root._clone(
                    base
                )
                : {}


        if (
            !root._isObject(
                overlay
            )
        ) {
            return root._clone(
                overlay
            )
        }


        const keys =
            Object.keys(
                overlay
            )


        for (
            let i = 0;
            i < keys.length;
            ++i
        ) {
            const key =
                keys[i]


            const overlayValue =
                overlay[key]


            if (
                root._isObject(
                    overlayValue
                ) &&
                root._isObject(
                    result[key]
                )
            ) {
                result[key] =
                    root._deepMerge(
                        result[key],
                        overlayValue
                    )
            } else {
                result[key] =
                    root._clone(
                        overlayValue
                    )
            }
        }


        return result
    }


    function _getEffectiveProfileName(
        requested,
        profiles
    ) {
        if (
            requested &&
            Object.prototype.hasOwnProperty.call(
                profiles,
                requested
            )
        ) {
            return requested
        }


        if (
            Object.prototype.hasOwnProperty.call(
                profiles,
                "full"
            )
        ) {
            return "full"
        }


        const names =
            Object.keys(
                profiles
            )


        if (
            names.length > 0
        ) {
            return names[0]
        }


        return ""
    }


    function _normalizeName(
        value
    ) {
        if (
            value === undefined ||
            value === null
        ) {
            return ""
        }


        return String(
            value
        ).trim()
    }


    // ============================================================
    // DATA STORE API
    // ============================================================

    /*
     * GET
     *
     * Read an effective animation value.
     *
     * Path examples:
     *
     *     Animations.get(
     *         "cxtmenu.enabled",
     *         true
     *     )
     *
     *     Animations.get(
     *         "cxtmenu.fadeDuration",
     *         200
     *     )
     *
     * Resolution:
     *
     *     override
     *         ↓
     *     active profile
     *         ↓
     *     fallback
     *
     * If a fallback is supplied and the property does not exist
     * anywhere in the effective configuration, the fallback is
     * ALSO written into the active profile.
     *
     * This means the first read can materialize defaults into
     * the profile automatically.
     *
     * scope:
     *
     *     "resolved"  → override + profile
     *     "profile"   → profile only
     *     "override"  → override only
     */
    function get(
        path,
        fallback,
        scope
    ) {
        const normalizedPath =
            String(
                path || ""
            ).trim()


        if (
            normalizedPath.length === 0
        ) {
            return fallback
        }


        const selectedScope =
            (
                scope === undefined ||
                scope === null ||
                String(scope).trim().length === 0
            )
                ? "resolved"
                : String(scope).trim()


        let result = {
            found: false,
            value: undefined
        }


        /*
         * --------------------------------------------------------
         * OVERRIDE ONLY
         * --------------------------------------------------------
         */
        if (
            selectedScope ===
                "override"
        ) {
            result =
                root._getAt(
                    root._validOverrides,
                    normalizedPath
                )
        }


        /*
         * --------------------------------------------------------
         * PROFILE ONLY
         * --------------------------------------------------------
         */
        else if (
            selectedScope ===
                "profile"
        ) {
            result =
                root._getAt(
                    root._activeProfile,
                    normalizedPath
                )
        }


        /*
         * --------------------------------------------------------
         * RESOLVED
         * --------------------------------------------------------
         */
        else {
            result =
                root._getAt(
                    root._resolved,
                    normalizedPath
                )
        }


        if (
            result.found
        ) {
            return root._clone(
                result.value
            )
        }


        /*
         * No value exists.
         *
         * If the caller supplied a fallback, persist it into the
         * active profile, exactly as requested.
         */
        if (
            fallback !== undefined &&
            selectedScope !== "override"
        ) {
            if (
                root.ready
            ) {
                root.set(
                    normalizedPath,
                    fallback,
                    "profile"
                )
            }


            return root._clone(
                fallback
            )
        }


        return fallback
    }


    /*
     * SET
     *
     * Create or update one nested value.
     *
     * scope:
     *
     *     "profile"
     *         write into the selected profile
     *
     *     "override"
     *         write into global overrides
     *
     * profileName:
     *
     *     Optional profile name when scope == "profile".
     *
     * Every set automatically goes through Config.set(), which
     * changes the reactive document and queues persistence.
     */
    function set(
        path,
        value,
        scope,
        profileName
    ) {
        const normalizedPath =
            String(
                path || ""
            ).trim()


        if (
            normalizedPath.length === 0
        ) {
            return false
        }


        const selectedScope =
            (
                scope === undefined ||
                scope === null ||
                String(scope).trim().length === 0
            )
                ? "profile"
                : String(scope).trim()


        /*
         * --------------------------------------------------------
         * OVERRIDE
         * --------------------------------------------------------
         */
        if (
            selectedScope ===
                "override"
        ) {
            const overrides =
                root._clone(
                    root._rawOverrides
                )


            if (
                !root._isObject(
                    overrides
                )
            ) {
                return false
            }


            if (
                !root._setAt(
                    overrides,
                    normalizedPath,
                    value
                )
            ) {
                return false
            }


            return Config.set(
                "animations.overrides",
                overrides,
                "homeConfig"
            )
        }


        /*
         * --------------------------------------------------------
         * PROFILE
         * --------------------------------------------------------
         */

        const targetProfile =
            root._normalizeName(
                profileName ||
                root.effectiveProfileName
            )


        if (
            targetProfile.length === 0
        ) {
            return false
        }


        const profiles =
            root._clone(
                root._rawProfiles
            )


        if (
            !root._isObject(
                profiles
            )
        ) {
            return false
        }


        /*
         * set() is an UPSERT.
         *
         * A missing profile is created as an empty object.
         */
        if (
            !root._isObject(
                profiles[
                    targetProfile
                ]
            )
        ) {
            profiles[
                targetProfile
            ] =
                {}
        }


        if (
            !root._setAt(
                profiles[
                    targetProfile
                ],
                normalizedPath,
                value
            )
        ) {
            return false
        }


        return Config.set(
            "animations.profiles",
            profiles,
            "homeConfig"
        )
    }


    /*
     * REMOVE
     *
     * Remove one nested profile/override value.
     *
     * scope defaults to "profile".
     */
    function remove(
        path,
        scope,
        profileName
    ) {
        const normalizedPath =
            String(
                path || ""
            ).trim()


        if (
            normalizedPath.length === 0
        ) {
            return false
        }


        const selectedScope =
            (
                scope === undefined ||
                scope === null ||
                String(scope).trim().length === 0
            )
                ? "profile"
                : String(scope).trim()


        /*
         * --------------------------------------------------------
         * OVERRIDE
         * --------------------------------------------------------
         */
        if (
            selectedScope ===
                "override"
        ) {
            const overrides =
                root._clone(
                    root._rawOverrides
                )


            if (
                !root._isObject(
                    overrides
                )
            ) {
                return false
            }


            if (
                !root._removeAt(
                    overrides,
                    normalizedPath
                )
            ) {
                return false
            }


            return Config.set(
                "animations.overrides",
                overrides,
                "homeConfig"
            )
        }


        /*
         * --------------------------------------------------------
         * PROFILE
         * --------------------------------------------------------
         */

        const targetProfile =
            root._normalizeName(
                profileName ||
                root.effectiveProfileName
            )


        if (
            targetProfile.length === 0
        ) {
            return false
        }


        const profiles =
            root._clone(
                root._rawProfiles
            )


        if (
            !root._isObject(
                profiles
            ) ||
            !root._isObject(
                profiles[
                    targetProfile
                ]
            )
        ) {
            return false
        }


        if (
            !root._removeAt(
                profiles[
                    targetProfile
                ],
                normalizedPath
            )
        ) {
            return false
        }


        return Config.set(
            "animations.profiles",
            profiles,
            "homeConfig"
        )
    }


    // ============================================================
    // PROFILE CRUD
    // ============================================================

    /*
     * GET PROFILE
     */
    function getProfile(
        name
    ) {
        const profileName =
            root._normalizeName(
                name
            )


        if (
            profileName.length === 0
        ) {
            return root._clone(
                root._activeProfile
            )
        }


        if (
            !Object.prototype.hasOwnProperty.call(
                root._validProfiles,
                profileName
            )
        ) {
            return ({ })
        }


        return root._clone(
            root._validProfiles[
                profileName
            ]
        )
    }


    /*
     * SET PROFILE
     *
     * Create OR update an entire profile.
     */
    function setProfile(
        name,
        values
    ) {
        const profileName =
            root._normalizeName(
                name
            )


        if (
            profileName.length === 0 ||
            !root._isObject(
                values
            )
        ) {
            return false
        }


        const profiles =
            root._clone(
                root._rawProfiles
            )


        if (
            !root._isObject(
                profiles
            )
        ) {
            return false
        }


        profiles[
            profileName
        ] =
            root._clone(
                values
            )


        return Config.set(
            "animations.profiles",
            profiles,
            "homeConfig"
        )
    }


    /*
     * REMOVE PROFILE
     *
     * The final remaining profile cannot be deleted.
     */
    function removeProfile(
        name
    ) {
        const profileName =
            root._normalizeName(
                name
            )


        if (
            profileName.length === 0 ||
            !root.hasProfile(
                profileName
            )
        ) {
            return false
        }


        const profileNames =
            Object.keys(
                root._validProfiles
            )


        if (
            profileNames.length <= 1
        ) {
            console.warn(
                "[Animations] Cannot remove the last profile."
            )

            return false
        }


        const profiles =
            root._clone(
                root._rawProfiles
            )


        if (
            !root._isObject(
                profiles
            )
        ) {
            return false
        }


        delete profiles[
            profileName
        ]


        if (
            !Config.set(
                "animations.profiles",
                profiles,
                "homeConfig"
            )
        ) {
            return false
        }


        /*
         * If the active profile was removed, select another one.
         */
        if (
            root.profile ===
                profileName
        ) {
            const remaining =
                root._sanitizeProfiles(
                    profiles
                )


            let next =
                ""


            if (
                Object.prototype.hasOwnProperty.call(
                    remaining,
                    "full"
                )
            ) {
                next =
                    "full"
            } else {
                const names =
                    Object.keys(
                        remaining
                    )

                if (
                    names.length > 0
                ) {
                    next =
                        names[0]
                }
            }


            if (
                next.length > 0
            ) {
                Config.set(
                    "animations.profile",
                    next,
                    "homeConfig"
                )
            }
        }


        return true
    }


    function hasProfile(
        name
    ) {
        const profileName =
            root._normalizeName(
                name
            )


        return (
            profileName.length > 0 &&
            Object.prototype.hasOwnProperty.call(
                root._validProfiles,
                profileName
            )
        )
    }


    // ============================================================
    // OVERRIDE CRUD
    // ============================================================

    /*
     * GET OVERRIDE
     *
     * Unlike get(), a missing override does NOT materialize a
     * fallback into the profile.
     */
    function getOverride(
        path,
        fallback
    ) {
        const normalizedPath =
            String(
                path || ""
            ).trim()


        if (
            normalizedPath.length === 0
        ) {
            return fallback
        }


        const result =
            root._getAt(
                root._validOverrides,
                normalizedPath
            )


        if (
            result.found
        ) {
            return root._clone(
                result.value
            )
        }


        return fallback
    }


    /*
     * SET OVERRIDE
     *
     * Create/update an override.
     */
    function setOverride(
        path,
        value
    ) {
        return root.set(
            path,
            value,
            "override"
        )
    }


    /*
     * REMOVE OVERRIDE
     */
    function removeOverride(
        path
    ) {
        return root.remove(
            path,
            "override"
        )
    }


    // ============================================================
    // PROFILE / OVERRIDE MERGING
    // ============================================================

    /*
     * Resolve a profile with CURRENT global overrides.
     *
     * Passing no name resolves the current effective profile.
     */
    function resolve(
        profileName
    ) {
        const requested =
            root._normalizeName(
                profileName
            )


        const name =
            requested.length > 0
                ? requested
                : root.effectiveProfileName


        if (
            !root.hasProfile(
                name
            )
        ) {
            return ({ })
        }


        return root._deepMerge(
            root._validProfiles[
                name
            ],
            root._validOverrides
        )
    }


    /*
     * Make/update a profile from:
     *
     *     source profile + current overrides
     *
     * This is deliberately named "setProfileFrom" rather than
     * "createProfileFrom": setProfile() remains the single
     * profile write/upsert primitive.
     */
    function setProfileFrom(
        sourceProfile,
        targetProfile
    ) {
        const source =
            root._normalizeName(
                sourceProfile
            )

        const target =
            root._normalizeName(
                targetProfile
            )


        if (
            source.length === 0 ||
            target.length === 0
        ) {
            return false
        }


        if (
            !root.hasProfile(
                source
            )
        ) {
            return false
        }


        const merged =
            root._deepMerge(
                root._validProfiles[
                    source
                ],
                root._validOverrides
            )


        return root.setProfile(
            target,
            merged
        )
    }


    /*
     * Select the global profile.
     */
    function selectProfile(
        name
    ) {
        const profileName =
            root._normalizeName(
                name
            )


        if (
            profileName.length === 0 ||
            !root.hasProfile(
                profileName
            )
        ) {
            return false
        }


        return Config.set(
            "animations.profile",
            profileName,
            "homeConfig"
        )
    }


    // ============================================================
    // CONVENIENCE ACCESSORS
    // ============================================================

    /*
     * Common shorthand for:
     *
     *     Animations.get(
     *         "component.enabled",
     *         fallback
     *     )
     */
    function isEnabled(
        component,
        fallback
    ) {
        const name =
            root._normalizeName(
                component
            )


        if (
            name.length === 0
        ) {
            return (
                fallback !== undefined
                    ? Boolean(fallback)
                    : false
            )
        }


        return Boolean(
            root.get(
                name + ".enabled",
                fallback !== undefined
                    ? fallback
                    : false
            )
        )
    }


    // ============================================================
    // STATUS
    // ============================================================

    function getStatus() {
        return {
            ready:
                root.ready,

            writing:
                root.writing,

            dirty:
                root.dirty,

            revision:
                root.revision,

            profile:
                root.profile,

            effectiveProfile:
                root.effectiveProfileName,

            profileCount:
                Object.keys(
                    root._validProfiles
                ).length,

            overrideCount:
                Object.keys(
                    root._validOverrides
                ).length
        }
    }


    // ============================================================
    // IPC
    // ============================================================

    IpcHandler {
        target:
            "n0ctos-animations"


        // --------------------------------------------------------
        // STATUS
        // --------------------------------------------------------

        function getStatus(): string {
            return JSON.stringify(
                root.getStatus()
            )
        }


        // --------------------------------------------------------
        // EFFECTIVE DATA
        // --------------------------------------------------------

        /*
         * get <path> [fallback-json] [scope]
         *
         * scope:
         *     resolved
         *     profile
         *     override
         */
        function get(
            path: string,
            fallbackJson: string,
            scope: string
        ): string {
            let fallback


            if (
                fallbackJson !== undefined &&
                fallbackJson !== null &&
                String(
                    fallbackJson
                ).length > 0
            ) {
                try {
                    fallback =
                        JSON.parse(
                            fallbackJson
                        )
                } catch (error) {
                    return ""
                }
            }


            const value =
                root.get(
                    path,
                    fallback,
                    scope
                )


            if (
                value === undefined
            ) {
                return ""
            }


            return JSON.stringify(
                value
            )
        }


        /*
         * set <path> <json> [scope] [profile]
         *
         * scope:
         *     profile   (default)
         *     override
         */
        function set(
            path: string,
            json: string,
            scope: string,
            profileName: string
        ): bool {
            let value


            try {
                value =
                    JSON.parse(
                        json
                    )
            } catch (error) {
                return false
            }


            return root.set(
                path,
                value,
                scope,
                profileName
            )
        }


        /*
         * remove <path> [scope] [profile]
         */
        function remove(
            path: string,
            scope: string,
            profileName: string
        ): bool {
            return root.remove(
                path,
                scope,
                profileName
            )
        }


        // --------------------------------------------------------
        // PROFILES
        // --------------------------------------------------------

        function getProfile(
            name: string
        ): string {
            if (
                !root.hasProfile(
                    name
                )
            ) {
                return ""
            }


            return JSON.stringify(
                root.getProfile(
                    name
                )
            )
        }


        /*
         * setProfile is CREATE + UPDATE.
         */
        function setProfile(
            name: string,
            json: string
        ): bool {
            let values


            try {
                values =
                    JSON.parse(
                        json
                    )
            } catch (error) {
                return false
            }


            return root.setProfile(
                name,
                values
            )
        }


        /*
         * removeProfile is DELETE.
         */
        function removeProfile(
            name: string
        ): bool {
            return root.removeProfile(
                name
            )
        }


        // --------------------------------------------------------
        // OVERRIDES
        // --------------------------------------------------------

        function getOverride(
            path: string
        ): string {
            const value =
                root.getOverride(
                    path
                )


            if (
                value === undefined
            ) {
                return ""
            }


            return JSON.stringify(
                value
            )
        }


        /*
         * setOverride is CREATE + UPDATE.
         */
        function setOverride(
            path: string,
            json: string
        ): bool {
            let value


            try {
                value =
                    JSON.parse(
                        json
                    )
            } catch (error) {
                return false
            }


            return root.setOverride(
                path,
                value
            )
        }


        /*
         * removeOverride is DELETE.
         */
        function removeOverride(
            path: string
        ): bool {
            return root.removeOverride(
                path
            )
        }


        // --------------------------------------------------------
        // PROFILE CONTROL / RESOLUTION
        // --------------------------------------------------------

        function selectProfile(
            name: string
        ): bool {
            return root.selectProfile(
                name
            )
        }


        function resolve(
            name: string
        ): string {
            return JSON.stringify(
                root.resolve(
                    name
                )
            )
        }


        /*
         * setProfileFrom
         *
         * source + current overrides -> target profile
         */
        function setProfileFrom(
            sourceProfile: string,
            targetProfile: string
        ): bool {
            return root.setProfileFrom(
                sourceProfile,
                targetProfile
            )
        }


        // --------------------------------------------------------
        // COMMON CONVENIENCE
        // --------------------------------------------------------

        function isEnabled(
            component: string
        ): bool {
            return root.isEnabled(
                component
            )
        }
    }
}
