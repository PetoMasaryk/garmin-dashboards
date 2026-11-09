using Toybox.Activity;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.UserProfile;
using Toybox.WatchUi;

// ============================================================
// APPLICATION ENTRY POINT
// ============================================================

class HRZoneApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new HRZoneView() ];
    }
}

// ============================================================
// HEART RATE ZONE DATA FIELD
// ============================================================

class HRZoneView extends WatchUi.DataField {

    // --------------------------------------------------------
    // HR ZONE COLORS (5 Garmin Zones)
    // --------------------------------------------------------

    const ZONE1_COLOR = 0xCBCBCB; // Z1 - Light Gray
    const ZONE2_COLOR = 0x1876D0; // Z2 - Blue
    const ZONE3_COLOR = 0x0A953C; // Z3 - Green
    const ZONE4_COLOR = 0xEB690B; // Z4 - Orange
    const ZONE5_COLOR = 0xE02E2C; // Z5 - Red

    // --------------------------------------------------------
    // CONFIGURATION
    // --------------------------------------------------------

    const SAMPLE_COUNT = 3;

    // --------------------------------------------------------
    // VARIABLES
    // --------------------------------------------------------

    var _hrZones; // Stores explicit upper BPM bounds for zones 1 to 5

    var _hrSamples;
    var _sampleIndex;
    var _samplesUsed;
    var _hrSum;

    var _displayHr;
    var _zoneColor;

    // --------------------------------------------------------
    // INITIALIZATION
    // --------------------------------------------------------

    function initialize() {
        DataField.initialize();

        // Default fallbacks in case profile lookup fails
        _hrZones = [133, 153, 159, 174, 190];

        _hrSamples = [0, 0, 0];
        _sampleIndex = 0;
        _samplesUsed = 0;
        _hrSum = 0;

        _displayHr = 0;
        _zoneColor = ZONE1_COLOR;

        // Retrieve Garmin user profile heart rate zones (returns absolute BPM limits)
        var hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if (hrZones != null && hrZones.size() >= 6) {
            // Garmin format: [minZ1, maxZ1, maxZ2, maxZ3, maxZ4, maxZ5]
            _hrZones = [
                hrZones[1], // Zone 1 upper limit (e.g., 133)
                hrZones[2], // Zone 2 upper limit (e.g., 153)
                hrZones[3], // Zone 3 upper limit (e.g., 159)
                hrZones[4], // Zone 4 upper limit (e.g., 174)
                hrZones[5]  // Zone 5 upper limit (Max HR)
            ];
        }
    }

    // --------------------------------------------------------
    // COMPUTATION
    // --------------------------------------------------------

    function compute(info) {
        var currentHr = 0;

        if (info != null) {
            if (info.currentHeartRate != null) {
                currentHr = info.currentHeartRate;
            }
        }

        updateRollingHr(currentHr);
        _zoneColor = getHRZoneColor(_displayHr);
    }

    // --------------------------------------------------------
    // THREE SECOND ROLLING HR AVERAGE
    // --------------------------------------------------------

    function updateRollingHr(currentHr) {
        if (_samplesUsed == SAMPLE_COUNT) {
            _hrSum -= _hrSamples[_sampleIndex];
        } else {
            _samplesUsed++;
        }

        _hrSamples[_sampleIndex] = currentHr;
        _hrSum += currentHr;
        _sampleIndex = (_sampleIndex + 1) % SAMPLE_COUNT;

        if (_samplesUsed > 0) {
            _displayHr = (_hrSum / _samplesUsed).toNumber();
        } else {
            _displayHr = 0;
        }
    }

    // --------------------------------------------------------
    // HR ZONE CALCULATION (Based on absolute BPM thresholds)
    // --------------------------------------------------------

    function getHRZoneColor(hr) {
        if (hr <= 0) {
            return ZONE1_COLOR;
        }

        if (hr <= _hrZones[0]) { return ZONE1_COLOR; } // <= 133
        if (hr <= _hrZones[1]) { return ZONE2_COLOR; } // <= 153
        if (hr <= _hrZones[2]) { return ZONE3_COLOR; } // <= 159
        if (hr <= _hrZones[3]) { return ZONE4_COLOR; } // <= 174
        return ZONE5_COLOR;                            // > 174
    }

    function getHRZoneName(hr) {
        if (hr <= 0) {
            return "ZONE 1";
        }

        if (hr <= _hrZones[0]) { return "ZONE 1"; }
        if (hr <= _hrZones[1]) { return "ZONE 2"; }
        if (hr <= _hrZones[2]) { return "ZONE 3"; }
        if (hr <= _hrZones[3]) { return "ZONE 4"; }
        return "ZONE 5";
    }

    // --------------------------------------------------------
    // TEXT CONTRAST
    // --------------------------------------------------------

    function getContrastTextColor(bgColor) {
        // Light Gray background requires black text for contrast
        if (bgColor == ZONE1_COLOR) {
            return Graphics.COLOR_BLACK;
        }
        return Graphics.COLOR_WHITE;
    }

    // --------------------------------------------------------
    // DISPLAY RENDERING
    // --------------------------------------------------------

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var bg = _zoneColor;
        var fg = getContrastTextColor(bg);

        dc.setColor(bg, bg);
        dc.clear();

        dc.setColor(fg, bg);

        // --------------------------------------------------------
        // HEART RATE ICON – HEART WITH ECG PULSE
        // --------------------------------------------------------

        var hx = 5;
        var hy = 3;

        dc.fillPolygon([
            [hx + 11, hy + 20],
            [hx + 8,  hy + 17],
            [hx + 4,  hy + 13],
            [hx + 1,  hy + 10],
            [hx,      hy + 7],
            [hx + 1,  hy + 4],
            [hx + 3,  hy + 2],
            [hx + 6,  hy + 1],
            [hx + 9,  hy + 2],
            [hx + 11, hy + 5],
            [hx + 13, hy + 2],
            [hx + 16, hy + 1],
            [hx + 19, hy + 2],
            [hx + 21, hy + 4],
            [hx + 22, hy + 7],
            [hx + 21, hy + 10],
            [hx + 18, hy + 13],
            [hx + 14, hy + 17]
        ]);

        // Restore text color
        dc.setColor(fg, bg);

        // Zone name at the top center (bumped up to FONT_SMALL)
        var zoneName = getHRZoneName(_displayHr);
        dc.drawText(
            w / 2,
            2,
            Graphics.FONT_SMALL,
            zoneName,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Main heart rate number centered
        var hrText = _displayHr.toString();
        dc.drawText(
            w / 2,
            h / 2 - 31,
            Graphics.FONT_NUMBER_HOT,
            hrText,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}