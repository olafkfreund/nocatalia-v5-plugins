import QtQuick
import QtQuick.Layouts
import Quickshell as QS
import Quickshell.Io as QSIo
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property QS.ShellScreen screen: null
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string screenName: screen ? (screen.name ?? "") : ""
    readonly property real capsuleHeight: (typeof Style !== "undefined" && typeof Style.getCapsuleHeightForScreen === "function") ? Style.getCapsuleHeightForScreen(root.screenName) : 26
    readonly property real barFontSize: (typeof Style !== "undefined" && typeof Style.getBarFontSizeForScreen === "function") ? Style.getBarFontSizeForScreen(root.screenName) : 10
    readonly property string fixedFont: (typeof Settings !== "undefined" && Settings.data?.ui?.fontFixed) ? Settings.data.ui.fontFixed : "monospace"

    property int fanRpm: 0
    property string fanLevel: "auto"
    property int currentTemp: 0

    // Flag per accertarsi che sia stata fatta almeno la prima lettura hardware
    property bool isInitialized: false

    // Accurate layout width calculations wrapping strictly the fan elements
    readonly property real contentWidth: layout.implicitWidth + ((typeof Style !== "undefined") ? Style.marginS * 2 : 8)
    readonly property real contentHeight: capsuleHeight
    implicitWidth: contentWidth
    implicitHeight: (typeof Style !== "undefined") ? Style.barHeight : 32

    Component.onCompleted: {
        if (pluginApi) {
            pluginApi.mainInstance = root;
        }
        fanLoader.reload();
        tempLoader.reload();
    }

    // Fan status monitoring
    QSIo.FileView {
        id: fanLoader
        path: "/proc/acpi/ibm/fan"
        printErrors: false
        onLoaded: {
            let content = text();
            if (content) {
                let lines = content.split("\n");
                let parsedRpm = 0;
                let parsedLevel = "auto";

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line.indexOf("speed:") === 0) {
                        parsedRpm = parseInt(line.split(":")[1].trim());
                        if (isNaN(parsedRpm)) parsedRpm = 0;
                    } else if (line.indexOf("level:") === 0) {
                        parsedLevel = line.split(":")[1].replace(/[\r\n\t]/g, "").trim().toLowerCase();
                    }
                }

                root.fanRpm = parsedRpm;
                
                // Seguiamo sempre passivamente il valore hardware reale deciso da thinkfan
                root.fanLevel = parsedLevel;
                root.isInitialized = true;
            }
        }
    }

    // Background temperature tracker (logico)
    QSIo.FileView {
        id: tempLoader
        path: "/sys/class/thermal/thermal_zone0/temp"
        printErrors: false
        onLoaded: {
            let val = text();
            if (val) {
                let parsed = parseInt(val.trim());
                if (!isNaN(parsed)) {
                    root.currentTemp = Math.round(parsed / 1000);
                }
            }
        }
    }

    // Safe inline process execution engine
    function setFanSpeed(targetLevel) {
        if (!root.isInitialized) return;

        let cleanLevel = String(targetLevel).replace(/[\r\n\t]/g, "").trim().toLowerCase();
        if (!cleanLevel || cleanLevel === "unknown") return;
        
        // Aggiorna subito la UI locale in attesa che il comando venga applicato
        root.fanLevel = cleanLevel;
        try {
            let rawQml = "import Quickshell.Io; Process { command: ['sh', '-c', 'echo level " + cleanLevel + " > /proc/acpi/ibm/fan']; running: true }";
            let proc = Qt.createQmlObject(rawQml, root, "DynamicFanInlineProc");
            
            if (proc) {
                proc.exited.connect(function() {
                    refreshTimer.start();
                    proc.destroy();
                });
            }
        } catch (e) {
            // Fallback tracking
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            fanLoader.reload();
            tempLoader.reload();
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fanLoader.reload();
            tempLoader.reload();
        }
    }

    readonly property bool isCustomActive: root.fanLevel !== "auto" && root.fanLevel !== "0"

    Rectangle {
        id: visualCapsule
        anchors.centerIn: parent
        width: root.contentWidth
        height: root.contentHeight
        radius: (typeof Style !== "undefined") ? Style.radiusL : 6
        
        color: root.isCustomActive
            ? ((typeof Color !== "undefined") ? Color.mPrimary : "#3355ff")
            : (root.fanLevel === "0"
                ? "#cc241d"
                : ((typeof Style !== "undefined") ? Style.capsuleColor : "#1affffff"))

        border.color: root.isCustomActive
            ? ((typeof Color !== "undefined") ? Color.mPrimary : "#3355ff")
            : (root.fanLevel === "0"
                ? "#cc241d"
                : ((typeof Style !== "undefined") ? Style.capsuleBorderColor : "#33ffffff"))
        border.width: (typeof Style !== "undefined") ? Style.capsuleBorderWidth : 1

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 4

            NIcon {
                id: fanIcon
                icon: "car-fan"
                color: (typeof Color !== "undefined")
                    ? (root.isCustomActive || root.fanLevel === "0" ? Color.mOnPrimary : Color.mOnSurface)
                    : "#ffffff"
            }

            NText {
                id: fanText
                text: root.fanRpm + " RPM"
                pointSize: barFontSize
                font.family: root.fixedFont
                font.weight: Font.Bold
                color: (typeof Color !== "undefined")
                    ? (root.isCustomActive || root.fanLevel === "0" ? Color.mOnPrimary : Color.mOnSurface)
                    : "#ffffff"
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (pluginApi && typeof pluginApi.openPanel === "function") {
                pluginApi.openPanel(root.screen, root)
            }
        }
    }
}