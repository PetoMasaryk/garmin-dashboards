using Toybox.Activity;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.UserProfile;

class Edge530DashboardView extends WatchUi.DataField {
    const P_ZONE1 = 0xCBCBCB; // Light Gray
    const P_ZONE2 = 0x0097FC; // Blue
    const P_ZONE3 = 0x52E507; // Green
    const P_ZONE4 = 0xF3BF2D; // Yellow
    const P_ZONE5 = 0xEB690B; // Orange
    const P_ZONE6 = 0xE02E2C; // Red
    const P_ZONE7 = 0x6A53AE; // Purple

    const HR_ZONE1 = 0xCBCBCB; // Light Gray
    const HR_ZONE2 = 0x0097FC; // Blue
    const HR_ZONE3 = 0x52E507; // Green
    const HR_ZONE4 = 0xEB690B; // Orange
    const HR_ZONE5 = 0xE02E2C; // Red

    var _ftp = 230;
    var _useCustomPower = false;
    var _pZone1 = 126;
    var _pZone2 = 172;
    var _pZone3 = 207;
    var _pZone4 = 241;
    var _pZone5 = 276;
    var _pZone6 = 345;

    var _hrZone1 = 133;
    var _hrZone2 = 153;
    var _hrZone3 = 159;
    var _hrZone4 = 174;
    var _hrZone5 = 190;

    var _fgColor = 0xF5F7FA;
    var _mutedColor = 0x9EADC0;
    var _bgColor = 0x000000;

    var _powerSamples;
    var _powerIndex;
    var _powerCount;
    var _powerNullStreak;

    var _np30Samples;
    var _np30Index;
    var _np30Count;
    var _npSum4;
    var _npTotalCount;
    var _lastNp;

    var _lastDistance;
    var _lastAltitude;
    var _gradeSamples;
    var _gradeIndex;
    var _gradeCount;
    var _gradeTotal;
    var _smoothedGrade = 0.0;

    function initialize() {
        DataField.initialize();
        loadUserSettings();

        _powerSamples = [0, 0, 0, 0];
        _powerIndex = 0;
        _powerCount = 0;
        _powerNullStreak = 0;

        _np30Samples = [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        ];
        _np30Index = 0;
        _np30Count = 0;
        _npSum4 = 0.0;
        _npTotalCount = 0;
        _lastNp = null;

        _gradeSamples = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        _gradeIndex = 0;
        _gradeCount = 0;
        _gradeTotal = 0.0;
        _lastDistance = null;
        _lastAltitude = null;
    }

    function loadUserSettings() {
        // 1. FTP: Primary from Garmin User Profile -> Fallback to Custom Property -> Default 230W
        _ftp = 0;
        try {
            var profile = UserProfile.getProfile();
            if (profile != null && profile has :ftp && profile.ftp != null && profile.ftp > 0) {
                _ftp = profile.ftp;
            }
        } catch (ex) {}

        if (_ftp == 0) {
            try {
                var ftpVal = Application.Properties.getValue("CustomFtp");
                if (ftpVal != null && ftpVal > 0) {
                    _ftp = ftpVal;
                }
            } catch (ex) {}
        }

        if (_ftp == 0) {
            _ftp = 230; // Safety default fallback
        }

        // 2. Power Zones: Check if user explicitly enabled manual override
        _useCustomPower = false;
        try {
            var customPFlag = Application.Properties.getValue("UseCustomPowerZones");
            if (customPFlag != null) { _useCustomPower = customPFlag; }
        } catch (ex) {}

        if (_useCustomPower) {
            try {
                var p1 = Application.Properties.getValue("PowerZone1Max");
                var p2 = Application.Properties.getValue("PowerZone2Max");
                var p3 = Application.Properties.getValue("PowerZone3Max");
                var p4 = Application.Properties.getValue("PowerZone4Max");
                var p5 = Application.Properties.getValue("PowerZone5Max");
                var p6 = Application.Properties.getValue("PowerZone6Max");

                if (p1 != null && p1 > 0) { _pZone1 = p1; }
                if (p2 != null && p2 > 0) { _pZone2 = p2; }
                if (p3 != null && p3 > 0) { _pZone3 = p3; }
                if (p4 != null && p4 > 0) { _pZone4 = p4; }
                if (p5 != null && p5 > 0) { _pZone5 = p5; }
                if (p6 != null && p6 > 0) { _pZone6 = p6; }
            } catch (ex) {}
        }

        // 3. HR Zones: Primary from Garmin Device Profile -> Override if toggle enabled
        var useCustomHr = false;
        try {
            var customHrFlag = Application.Properties.getValue("UseCustomHrZones");
            if (customHrFlag != null) { useCustomHr = customHrFlag; }
        } catch (ex) {}

        var loadedFromDevice = false;
        if (!useCustomHr) {
            try {
                var hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_BIKING);
                if (hrZones == null || hrZones.size() < 6) {
                    hrZones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
                }
                if (hrZones != null && hrZones.size() >= 6) {
                    _hrZone1 = hrZones[1];
                    _hrZone2 = hrZones[2];
                    _hrZone3 = hrZones[3];
                    _hrZone4 = hrZones[4];
                    _hrZone5 = hrZones[5];
                    loadedFromDevice = true;
                }
            } catch (ex) {}
        }

        // Fallback to manual properties if device profile reading was bypassed or failed
        if (!loadedFromDevice) {
            try {
                var z1 = Application.Properties.getValue("HrZone1Max");
                var z2 = Application.Properties.getValue("HrZone2Max");
                var z3 = Application.Properties.getValue("HrZone3Max");
                var z4 = Application.Properties.getValue("HrZone4Max");
                var z5 = Application.Properties.getValue("HrZone5Max");

                if (z1 != null && z1 > 0) { _hrZone1 = z1; }
                if (z2 != null && z2 > 0) { _hrZone2 = z2; }
                if (z3 != null && z3 > 0) { _hrZone3 = z3; }
                if (z4 != null && z4 > 0) { _hrZone4 = z4; }
                if (z5 != null && z5 > 0) { _hrZone5 = z5; }
            } catch (ex) {}
        }
    }

    function compute(info) {
        if (info != null) {
            updateRollingValues(info);
        }
        return (info != null && info.currentPower != null) ? info.currentPower : 0;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var sx = w / 246.0;
        var sy = h / 322.0;
        var right = w - 6 * sx;

        var sysBg = getBackgroundColor();
        var night = (sysBg == Graphics.COLOR_BLACK || sysBg == 0x000000);

        _bgColor = night ? 0x000000 : 0xFFFFFF;
        _fgColor = night ? 0xF5F7FA : 0x111111;
        _mutedColor = night ? 0x9EADC0 : 0x555555;

        dc.setColor(_fgColor, _bgColor);
        dc.clear();

        var info = Activity.getActivityInfo();

        // HEADER: Gear, Clock, Battery
        drawText(dc, 7*sx, 8*sy, "GEAR", Graphics.FONT_XTINY,
            Graphics.TEXT_JUSTIFY_LEFT, _mutedColor, _bgColor);
        drawText(dc, 42*sx, 3*sy, gearString(info), Graphics.FONT_MEDIUM,
            Graphics.TEXT_JUSTIFY_LEFT, _fgColor, _bgColor);

        drawText(dc, w/2, 3*sy, clockString(), Graphics.FONT_MEDIUM,
            Graphics.TEXT_JUSTIFY_CENTER, _fgColor, _bgColor);

        var sysStats = System.getSystemStats();
        var batLevel = (sysStats != null && sysStats.battery != null) ? sysStats.battery.toNumber() : 0;
        var batFillCol = batLevel <= 15 ? 0xE02E2C : (batLevel <= 30 ? 0xEB690B : _fgColor);
        drawBatteryIcon(dc, right - 44*sx, 11*sy, 16, 8, batLevel, _mutedColor, batFillCol, _bgColor);
        drawText(dc, right, 8*sy, "Di2", Graphics.FONT_XTINY,
            Graphics.TEXT_JUSTIFY_RIGHT, _mutedColor, _bgColor);

        // POWER
        var power = rollingPower(info != null ? info.currentPower : null);
        var pColor = powerColor(power);
        
        drawText(dc, 7*sx, 28*sy, powerZoneName(power), Graphics.FONT_SMALL,
            Graphics.TEXT_JUSTIFY_LEFT, pColor, _bgColor);
        
        var powerStr = power == null ? "---" : power.toString();
        var pFont = Graphics.FONT_NUMBER_MEDIUM;
        var pUnitFont = Graphics.FONT_SMALL;
        var pDims = dc.getTextDimensions(powerStr, pFont);
        var uDims = dc.getTextDimensions("W", pUnitFont);
        var totalPWidth = pDims[0] + 2 * sx + uDims[0];
        var pStartX = right - totalPWidth;

        drawText(dc, pStartX, 22*sy, powerStr, pFont, Graphics.TEXT_JUSTIFY_LEFT, pColor, _bgColor);
        drawText(dc, pStartX + pDims[0] + 2*sx, 30*sy, "W", pUnitFont, Graphics.TEXT_JUSTIFY_LEFT, _mutedColor, _bgColor);

        drawPowerZoneBar(dc, 8*sx, 58*sy, w - 16*sx, 22*sy, power, sx, sy);

        // SPEED AND GRADE
        drawText(dc, 64*sx, 90*sy, "SPEED", Graphics.FONT_SMALL, Graphics.TEXT_JUSTIFY_CENTER, _mutedColor, _bgColor);
        var speed = (info != null && info.currentSpeed != null) ? info.currentSpeed * 3.6 : null;
        var speedStr = speed == null ? "--.-" : format1(speed);
        var speedDims = dc.getTextDimensions(speedStr, Graphics.FONT_NUMBER_MEDIUM);
        var speedStartX = 64*sx - (speedDims[0] + 2*sx + dc.getTextDimensions("km/h", Graphics.FONT_XTINY)[0]) / 2.0;

        drawText(dc, speedStartX, 112*sy, speedStr, Graphics.FONT_NUMBER_MEDIUM, Graphics.TEXT_JUSTIFY_LEFT, _fgColor, _bgColor);
        drawText(dc, speedStartX + speedDims[0] + 2*sx, 122*sy, "km/h", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_LEFT, _mutedColor, _bgColor);

        var avg = (info != null && info.averageSpeed != null) ? info.averageSpeed * 3.6 : null;
        drawText(dc, 64*sx, 151*sy, "AVG " + (avg == null ? "--.-" : format1(avg)), Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_CENTER, _mutedColor, _bgColor);

        drawText(dc, 182*sx, 90*sy, "GRADE", Graphics.FONT_SMALL, Graphics.TEXT_JUSTIFY_CENTER, _mutedColor, _bgColor);
        var gradeColor = _smoothedGrade > 1.0 ? P_ZONE5 : (_smoothedGrade < -1.0 ? P_ZONE2 : P_ZONE3);
        var gradeInt = (_smoothedGrade >= 0 ? (_smoothedGrade + 0.5).toNumber() : (_smoothedGrade - 0.5).toNumber());
        var gradeStr = gradeInt > 0 ? "+" + gradeInt.toString() : gradeInt.toString();
        var gradeDims = dc.getTextDimensions(gradeStr, Graphics.FONT_NUMBER_MEDIUM);
        var gradeStartX = 182*sx - (gradeDims[0] + 2*sx + dc.getTextDimensions("%", Graphics.FONT_XTINY)[0]) / 2.0;

        drawText(dc, gradeStartX, 112*sy, gradeStr, Graphics.FONT_NUMBER_MEDIUM, Graphics.TEXT_JUSTIFY_LEFT, gradeColor, _bgColor);
        drawText(dc, gradeStartX + gradeDims[0] + 2*sx, 122*sy, "%", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_LEFT, gradeColor, _bgColor);
        drawText(dc, 182*sx, 149*sy, _smoothedGrade > 1.0 ? "CLIMB" : (_smoothedGrade < -1.0 ? "DESCENT" : "FLAT"), Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_CENTER, gradeColor, _bgColor);

        // HEART RATE & CADENCE
        var hr = info != null ? info.currentHeartRate : null;
        var hrColor = heartRateColor(hr);
        dc.setColor(hrColor, hrColor);
        dc.fillRectangle((7*sx).toNumber(), (174*sy).toNumber(), (114*sx).toNumber(), (75*sy).toNumber());
        var hrTextColor = (hrColor == HR_ZONE1 || hrColor == 0xCBCBCB || hrColor == P_ZONE4) ? 0x000000 : 0xFFFFFF;

        drawHrText(dc, 64*sx, 178*sy, heartRateZoneName(hr), Graphics.FONT_SMALL, Graphics.TEXT_JUSTIFY_CENTER, hrColor, hrTextColor);
        drawHrText(dc, 64*sx, 200*sy, hr == null ? "--" : hr.toString(), Graphics.FONT_NUMBER_MEDIUM, Graphics.TEXT_JUSTIFY_CENTER, hrColor, hrTextColor);
        drawHrText(dc, 64*sx, 232*sy, "bpm", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_CENTER, hrColor, hrTextColor);
        
        var cadence = info != null ? info.currentCadence : null;
        drawText(dc, 182*sx, 178*sy, "CADENCE", Graphics.FONT_SMALL, Graphics.TEXT_JUSTIFY_CENTER, _mutedColor, _bgColor);
        drawText(dc, 182*sx, 200*sy, cadence == null ? "--" : cadence.toString(), Graphics.FONT_NUMBER_MEDIUM, Graphics.TEXT_JUSTIFY_CENTER, _fgColor, _bgColor);
        drawText(dc, 182*sx, 232*sy, "rpm", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_CENTER, _mutedColor, _bgColor);

        // ELEVATION
        var ascent = info != null ? info.totalAscent : null;
        var altitude = info != null ? info.altitude : null;
        var descent = info != null ? info.totalDescent : null;
        drawText(dc, 42*sx, 260*sy, "ASCENT", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_CENTER, _mutedColor, _bgColor);
        drawText(dc, 42*sx, 273*sy, meters(ascent), Graphics.FONT_SMALL, Graphics.TEXT_JUSTIFY_CENTER, _fgColor, _bgColor);
        drawText(dc, 123*sx, 260*sy, "ALTITUDE", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_CENTER, _mutedColor, _bgColor);
        drawText(dc, 123*sx, 273*sy, meters(altitude), Graphics.FONT_SMALL, Graphics.TEXT_JUSTIFY_CENTER, _fgColor, _bgColor);
        drawText(dc, 204*sx, 260*sy, "DESCENT", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_CENTER, _mutedColor, _bgColor);
        drawText(dc, 204*sx, 273*sy, meters(descent), Graphics.FONT_SMALL, Graphics.TEXT_JUSTIFY_CENTER, _fgColor, _bgColor);

        // FOOTER: Elapsed Time, Power (NP), Distance
        var elapsedTime = info != null ? info.elapsedTime : null;
        drawText(dc, 7*sx, 301*sy, "T", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_LEFT, _mutedColor, _bgColor);
        drawText(dc, 20*sx, 294*sy, elapsedString(elapsedTime), Graphics.FONT_MEDIUM, Graphics.TEXT_JUSTIFY_LEFT, _fgColor, _bgColor);

        var npVal = "--";
        if (_lastNp != null) {
            npVal = _lastNp.toString();
        } else if (info != null && info has :averagePower && info.averagePower != null) {
            npVal = info.averagePower.toString();
        }
        drawText(dc, 92*sx, 301*sy, "NP", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_LEFT, _mutedColor, _bgColor);
        drawText(dc, 110*sx, 294*sy, npVal, Graphics.FONT_MEDIUM, Graphics.TEXT_JUSTIFY_LEFT, _fgColor, _bgColor);

        // Distance & KM anchored cleanly to right margin to prevent any screen overflow
        var elapsedDist = info != null ? info.elapsedDistance : null;
        var distStr = distanceString(elapsedDist);
        var kmDims = dc.getTextDimensions("km", Graphics.FONT_XTINY);
        var kmWidth = kmDims[0];
        drawText(dc, right, 301*sy, "km", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_RIGHT, _mutedColor, _bgColor);

        var distValRight = right - kmWidth - 2*sx;
        drawText(dc, distValRight, 294*sy, distStr, Graphics.FONT_MEDIUM, Graphics.TEXT_JUSTIFY_RIGHT, _fgColor, _bgColor);

        var distDims = dc.getTextDimensions(distStr, Graphics.FONT_MEDIUM);
        var distValLeft = distValRight - distDims[0];
        drawText(dc, distValLeft - 3*sx, 301*sy, "D", Graphics.FONT_XTINY, Graphics.TEXT_JUSTIFY_RIGHT, _mutedColor, _bgColor);
    }

    function drawBatteryIcon(dc, x, y, w, h, level, outlineCol, fillCol, bgCol) {
        dc.setColor(outlineCol, bgCol);
        dc.drawRectangle(x.toNumber(), y.toNumber(), w, h);
        dc.fillRectangle((x + w).toNumber(), (y + 2).toNumber(), 2, h - 4);
        var fillW = ((w - 3) * level) / 100;
        if (fillW > 0) {
            dc.setColor(fillCol, bgCol);
            dc.fillRectangle((x + 1).toNumber(), (y + 1).toNumber(), fillW, h - 2);
        }
    }

    function drawPowerZoneBar(dc, x, y, width, height, power, sx, sy) {
        var colors = [P_ZONE1, P_ZONE2, P_ZONE3, P_ZONE4, P_ZONE5, P_ZONE6, P_ZONE7];
        
        var gap = 1 * sx;
        var totalGaps = 6 * gap;
        var usable = width - totalGaps;

        var bounds = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0];
        var maxScale = 1.0;

        if (_useCustomPower && _pZone6 > 0) {
            // Manual custom mode scaling
            maxScale = (_pZone6 * 1.25).toFloat();
            bounds[0] = clamp(_pZone1 / maxScale, 0.0, 1.0);
            bounds[1] = clamp(_pZone2 / maxScale, 0.0, 1.0);
            bounds[2] = clamp(_pZone3 / maxScale, 0.0, 1.0);
            bounds[3] = clamp(_pZone4 / maxScale, 0.0, 1.0);
            bounds[4] = clamp(_pZone5 / maxScale, 0.0, 1.0);
            bounds[5] = clamp(_pZone6 / maxScale, 0.0, 1.0);
            bounds[6] = 1.0;
        } else {
            // Standard FTP automatic mode
            maxScale = (_ftp * 2.0).toFloat();
            var limits = [0.55, 0.75, 0.90, 1.05, 1.20, 1.50, 2.00];
            for (var j = 0; j < 7; j++) {
                bounds[j] = clamp((limits[j] * _ftp) / maxScale, 0.0, 1.0);
            }
            bounds[6] = 1.0;
        }

        var prevX = x;
        for (var i = 0; i < 7; i++) {
            var segEndX = x + (bounds[i] * usable) + (i * gap);
            var segW = segEndX - prevX;

            if (segW > 0) {
                dc.setColor(colors[i], colors[i]);
                dc.fillRectangle(prevX.toNumber(), y.toNumber(), segW.toNumber(), height.toNumber());
            }
            prevX = segEndX + gap;
        }

        // Draw active power marker triangle
        if (power != null && maxScale > 0) {
            var pRatio = clamp(power.toFloat() / maxScale, 0.0, 1.0);
            var gapOffset = 0;
            for (var k = 0; k < 6; k++) {
                if (pRatio > bounds[k]) {
                    gapOffset += gap;
                } else {
                    break;
                }
            }
            var markerX = clamp(x + (pRatio * usable) + gapOffset, x + 2*sx, x + width - 2*sx);
            
            dc.setColor(_fgColor, _fgColor);
            dc.fillPolygon([
                [markerX.toNumber(), (y - 2*sy).toNumber()],
                [(markerX - 4*sx).toNumber(), (y - 7*sy).toNumber()],
                [(markerX + 4*sx).toNumber(), (y - 7*sy).toNumber()]
            ]);
        }
    }

    function updateRollingValues(info) {
        // 1. Power rolling calculation (3s average and 30s NP)
        if (info.currentPower != null) {
            var cp = info.currentPower;
            _powerSamples[_powerIndex] = cp;
            _powerIndex = (_powerIndex + 1) % 4;
            if (_powerCount < 4) { _powerCount++; }
            _powerNullStreak = 0;

            // 30s buffer for Normalized Power
            _np30Samples[_np30Index] = cp;
            _np30Index = (_np30Index + 1) % 30;
            if (_np30Count < 30) { _np30Count++; }

            if (_np30Count == 30) {
                var sum30 = 0.0;
                for (var s = 0; s < 30; s++) {
                    sum30 += _np30Samples[s];
                }
                var avg30 = sum30 / 30.0;
                var p4 = avg30 * avg30 * avg30 * avg30;
                _npSum4 += p4;
                _npTotalCount++;
                if (_npTotalCount > 0) {
                    var mean4 = _npSum4 / _npTotalCount;
                    _lastNp = Math.sqrt(Math.sqrt(mean4)).toNumber();
                }
            }
        } else {
            _powerNullStreak++;
            if (_powerNullStreak >= 3) {
                _powerCount = 0;
            }
        }

        // 2. Grade calculation with automatic lockout recovery
        if (info.elapsedDistance != null && info.altitude != null) {
            if (_lastDistance != null && _lastAltitude != null) {
                var dd = info.elapsedDistance - _lastDistance;
                var da = info.altitude - _lastAltitude;
                if (dd >= 1.5 && dd < 50.0) {
                    var g = clamp((da / dd) * 100.0, -25.0, 25.0);
                    if (_gradeCount == 8) {
                        _gradeTotal -= _gradeSamples[_gradeIndex];
                    } else {
                        _gradeCount++;
                    }
                    _gradeSamples[_gradeIndex] = g;
                    _gradeTotal += g;
                    _gradeIndex = (_gradeIndex + 1) % 8;
                    if (_gradeCount > 0) {
                        _smoothedGrade = _gradeTotal / _gradeCount;
                    }
                    _lastDistance = info.elapsedDistance;
                    _lastAltitude = info.altitude;
                } else if (dd >= 50.0 || dd < 0.0) {
                    // Reset reference points after gap/jump/lap to prevent permanent lockout
                    _lastDistance = info.elapsedDistance;
                    _lastAltitude = info.altitude;
                }
            } else {
                _lastDistance = info.elapsedDistance;
                _lastAltitude = info.altitude;
            }
        }
    }

    function rollingPower(fallback) {
        if (_powerCount == 0) { return fallback; }
        var count = _powerCount > 3 ? 3 : _powerCount;
        var sum = 0.0;
        for (var i = 0; i < count; i++) {
            sum += _powerSamples[(_powerIndex - 1 - i + 4) % 4];
        }
        return (sum / count).toNumber();
    }

    function heartRateColor(hr) {
        if (hr == null) { return _mutedColor; }
        if (hr <= _hrZone1) { return HR_ZONE1; }
        if (hr <= _hrZone2) { return HR_ZONE2; }
        if (hr <= _hrZone3) { return HR_ZONE3; }
        if (hr <= _hrZone4) { return HR_ZONE4; }
        return HR_ZONE5;
    }

    function heartRateZoneName(hr) {
        if (hr == null) { return "HEART RATE"; }
        if (hr <= _hrZone1) { return "ZONE 1"; }
        if (hr <= _hrZone2) { return "ZONE 2"; }
        if (hr <= _hrZone3) { return "ZONE 3"; }
        if (hr <= _hrZone4) { return "ZONE 4"; }
        return "ZONE 5";
    }

    function powerColor(power) {
        if (power == null) { return _mutedColor; }
        if (_useCustomPower) {
            if (power <= _pZone1) { return P_ZONE1; }
            if (power <= _pZone2) { return P_ZONE2; }
            if (power <= _pZone3) { return P_ZONE3; }
            if (power <= _pZone4) { return P_ZONE4; }
            if (power <= _pZone5) { return P_ZONE5; }
            if (power <= _pZone6) { return P_ZONE6; }
            return P_ZONE7;
        } else {
            if (_ftp <= 0) { return _mutedColor; }
            var p = power.toFloat() / _ftp.toFloat();
            if (p < 0.55) { return P_ZONE1; }
            if (p < 0.75) { return P_ZONE2; }
            if (p < 0.90) { return P_ZONE3; }
            if (p < 1.05) { return P_ZONE4; }
            if (p < 1.20) { return P_ZONE5; }
            if (p < 1.50) { return P_ZONE6; }
            return P_ZONE7;
        }
    }

    function powerZoneName(power) {
        if (power == null) { return "POWER"; }
        if (_useCustomPower) {
            if (power <= _pZone1) { return "RECOVERY"; }
            if (power <= _pZone2) { return "ENDURANCE"; }
            if (power <= _pZone3) { return "TEMPO"; }
            if (power <= _pZone4) { return "SWEETSPOT"; }
            if (power <= _pZone5) { return "THRESHOLD"; }
            if (power <= _pZone6) { return "VO2 MAX"; }
            return "ANAEROBIC";
        } else {
            if (_ftp <= 0) { return "POWER"; }
            var p = power.toFloat() / _ftp.toFloat();
            if (p < 0.55) { return "RECOVERY"; }
            if (p < 0.75) { return "ENDURANCE"; }
            if (p < 0.90) { return "TEMPO"; }
            if (p < 1.05) { return "SWEETSPOT"; }
            if (p < 1.20) { return "THRESHOLD"; }
            if (p < 1.50) { return "VO2 MAX"; }
            return "ANAEROBIC";
        }
    }

    function gearString(info) {
        if (info != null && info has :frontDerailleurIndex && info has :rearDerailleurIndex) {
            if (info.frontDerailleurIndex != null && info.rearDerailleurIndex != null) {
                return info.frontDerailleurIndex.toString() + "-" + info.rearDerailleurIndex.toString();
            }
        }
        return "--";
    }

    function clockString() {
        var t = System.getClockTime();
        return pad2(t.hour) + ":" + pad2(t.min);
    }

    function elapsedString(ms) {
        if (ms == null) { return "--:--"; }
        var total = (ms / 1000).toNumber();
        var h = (total / 3600).toNumber();
        var m = ((total % 3600) / 60).toNumber();
        if (h > 0) { return h.toString() + ":" + pad2(m); }
        return m.toString() + ":" + pad2(total % 60);
    }

    function distanceString(metersVal) {
        if (metersVal == null) { return "--.-"; }
        return (metersVal / 1000.0).format("%.1f");
    }

    function pad2(n) { return n < 10 ? "0" + n.toString() : n.toString(); }
    function meters(v) { return v == null ? "-- m" : v.toNumber().toString() + " m"; }
    function format1(v) { return (v / 1.0).format("%.1f"); }
    function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }

    function drawText(dc, x, y, value, font, justification, color, bgColor) {
        dc.setColor(color, bgColor);
        dc.drawText(x, y, font, value, justification);
    }
    
    function drawHrText(dc, x, y, value, font, justification, hrColor, textColor) {
        dc.setColor(textColor, hrColor);
        dc.drawText(x, y, font, value, justification);
    }
}
