using Toybox.Application;
using Toybox.WatchUi;

class Edge530DashboardApp extends Application.AppBase {
    private var _view;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        _view = new Edge530DashboardView();
        return [ _view ];
    }

    function onSettingsChanged() {
        if (_view != null) {
            _view.loadUserSettings();
            WatchUi.requestUpdate();
        }
    }
}

function getApp() as Edge530DashboardApp {
    return Application.getApp() as Edge530DashboardApp;
}