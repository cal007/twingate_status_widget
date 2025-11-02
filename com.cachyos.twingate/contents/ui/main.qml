import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property bool serviceRunning: false
    property bool serviceEnabled: false
    property string serviceState: ""
    property bool twingateReportsOnline: false
    property bool twingateReportsAuth: false
    property bool realityCheckSuccess: false
    property bool pingSuccess: false
    property var resources: []
    property string resourceParseError: ""
    property string rawResourceOutput: ""
    property string rawStatusOutput: ""
    property string debugLog: ""
    readonly property string authResource: Plasmoid.configuration.authResource || ""
    readonly property string pingIp: Plasmoid.configuration.pingIp || ""
    property var remoteNetworks: []
    property bool isAuthenticated: false
    property bool hasTriedAuth: false
    property var pingResults: ({})
    property bool waitingForServiceStart: false
    property real lastRestartTime: 0

    Plasmoid.icon: realityCheckSuccess ? "security-high" : (serviceRunning ? "security-medium" : "security-low")

    function addDebugLog(msg) {
        let timestamp = Qt.formatTime(new Date(), "hh:mm:ss")
        let entry = "[" + timestamp + "] " + msg
        let lines = debugLog.split("\n")
        lines.unshift(entry)
        if (lines.length > 20) lines = lines.slice(0, 20)
            debugLog = lines.join("\n")
    }

    function parseRemoteNetworks() {
        let rawList = Plasmoid.configuration.remoteNetworks || []
        let parsed = []

        for (let i = 0; i < rawList.length; i++) {
            let ip = rawList[i].trim()
            if (ip !== "") {
                parsed.push(ip)
            }
        }

        remoteNetworks = parsed
        addDebugLog("📡 Remote Networks: " + JSON.stringify(parsed))
    }

    function doPing() {
        if (remoteNetworks.length === 0) {
            addDebugLog("⚠️ No remote networks configured!")
            pingSuccess = false
            return
        }

        addDebugLog("🔍 Pinging " + remoteNetworks.length + " networks...")
        pingResults = {}

        for (let i = 0; i < remoteNetworks.length; i++) {
            let ip = remoteNetworks[i]
            addDebugLog("  → Ping " + ip)
            execCommand("ping -c 1 -W 2 " + ip)
        }
    }

    function execCommand(cmd) {
        addDebugLog("=== EXECUTING: " + cmd)
        executable.connectSource(cmd)
    }

    function toggleService() {
        addDebugLog("Toggle service requested")

        if (serviceState === "activating") {
            addDebugLog("⚠️ Service is activating - ignoring toggle request")
            return
        }

        let now = Date.now()
        if (lastRestartTime > 0 && (now - lastRestartTime) < 60000) {
            let remaining = Math.ceil((60000 - (now - lastRestartTime)) / 1000)
            addDebugLog("⚠️ Restart blocked - wait " + remaining + "s more")
            return
        }

        if (serviceRunning) {
            execCommand("systemctl stop twingate")
        } else {
            waitingForServiceStart = true
            lastRestartTime = now
            execCommand("systemctl start twingate")
        }

        hasTriedAuth = false
    }

    function doAuth() {
        if (authResource === "") {
            addDebugLog("ERROR: No auth resource configured!")
            return
        }

        if (!serviceRunning) {
            addDebugLog("⚠️ Service not running - cannot authenticate")
            return
        }

        if (serviceState === "activating") {
            addDebugLog("⚠️ Service still activating - waiting...")
            return
        }

        // ✅ FIX: Verwende Twingate CLI Auth-Kommando!
        addDebugLog("🔐 Starting authentication via: twingate auth " + authResource)
        execCommand("twingate auth " + authResource)
        hasTriedAuth = true
    }

    function checkSystemctl() {
        execCommand("systemctl is-active twingate")
        execCommand("systemctl is-enabled twingate")
        execCommand("systemctl show -p ActiveState -p SubState twingate")
    }

    function checkStatus() {
        execCommand("twingate status")
    }

    function checkResources() {
        execCommand("twingate resources")
    }

    function updateRealityCheck() {
        let oldState = realityCheckSuccess

        if (!serviceRunning || serviceState === "activating") {
            realityCheckSuccess = false
            isAuthenticated = false
            addDebugLog("❌ REALITY: Service not ready (state: " + serviceState + ")")

            if (waitingForServiceStart && serviceState === "activating") {
                // Weiter warten...
            } else if (waitingForServiceStart) {
                waitingForServiceStart = false
            }
            return
        }

        if (serviceRunning && serviceState === "active" && waitingForServiceStart) {
            waitingForServiceStart = false
            addDebugLog("✅ Service is now ACTIVE")
        }

        let statusLines = rawStatusOutput.trim().toLowerCase()

        if (statusLines.includes("not running") || statusLines.includes("stopped") || statusLines.includes("offline")) {
            realityCheckSuccess = false
            isAuthenticated = false
            addDebugLog("❌ REALITY: Twingate reports OFFLINE")
        } else if (statusLines.includes("online") || statusLines.includes("running") || statusLines.includes("connected")) {
            if (pingSuccess) {
                realityCheckSuccess = true
                isAuthenticated = true
                addDebugLog("✅ REALITY: Twingate ONLINE + Ping OK")
            } else {
                realityCheckSuccess = false
                isAuthenticated = false
                addDebugLog("⚠️ REALITY: Twingate says online but PING FAILED")
            }
        } else if (statusLines.includes("unknown") || statusLines === "") {
            if (pingSuccess) {
                realityCheckSuccess = true
                isAuthenticated = true
                addDebugLog("✅ REALITY: Twingate unreliable but PING works!")
            } else {
                realityCheckSuccess = false
                isAuthenticated = false
                addDebugLog("❌ REALITY: No ping")
            }
        }

        if (oldState !== realityCheckSuccess) {
            addDebugLog("🔄 Reality Check: " + oldState + " → " + realityCheckSuccess)
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            let cmd = sourceName
            let exitCode = data["exit code"]
            let stdout = data["stdout"] || ""

            addDebugLog("✓ Command: " + cmd.substring(0, 50))
            addDebugLog("  Exit: " + exitCode + " | Out: " + stdout.substring(0, 50))

            // ============ TWINGATE AUTH ============
            if (cmd.includes("twingate auth")) {
                if (exitCode === 0) {
                    addDebugLog("✅ Authentication initiated successfully")
                    // Nach Auth: Status neu prüfen
                    Qt.callLater(function() {
                        checkStatus()
                        checkResources()
                    })
                } else {
                    addDebugLog("❌ Authentication failed: " + stdout)
                }
            }

            // ============ SYSTEMCTL SHOW ============
            else if (cmd.includes("systemctl show")) {
                let lines = stdout.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line.startsWith("ActiveState=")) {
                        let oldState = serviceState
                        serviceState = line.replace("ActiveState=", "")

                        if (oldState !== serviceState) {
                            addDebugLog("🔄 Service State: " + oldState + " → " + serviceState)
                        }
                    }
                }
                updateRealityCheck()
            }

            // ============ SYSTEMCTL IS-ACTIVE ============
            else if (cmd.includes("systemctl") && cmd.includes("is-active")) {
                let wasRunning = serviceRunning
                serviceRunning = (exitCode === 0 && stdout.trim() === "active")

                if (wasRunning !== serviceRunning) {
                    addDebugLog("🔄 Service Running: " + wasRunning + " → " + serviceRunning)
                }
                updateRealityCheck()
            }

            // ============ SYSTEMCTL IS-ENABLED ============
            else if (cmd.includes("systemctl") && cmd.includes("is-enabled")) {
                let wasEnabled = serviceEnabled
                serviceEnabled = (exitCode === 0 && stdout.trim() === "enabled")

                if (wasEnabled !== serviceEnabled) {
                    addDebugLog("🔄 Service Enabled: " + wasEnabled + " → " + serviceEnabled)
                }
            }

            // ============ PING ============
            else if (cmd.startsWith("ping -c 1 -W 2")) {
                let ip = cmd.replace("ping -c 1 -W 2 ", "").trim()
                let success = (exitCode === 0)

                pingResults[ip] = success
                addDebugLog((success ? "✅" : "❌") + " Ping " + ip)

                let allSuccess = true
                let checkedCount = 0

                for (let key in pingResults) {
                    checkedCount++
                    if (pingResults[key] !== true) {
                        allSuccess = false
                        break
                    }
                }

                if (checkedCount === remoteNetworks.length) {
                    let oldPing = pingSuccess
                    pingSuccess = allSuccess

                    if (oldPing !== pingSuccess) {
                        addDebugLog("🔄 Ping Result: " + oldPing + " → " + pingSuccess + " (checked " + checkedCount + "/" + remoteNetworks.length + ")")
                    }

                    updateRealityCheck()
                }
            }

            // ============ TWINGATE STATUS ============
            else if (cmd.includes("twingate status")) {
                rawStatusOutput = stdout
                addDebugLog("=== TWINGATE STATUS ===")
                addDebugLog(stdout.substring(0, 200))

                let lines = stdout.toLowerCase().split("\n")
                let wasOnline = twingateReportsOnline
                let wasAuth = twingateReportsAuth

                twingateReportsOnline = false
                twingateReportsAuth = false

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()

                    if (line.includes("online") || line.includes("connected") || line.includes("running")) {
                        twingateReportsOnline = true
                    }
                    if (line.includes("authenticated") || line.includes("signed in")) {
                        twingateReportsAuth = true
                    }
                }

                if (wasOnline !== twingateReportsOnline) {
                    addDebugLog("🔄 Twingate Online: " + wasOnline + " → " + twingateReportsOnline)
                }
                if (wasAuth !== twingateReportsAuth) {
                    addDebugLog("🔄 Twingate Auth: " + wasAuth + " → " + twingateReportsAuth)
                }

                updateRealityCheck()
            }

            // ============ TWINGATE RESOURCES ============
            else if (cmd.includes("twingate resources")) {
                rawResourceOutput = stdout
                addDebugLog("=== RESOURCES ===")
                addDebugLog("Lines: " + stdout.split("\n").length)

                if (stdout.trim() === "" || stdout.includes("No resources")) {
                    addDebugLog("⚠️ No resources output")
                    resourceParseError = "No output from twingate resources"
                    updateRealityCheck()
                    disconnectSource(sourceName)
                    return
                }

                let lines = stdout.split("\n")
                let newResources = []
                let newNetworks = []

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line === "" || line.startsWith("#")) continue

                        let match1 = line.match(/^(\S+)\s+via\s+(\S+)/)
                        if (match1) {
                            newResources.push({
                                address: match1[1],
                                network: match1[2]
                            })
                            if (newNetworks.indexOf(match1[2]) === -1) {
                                newNetworks.push(match1[2])
                            }
                            continue
                        }

                        let match2 = line.match(/^(\S+\.\S+)/)
                        if (match2) {
                            newResources.push({
                                address: match2[1],
                                network: "default"
                            })
                            if (newNetworks.indexOf("default") === -1) {
                                newNetworks.push("default")
                            }
                        }
                }

                if (newResources.length > 0) {
                    resources = newResources
                    remoteNetworks = newNetworks
                    resourceParseError = ""
                    addDebugLog("✅ Parsed " + resources.length + " resources")
                } else {
                    resourceParseError = "Could not parse resources"
                    addDebugLog("⚠️ Parse failed")
                }

                updateRealityCheck()
            }

            // ============ START/STOP ============
            else if (cmd.includes("systemctl") && (cmd.includes("start") || cmd.includes("stop"))) {
                addDebugLog("Service command done: " + (exitCode === 0 ? "OK" : "FAIL"))
                Qt.callLater(function() {
                    checkSystemctl()
                })
            }

            disconnectSource(sourceName)
        }
    }

    Timer {
        id: checkTimer
        interval: 10000
        running: true
        repeat: true

        property int cycleCount: 0

        onTriggered: {
            cycleCount++

            checkSystemctl()

            if (serviceRunning && serviceState === "active") {
                checkStatus()
                checkResources()

                if (cycleCount % 3 === 0 && remoteNetworks.length > 0) {
                    addDebugLog("🔄 30-second ping cycle")
                    doPing()
                }
            }
        }
    }

    Component.onCompleted: {
        addDebugLog("=== TWINGATE WIDGET STARTED ===")
        parseRemoteNetworks()
        checkSystemctl()
        checkStatus()
        checkResources()
        if (remoteNetworks.length > 0) {
            doPing()
        }
        checkTimer.start()
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 400
        Layout.minimumHeight: 500
        spacing: 10

        PlasmaComponents.Label {
            text: "Twingate Status Monitor"
            font.bold: true
            font.pointSize: 14
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle { Layout.fillWidth: true; height: 2; color: Kirigami.Theme.highlightColor }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: 8
            columnSpacing: 16

            PlasmaComponents.Label { text: "🎯 Twingate Working:"; font.bold: true }
            RowLayout {
                Kirigami.Icon {
                    source: root.realityCheckSuccess ? "emblem-success" : "emblem-error"
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                }
                PlasmaComponents.Label {
                    text: root.realityCheckSuccess ? "YES" : "NO"
                    color: root.realityCheckSuccess ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                    font.bold: true
                }
            }

            Rectangle { Layout.columnSpan: 2; Layout.fillWidth: true; height: 1; color: Kirigami.Theme.textColor; opacity: 0.3 }

            PlasmaComponents.Label { text: "Service State:"; opacity: 0.7 }
            PlasmaComponents.Label {
                text: root.serviceState
                color: root.serviceState === "active" ? Kirigami.Theme.positiveTextColor :
                root.serviceState === "activating" ? Kirigami.Theme.neutralTextColor :
                Kirigami.Theme.negativeTextColor
            }

            PlasmaComponents.Label { text: "Service Running:"; opacity: 0.7 }
            PlasmaComponents.Label {
                text: root.serviceRunning ? "Active ✅" : "Stopped ❌"
                color: root.serviceRunning ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }

            PlasmaComponents.Label { text: "Service Enabled:"; opacity: 0.7 }
            PlasmaComponents.Label {
                text: root.serviceEnabled ? "Enabled ✅" : "Disabled ❌"
                color: root.serviceEnabled ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }

            PlasmaComponents.Label { text: "Reality Check (Ping):"; opacity: 0.7 }
            PlasmaComponents.Label {
                text: root.pingSuccess ? "All Success ✅" : "Failed ❌"
                color: root.pingSuccess ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }

            Rectangle { Layout.columnSpan: 2; Layout.fillWidth: true; height: 1; color: Kirigami.Theme.textColor; opacity: 0.2 }

            PlasmaComponents.Label { text: "twingate status:"; opacity: 0.5; font.italic: true }
            PlasmaComponents.Label {
                text: root.twingateReportsOnline ? "online" : "offline/unknown"
                opacity: 0.5
                font.italic: true
            }

            PlasmaComponents.Label { text: "twingate auth:"; opacity: 0.5; font.italic: true }
            PlasmaComponents.Label {
                text: root.twingateReportsAuth ? "yes" : "no/unknown"
                opacity: 0.5
                font.italic: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.textColor; opacity: 0.2 }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.resources.length > 0 || root.resourceParseError !== ""

            PlasmaComponents.Label {
                text: root.resourceParseError !== ""
                ? "⚠️ Resources (parse error)"
                : "📡 Resources (" + root.resources.length + ")"
                font.bold: true
            }

            PlasmaComponents.Label {
                visible: root.resourceParseError !== ""
                text: root.resourceParseError
                color: Kirigami.Theme.neutralTextColor
                font.italic: true
                opacity: 0.7
            }

            Repeater {
                model: root.resources
                delegate: RowLayout {
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        source: "network-connect"
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                    }

                    PlasmaComponents.Label {
                        text: modelData.address
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        text: "via " + modelData.network
                        opacity: 0.6
                        font.italic: true
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.textColor; opacity: 0.2 }

        ColumnLayout {
            Layout.fillWidth: true

            PlasmaComponents.Label {
                text: "📋 Debug Log"
                font.bold: true
            }

            PlasmaComponents.TextArea {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                text: root.debugLog
                readOnly: true
                font.family: "monospace"
                font.pointSize: 8
                wrapMode: TextEdit.Wrap
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Kirigami.Theme.textColor; opacity: 0.2 }

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents.Button {
                text: {
                    if (root.serviceState === "activating") return "Activating..."
                        if (root.waitingForServiceStart) return "Starting..."
                            return root.serviceRunning ? "Stop" : "Start"
                }
                icon.name: root.serviceRunning ? "process-stop" : "media-playback-start"
                enabled: {
                    if (root.serviceState === "activating") return false
                        let now = Date.now()
                        if (root.lastRestartTime > 0 && (now - root.lastRestartTime) < 60000) return false
                            return true
                }
                Layout.fillWidth: true
                onClicked: root.toggleService()
            }

            PlasmaComponents.Button {
                text: "Auth"
                icon.name: "dialog-password"
                enabled: root.serviceRunning && root.serviceState === "active" && !root.realityCheckSuccess && root.authResource !== ""
                Layout.fillWidth: true
                onClicked: root.doAuth()
            }

            PlasmaComponents.Button {
                text: "Ping"
                icon.name: "network-connect"
                enabled: remoteNetworks.length > 0
                onClicked: root.doPing()
            }
        }

        Item { Layout.fillHeight: true }
    }
}
