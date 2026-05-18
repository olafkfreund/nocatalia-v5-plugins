import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io as QSIo
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    // ===== NOCTALIA REQUIRED PROPERTIES =====
    property var pluginApi: null
    property ShellScreen screen
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
    property bool isInitialized: false

    // ===== READING NATIVE NOCTALIA SETTINGS =====
    readonly property bool colorizeByStatus:
        pluginApi?.pluginSettings?.colorizeByStatus ??
        pluginApi?.manifest?.metadata?.defaultSettings?.colorizeByStatus ??
        true

    readonly property bool allowPopupOpening:
        pluginApi?.pluginSettings?.allowPopupOpening ??
        pluginApi?.manifest?.metadata?.defaultSettings?.allowPopupOpening ??
        true

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

    // Hardware fan monitoring (passive tracking bound to thinkfan)
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
                root.fanLevel = parsedLevel;
                root.isInitialized = true;
            }
        }
    }

    // System temperature monitoring
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

    // Executing ACPI fan commands
    function setFanSpeed(targetLevel) {
        if (!root.isInitialized) return;

        let cleanLevel = String(targetLevel).replace(/[\r\n\t]/g, "").trim().toLowerCase();
        if (!cleanLevel || cleanLevel === "unknown") return;
        
        root.fanLevel = cleanLevel;
        try {
            let rawQml = 'import Quickshell.Io; Process { command: ["sh", "-c", "echo level ' + cleanLevel + ' > /proc/acpi/ibm/fan"]; running: true }';
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

    Timer { id: refreshTimer; interval: 300; repeat: false; onTriggered: { fanLoader.reload(); tempLoader.reload(); } }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { fanLoader.reload(); tempLoader.reload(); } }

    readonly property bool isCustomActive: root.fanLevel !== "auto" && root.fanLevel !== "0"

    // ===== NATIVE NOCTALIA CONTEXT MENU =====
    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": "Widget Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)

            if (action === "settings") {
                if (pluginApi?.manifest) {
                    BarService.openPluginSettings(screen, pluginApi.manifest)
                }
            }
        }
    }

    // ===== GRAPHICAL INTERFACE (CAPSULE) =====
    Rectangle {
        id: visualCapsule
        anchors.centerIn: parent
        width: root.contentWidth
        height: root.contentHeight
        radius: (typeof Style !== "undefined") ? Style.radiusL : 6
        
        color: !root.colorizeByStatus
            ? ((typeof Style !== "undefined") ? Style.capsuleColor : "#1affffff")
            : (root.isCustomActive
                ? ((typeof Color !== "undefined") ? Color.mPrimary : "#3355ff")
                : (root.fanLevel === "0" ? "#cc241d" : ((typeof Style !== "undefined") ? Style.capsuleColor : "#1affffff")))

        border.color: !root.colorizeByStatus
            ? ((typeof Style !== "undefined") ? Style.capsuleBorderColor : "#33ffffff")
            : (root.isCustomActive
                ? ((typeof Color !== "undefined") ? Color.mPrimary : "#3355ff")
                : (root.fanLevel === "0" ? "#cc241d" : ((typeof Style !== "undefined") ? Style.capsuleBorderColor : "#33ffffff")))
        border.width: (typeof Style !== "undefined") ? Style.capsuleBorderWidth : 1

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: (typeof Style !== "undefined") ? Style.marginXS : 4 // Fixed: Avoided hardcoded spacing value

            NIcon {
                id: fanIcon
                icon: "car-fan"
                color: (typeof Color !== "undefined")
                    ? (root.colorizeByStatus && (root.isCustomActive || root.fanLevel === "0") ? Color.mOnPrimary : Color.mOnSurface)
                    : "#ffffff"
            }

            NText {
                id: fanText
                text: root.fanRpm + " RPM"
                pointSize: barFontSize
                font.family: root.fixedFont
                font.weight: Font.Bold
                color: (typeof Color !== "undefined")
                    ? (root.colorizeByStatus && (root.isCustomActive || root.fanLevel === "0") ? Color.mOnPrimary : Color.mOnSurface)
                    : "#ffffff"
            }
        }
    }

    // ===== INTERACTION MANAGEMENT =====
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen)
            } else if (mouse.button === Qt.LeftButton) {
                if (root.allowPopupOpening && pluginApi && typeof pluginApi.openPanel === "function") {
                    pluginApi.openPanel(root.screen, root);
                }
            }
        }
    }
}