import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property var pluginSettings: pluginApi?.pluginSettings ?? ({})
    readonly property var main: pluginApi?.mainInstance ?? ({})

    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

    readonly property string displayMode: pluginSettings.displayMode ?? "alwaysShow"
    readonly property bool isLoading: main.isLoading ?? true

    readonly property string pillIcon: isLoading ? "reload" : "robot"
    readonly property string pillText: {
        if (isLoading) return "";
        const s = main.sessionPercent ?? -1;
        const w = main.weeklyPercent  ?? -1;
        switch (main.barMetric ?? "auto") {
            case "session": return s >= 0 ? Math.round(s) + "%" : "--";
            case "weekly":  return w >= 0 ? Math.round(w) + "%" : "--";
            case "cost":    return "$" + (main.todayCost ?? 0).toFixed(2);
            default:        return s >= 0 ? Math.round(s) + "%"
                                          : "$" + (main.todayCost ?? 0).toFixed(2);
        }
    }

    readonly property color budgetColor: {
        if (isLoading) return "transparent";
        const p = main.budgetPercent ?? -1;
        if (p >= 80) return Color.mError;
        if (p >= 50) return Color.mTertiary;
        return "transparent";
    }

    readonly property bool isOverBudget: (main?.budgetPercent ?? -1) >= 100

    implicitWidth: barPill.width
    implicitHeight: barPill.height

    NPopupContextMenu {
        id: contextMenu
        model: [{
            label: pluginApi?.tr("settings.pluginSettings"),
            action: "plugin-settings",
            icon: "settings"
        }]
        onTriggered: (action) => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "plugin-settings" && pluginApi)
                BarService.openPluginSettings(screen, pluginApi.manifest);
        }
    }

    BarPill {
        id: barPill
        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        autoHide: false

        icon: root.pillIcon
        text: root.pillText
        tooltipText: {
            const parts = [];
            const pct = root.main.sessionPercent ?? -1;
            if (pct >= 0) parts.push("Session " + Math.round(pct) + "%");
            parts.push("$" + (root.main.todayCost ?? 0).toFixed(2) + " today");
            parts.push("$" + (root.main.monthCost ?? 0).toFixed(2) + " this month");
            return parts.join(" · ");
        }

        forceOpen: !root.isBarVertical && root.displayMode === "alwaysShow"
        forceClose: root.isBarVertical || root.displayMode === "alwaysHide"

        customTextIconColor: root.budgetColor

        SequentialAnimation {
            running: root.isOverBudget
            loops: Animation.Infinite
            onRunningChanged: if (!running) barPill.opacity = 1.0
            NumberAnimation { target: barPill; property: "opacity"; to: 0.4; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { target: barPill; property: "opacity"; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
        }

        onClicked: {
            if (pluginApi)
                pluginApi.openPanel(root.screen, barPill);
        }

        onRightClicked: {
            PanelService.showContextMenu(contextMenu, barPill, screen);
        }
    }
}
