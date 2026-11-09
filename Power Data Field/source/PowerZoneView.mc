using Toybox.Activity;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.UserProfile;
using Toybox.WatchUi;


// ============================================================
// APPLICATION ENTRY POINT
// ============================================================

class PowerZoneApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new PowerZoneView() ];
    }
}


// ============================================================
// POWER ZONE DATA FIELD
// ============================================================

class PowerZoneView extends WatchUi.DataField {

    // --------------------------------------------------------
    // POWER ZONE COLORS & NAMES
    // --------------------------------------------------------

    const ZONE1_COLOR = 0xCBCBCB; // Recovery - White / Light Gray
    const ZONE2_COLOR = 0x1876D0; // Endurance - Blue
    const ZONE3_COLOR = 0x0A953C; // Tempo - Green
    const ZONE4_COLOR = 0xF3BF2D; // Threshold - Yellow
    const ZONE5_COLOR = 0xEB690B; // VO2 Max - Orange
    const ZONE6_COLOR = 0xE02E2C; // Anaerobic - Red
    const ZONE7_COLOR = 0x6A53AE; // Neuromuscular - Purple
    const COLOR_NO_POWER = Graphics.COLOR_DK_GRAY;

    const ZONE_COLORS = [
        ZONE1_COLOR,
        ZONE2_COLOR,
        ZONE3_COLOR,
        ZONE4_COLOR,
        ZONE5_COLOR,
        ZONE6_COLOR,
        ZONE7_COLOR
    ];

    const ZONE_NAMES = [
        "RECOVERY",
        "ENDURANCE",
        "TEMPO",
        "THRESHOLD",
        "VO2 MAX",
        "ANAEROBIC",
        "NEUROMUSC"
    ];

    // --------------------------------------------------------
    // CONFIGURATION
    // --------------------------------------------------------

    // Used when Garmin FTP cannot be retrieved.
    const DEFAULT_FTP = 300;

    // Rolling average duration in seconds.
    const SAMPLE_COUNT = 3;

    // --------------------------------------------------------
    // VARIABLES
    // --------------------------------------------------------

    var _ftp;

    var _powerSamples;
    var _sampleIndex;
    var _samplesUsed;
    var _powerSum;

    var _hasPowerData;
    var _displayPower;
    var _zoneIndex;
    var _zoneColor;
    var _zoneName;


    // --------------------------------------------------------
    // INITIALIZATION
    // --------------------------------------------------------

    function initialize() {

        DataField.initialize();

        _ftp = DEFAULT_FTP;

        _powerSamples = [0, 0, 0];
        _sampleIndex = 0;
        _samplesUsed = 0;
        _powerSum = 0;

        _hasPowerData = false;
        _displayPower = 0;
        _zoneIndex = 0;
        _zoneColor = COLOR_NO_POWER;
        _zoneName = "--";

        // Retrieve cycling FTP from Garmin user profile.
        var ftp = UserProfile.getFunctionalThresholdPower(
            Activity.SPORT_CYCLING
        );

        if (ftp != null && ftp > 0) {
            _ftp = ftp;
        }
    }


    // --------------------------------------------------------
    // POWER DATA COMPUTATION
    // Called approximately once per second by Garmin.
    // --------------------------------------------------------

    function compute(info) {

        if (info != null && info.currentPower != null) {
            _hasPowerData = true;

            updateRollingPower(info.currentPower);

            _zoneIndex = getPowerZoneIndex(_displayPower);
            _zoneColor = ZONE_COLORS[_zoneIndex];
            _zoneName = ZONE_NAMES[_zoneIndex];
        } else {
            // Power dropout or sensor not connected:
            // Do not treat as 0 W (which represents coasting).
            _hasPowerData = false;
            _displayPower = 0;

            // Reset circular buffer so stale pre-dropout data does not skew averages upon reconnect.
            _samplesUsed = 0;
            _powerSum = 0;
            _sampleIndex = 0;
            _powerSamples = [0, 0, 0];

            _zoneColor = COLOR_NO_POWER;
            _zoneName = "--";
        }
    }


    // --------------------------------------------------------
    // THREE SECOND ROLLING POWER AVERAGE
    // --------------------------------------------------------

    function updateRollingPower(currentPower) {

        // Remove the oldest sample when the buffer is full.
        if (_samplesUsed == SAMPLE_COUNT) {

            _powerSum -= _powerSamples[_sampleIndex];

        } else {

            _samplesUsed++;
        }

        // Insert the new sample.
        _powerSamples[_sampleIndex] = currentPower;

        _powerSum += currentPower;

        // Move circular buffer index.
        _sampleIndex = (_sampleIndex + 1) % SAMPLE_COUNT;

        // Calculate rounded average (avoids integer division truncation).
        if (_samplesUsed > 0) {

            _displayPower = Math.round(_powerSum.toFloat() / _samplesUsed).toNumber();

        } else {

            _displayPower = 0;
        }
    }


    // --------------------------------------------------------
    // CONSOLIDATED POWER ZONE CALCULATION
    // --------------------------------------------------------

    function getPowerZoneIndex(power) {

        if (_ftp <= 0 || power == null) {
            return 0;
        }

        var ratio = power.toFloat() / _ftp.toFloat();

        if (ratio < 0.55) { return 0; }
        if (ratio < 0.75) { return 1; }
        if (ratio < 0.90) { return 2; }
        if (ratio < 1.05) { return 3; }
        if (ratio < 1.20) { return 4; }
        if (ratio < 1.50) { return 5; }

        return 6;
    }

    function getPowerZoneColor(power) {
        return ZONE_COLORS[getPowerZoneIndex(power)];
    }

    function getPowerZoneName(power) {
        return ZONE_NAMES[getPowerZoneIndex(power)];
    }


    // --------------------------------------------------------
    // TEXT CONTRAST
    // --------------------------------------------------------

    function getContrastTextColor(bgColor) {

        if (bgColor == ZONE1_COLOR ||
            bgColor == ZONE4_COLOR) {

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
        // LARGE LIGHTNING BOLT ICON
        // --------------------------------------------------------

        var lx = 5;
        var ly = 2;

        // Filled lightning bolt (22 x 26 px)
        dc.fillPolygon([
            [lx + 15, ly],
            [lx + 4,  ly + 15],
            [lx + 10, ly + 15],
            [lx + 7,  ly + 26],
            [lx + 22, ly + 10],
            [lx + 14, ly + 10]
        ]);

        // Zone name at the top (precomputed in compute).
        dc.drawText(
            w / 2,
            2,
            Graphics.FONT_TINY,
            _zoneName,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Main power number or dropout placeholder.
        var powerText = _hasPowerData ? _displayPower.toString() : "---";

        dc.drawText(
            w / 2,
            h / 2 - 35,
            Graphics.FONT_NUMBER_HOT,
            powerText,
            Graphics.TEXT_JUSTIFY_CENTER
        );

        // Smaller W suffix (measured against FONT_NUMBER_HOT, only drawn when data is active).
        if (_hasPowerData) {
            var numberWidth = dc.getTextWidthInPixels(
                powerText,
                Graphics.FONT_NUMBER_HOT
            );

            var numberHeight = dc.getFontHeight(
                Graphics.FONT_NUMBER_HOT
            );

            dc.drawText(
                (w / 2) + (numberWidth / 2) + 4,
                h / 2 - 17 + (numberHeight / 2),
                Graphics.FONT_XTINY,
                "W",
                Graphics.TEXT_JUSTIFY_LEFT
            );
        }
    }
}
