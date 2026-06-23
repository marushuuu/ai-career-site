import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class MyFirstWatchFaceView extends WatchUi.WatchFace {

    // Layout cache (set in onLayout)
    private var mCx as Number = 227;
    private var mCy as Number = 227;

    // ── Ocean & Wind palette ─────────────────────────────────────────────────
    private const C_BG        as Number = 0x000000; // black background
    private const C_HOUR      as Number = 0x0066FF; // deep blue  (hours)
    private const C_MIN       as Number = 0x00CCFF; // cyan       (minutes)
    private const C_GLOW_H    as Number = 0x002266; // glow shadow for hours
    private const C_GLOW_M    as Number = 0x004477; // glow shadow for minutes
    private const C_ACCENT    as Number = 0xFF6600; // orange accent
    private const C_RING_DIM  as Number = 0x001A3D; // dark navy ring
    private const C_SEC_DIM   as Number = 0x3D1A00; // dim orange for seconds track
    private const C_DATE      as Number = 0xAADDFF; // light blue for date
    private const C_VALUE     as Number = 0xDDEEFF; // near-white for stat values
    private const C_HR        as Number = 0xFF4444; // red for heart rate

    // Day / month name tables
    private const DAYS   as Array<String> = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
    private const MONTHS as Array<String> = ["Jan","Feb","Mar","Apr","May","Jun",
                                              "Jul","Aug","Sep","Oct","Nov","Dec"];

    private var mIsAwake as Boolean = true;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        mCx = dc.getWidth()  / 2;
        mCy = dc.getHeight() / 2;
    }

    function onShow()  as Void {}
    function onHide()  as Void {}

    function onEnterSleep() as Void {
        mIsAwake = false;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        mIsAwake = true;
        WatchUi.requestUpdate();
    }

    // Full-power update
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(C_BG, C_BG);
        dc.clear();
        var t = System.getClockTime();
        if (mIsAwake) {
            drawFullFace(dc, t);
        } else {
            drawAodFace(dc, t);
        }
    }

    // Low-power AOD update (called by the OS during always-on display)
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(C_BG, C_BG);
        dc.clear();
        drawAodFace(dc, System.getClockTime());
    }

    // ── Full face ────────────────────────────────────────────────────────────

    private function drawFullFace(dc as Graphics.Dc, t as System.ClockTime) as Void {
        drawDecorRing(dc);
        drawSecondsRing(dc, t.sec);
        drawTime(dc, t);
        drawSeconds(dc, t.sec);
        drawDateRow(dc);
        drawStatsRow(dc);
    }

    // ── AOD face (time only, minimal draw) ───────────────────────────────────

    private function drawAodFace(dc as Graphics.Dc, t as System.ClockTime) as Void {
        var h = normalizeHour(t.hour);
        var timeStr = h.format("%02d") + ":" + t.min.format("%02d");
        dc.setColor(0x004499, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, mCy, Graphics.FONT_NUMBER_THAI_HOT, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── Decorative outer ring with cardinal tick marks ───────────────────────

    private function drawDecorRing(dc as Graphics.Dc) as Void {
        dc.setColor(C_RING_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(mCx, mCy, 218);

        // Orange tick marks at cardinal positions
        dc.setColor(C_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(mCx,       mCy - 218, mCx,       mCy - 209); // 12
        dc.drawLine(mCx,       mCy + 209, mCx,       mCy + 218); // 6
        dc.drawLine(mCx + 209, mCy,       mCx + 218, mCy);       // 3
        dc.drawLine(mCx - 218, mCy,       mCx - 209, mCy);       // 9
    }

    // ── Seconds progress arc (orange ring, clockwise from 12 o'clock) ────────

    private function drawSecondsRing(dc as Graphics.Dc, sec as Number) as Void {
        // Background: full dim circle
        dc.setColor(C_SEC_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawCircle(mCx, mCy, 207);

        // Active arc
        if (sec > 0) {
            var endDeg = 90 - (sec * 6);
            dc.setColor(C_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            dc.drawArc(mCx, mCy, 207, Graphics.ARC_CLOCKWISE, 90, endDeg);
        }
    }

    // ── Main time display with per-channel glow ──────────────────────────────

    private function drawTime(dc as Graphics.Dc, t as System.ClockTime) as Void {
        var hStr = normalizeHour(t.hour).format("%02d");
        var mStr = t.min.format("%02d");
        var timeY = mCy - 85; // upper half

        // Hours in deep blue, minutes in cyan, colon in orange
        drawGlow(dc, mCx - 73, timeY, hStr,
                 Graphics.FONT_NUMBER_THAI_HOT, C_GLOW_H, C_HOUR);

        var jc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, timeY, Graphics.FONT_NUMBER_THAI_HOT, ":", jc);

        drawGlow(dc, mCx + 73, timeY, mStr,
                 Graphics.FONT_NUMBER_THAI_HOT, C_GLOW_M, C_MIN);
    }

    // ── Seconds numeric value ─────────────────────────────────────────────────

    private function drawSeconds(dc as Graphics.Dc, sec as Number) as Void {
        var jc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, mCy + 5, Graphics.FONT_MEDIUM, sec.format("%02d"), jc);
    }

    // ── Date row ──────────────────────────────────────────────────────────────

    private function drawDateRow(dc as Graphics.Dc) as Void {
        // Thin orange separator
        var sepY = mCy + 30;
        dc.setColor(C_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(mCx - 90, sepY, mCx + 90, sepY);

        // Date string: "Mon Jun 23"
        var info    = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = DAYS[info.day_of_week - 1] + " "
                    + MONTHS[info.month - 1]      + " "
                    + info.day.format("%d");

        var jc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_DATE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, mCy + 52, Graphics.FONT_SMALL, dateStr, jc);
    }

    // ── Stats row (battery | steps | bpm) ────────────────────────────────────

    private function drawStatsRow(dc as Graphics.Dc) as Void {
        var battery   = System.getSystemStats().battery.toNumber();
        var steps     = 0 as Number;
        var heartRate = 0 as Number;

        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null && actInfo.steps != null) {
            steps = actInfo.steps as Number;
        }

        var actData = Activity.getActivityInfo();
        if (actData != null && actData.currentHeartRate != null) {
            heartRate = actData.currentHeartRate as Number;
        }

        var labelY = mCy + 112;
        var valueY = mCy + 140;
        var col1   = mCx - 120;
        var col2   = mCx;
        var col3   = mCx + 120;

        // Top separator
        dc.setColor(C_RING_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(col1 - 25, labelY - 18, col3 + 25, labelY - 18);

        // Column dividers
        dc.drawLine(col1 + 55, labelY - 12, col1 + 55, valueY + 14);
        dc.drawLine(col2 + 55, labelY - 12, col2 + 55, valueY + 14);

        // Battery
        drawStat(dc, col1, labelY, valueY, "BAT",
                 battery.format("%d") + "%", C_ACCENT, C_VALUE);

        // Steps
        drawStat(dc, col2, labelY, valueY, "STEPS",
                 steps.format("%d"), C_ACCENT, C_VALUE);

        // Heart rate (red when active, near-white when unavailable)
        var hrStr   = (heartRate > 0) ? heartRate.format("%d") : "--";
        var hrColor = (heartRate > 0) ? C_HR : C_VALUE;
        drawStat(dc, col3, labelY, valueY, "BPM", hrStr, C_ACCENT, hrColor);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private function drawStat(dc    as Graphics.Dc,
                               x     as Number,
                               labY  as Number,
                               valY  as Number,
                               label as String,
                               value as String,
                               labColor as Number,
                               valColor as Number) as Void {
        var jc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(labColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, labY, Graphics.FONT_XTINY, label, jc);
        dc.setColor(valColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, valY, Graphics.FONT_SMALL, value, jc);
    }

    // Simulated glow: draw blurred shadow, then sharp text on top
    private function drawGlow(dc        as Graphics.Dc,
                               x         as Number,
                               y         as Number,
                               text      as String,
                               font      as Graphics.FontType,
                               glowColor as Number,
                               mainColor as Number) as Void {
        var jc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(glowColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + 2, y,     font, text, jc);
        dc.drawText(x - 2, y,     font, text, jc);
        dc.drawText(x,     y + 2, font, text, jc);
        dc.drawText(x,     y - 2, font, text, jc);
        dc.drawText(x + 2, y + 2, font, text, jc);
        dc.drawText(x - 2, y - 2, font, text, jc);
        dc.drawText(x + 2, y - 2, font, text, jc);
        dc.drawText(x - 2, y + 2, font, text, jc);
        dc.setColor(mainColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, jc);
    }

    // Converts 24-hour value to 12-hour if device is set to 12h mode
    private function normalizeHour(hour as Number) as Number {
        if (System.getDeviceSettings().is24Hour) {
            return hour;
        }
        if (hour == 0)  { return 12; }
        if (hour > 12)  { return hour - 12; }
        return hour;
    }
}
