import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// MIP (Memory-in-Pixel) watch face for Forerunner 570.
// No glow / gradient effects — high-contrast, battery-friendly design.
class MyFirstWatchFaceView extends WatchUi.WatchFace {

    private var mCx as Number = 140;
    private var mCy as Number = 140;

    // ── MIP color palette ────────────────────────────────────────────────────
    // MIP supports a limited set of colors; stick to safe constants.
    private const C_BG    as Number = 0x000000; // black
    private const C_TIME  as Number = 0xFFFFFF; // white  (max contrast for time)
    private const C_ACNT  as Number = 0xFF5500; // orange (accent / labels)
    private const C_SEC   as Number = 0xFFAA00; // amber  (seconds)
    private const C_DATE  as Number = 0xAAAAAA; // gray   (date)
    private const C_VAL   as Number = 0xFFFFFF; // white  (stat values)
    private const C_HR    as Number = 0xFF0000; // red    (heart rate active)
    private const C_DIM   as Number = 0x444444; // dark gray (ring / dividers)

    private const DAYS   as Array<String> = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
    private const MONTHS as Array<String> = ["Jan","Feb","Mar","Apr","May","Jun",
                                              "Jul","Aug","Sep","Oct","Nov","Dec"];

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        mCx = dc.getWidth()  / 2;
        mCy = dc.getHeight() / 2;
    }

    function onShow()  as Void {}
    function onHide()  as Void {}

    // MIP: request a redraw on power-state change so the OS refreshes cleanly.
    function onEnterSleep() as Void { WatchUi.requestUpdate(); }
    function onExitSleep()  as Void { WatchUi.requestUpdate(); }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(C_BG, C_BG);
        dc.clear();

        var t = System.getClockTime();
        drawOuterRing(dc);
        drawSecondsRing(dc, t.sec);
        drawTime(dc, t);
        drawSeconds(dc, t.sec);
        drawDate(dc);
        drawStats(dc);
    }

    // ── Outer decorative ring ────────────────────────────────────────────────

    private function drawOuterRing(dc as Graphics.Dc) as Void {
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(mCx, mCy, mCx - 4);

        // Orange tick marks at 12 / 3 / 6 / 9
        dc.setColor(C_ACNT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var r0 = mCx - 4;
        var r1 = mCx - 11;
        dc.drawLine(mCx,       mCy - r0, mCx,       mCy - r1);
        dc.drawLine(mCx,       mCy + r1, mCx,       mCy + r0);
        dc.drawLine(mCx + r1, mCy,       mCx + r0, mCy);
        dc.drawLine(mCx - r0, mCy,       mCx - r1, mCy);
    }

    // ── Seconds progress arc (clockwise from 12 o'clock) ────────────────────

    private function drawSecondsRing(dc as Graphics.Dc, sec as Number) as Void {
        var r = mCx - 9;
        // Dim background track
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle(mCx, mCy, r);
        // Active arc in orange
        if (sec > 0) {
            dc.setColor(C_ACNT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawArc(mCx, mCy, r, Graphics.ARC_CLOCKWISE, 90, 90 - (sec * 6));
        }
    }

    // ── Time: HH:MM in white, large ──────────────────────────────────────────

    private function drawTime(dc as Graphics.Dc, t as System.ClockTime) as Void {
        var h       = normalizeHour(t.hour);
        var timeStr = h.format("%02d") + ":" + t.min.format("%02d");
        var jc      = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, mCy - mCy / 4, Graphics.FONT_NUMBER_THAI_HOT, timeStr, jc);
    }

    // ── Seconds numeric ───────────────────────────────────────────────────────

    private function drawSeconds(dc as Graphics.Dc, sec as Number) as Void {
        var jc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_SEC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, mCy + mCy / 10, Graphics.FONT_SMALL, sec.format("%02d"), jc);
    }

    // ── Date row ──────────────────────────────────────────────────────────────

    private function drawDate(dc as Graphics.Dc) as Void {
        var sepY = mCy + mCy / 4;

        // Thin orange rule
        dc.setColor(C_ACNT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(mCx - mCx / 2, sepY, mCx + mCx / 2, sepY);

        var info    = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = DAYS[info.day_of_week - 1] + " "
                    + MONTHS[info.month - 1]      + " "
                    + info.day.format("%d");

        var jc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(C_DATE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, sepY + 14, Graphics.FONT_TINY, dateStr, jc);
    }

    // ── Stats row: BAT | STP | BPM ───────────────────────────────────────────

    private function drawStats(dc as Graphics.Dc) as Void {
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

        // Position at lower quarter of screen
        var midY   = mCy + mCy * 55 / 100;
        var labY   = midY;
        var valY   = midY + 18;
        var col1   = mCx - mCx * 55 / 100;
        var col2   = mCx;
        var col3   = mCx + mCx * 55 / 100;

        // Top divider
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(col1 - 5, labY - 14, col3 + 5, labY - 14);

        // Vertical separators between columns
        dc.drawLine(col1 + (col2 - col1) / 2, labY - 10, col1 + (col2 - col1) / 2, valY + 10);
        dc.drawLine(col2 + (col3 - col2) / 2, labY - 10, col2 + (col3 - col2) / 2, valY + 10);

        drawStat(dc, col1, labY, valY, "BAT",
                 battery.format("%d") + "%", C_ACNT, C_VAL);

        drawStat(dc, col2, labY, valY, "STP",
                 steps.format("%d"), C_ACNT, C_VAL);

        var hrStr   = (heartRate > 0) ? heartRate.format("%d") : "--";
        var hrColor = (heartRate > 0) ? C_HR : C_VAL;
        drawStat(dc, col3, labY, valY, "BPM", hrStr, C_ACNT, hrColor);
    }

    private function drawStat(dc       as Graphics.Dc,
                               x        as Number,
                               labY     as Number,
                               valY     as Number,
                               label    as String,
                               value    as String,
                               labColor as Number,
                               valColor as Number) as Void {
        var jc = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(labColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, labY, Graphics.FONT_XTINY, label, jc);
        dc.setColor(valColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, valY, Graphics.FONT_XTINY, value, jc);
    }

    private function normalizeHour(hour as Number) as Number {
        if (System.getDeviceSettings().is24Hour) { return hour; }
        if (hour == 0)  { return 12; }
        if (hour > 12)  { return hour - 12; }
        return hour;
    }
}
