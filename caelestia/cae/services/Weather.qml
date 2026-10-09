pragma Singleton

import QtQuick
import Quickshell
import Caelestia.I18n
import "../utils"
import shell.services as R

// Adapter: Caelestia's Weather interface over Ryoku's weather daemon, which
// already fetches Open-Meteo for the location set in Ryoku. The daemon's
// readings are in the user's units, so formatTemp only rounds and suffixes.
Singleton {
    id: root

    readonly property var src: R.Weather.current
    readonly property string city: R.Weather.city || R.Weather.location
    readonly property var cc: src ? {
        weatherCode: String(src.code),
        tempC: src.temp,
        feelsLikeC: src.feels,
        humidity: src.humidity,
        windSpeed: src.windValue,
        isDay: src.isDay ? 1 : 0
    } : null
    readonly property string unit: src && String(src.temperature).indexOf("F") >= 0 ? "F" : "C"

    readonly property list<var> forecast: {
        const today = new Date();
        return R.Weather.daily.map((d, i) => {
            const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i);
            return {
                date: Qt.formatDate(date, "yyyy/MM/dd"),
                maxTempC: d.hi,
                minTempC: d.lo,
                weatherCode: String(d.code),
                icon: Icons.getWeatherIcon(String(d.code))
            };
        });
    }
    readonly property list<var> hourlyForecast: R.Weather.hourly.map(h => ({
                hour: Number(h.hour),
                tempC: h.temp,
                precipChance: h.precip,
                weatherCode: String(h.code),
                icon: Icons.getWeatherIcon(String(h.code))
            }))

    readonly property string icon: cc ? Icons.getWeatherIcon(cc.weatherCode) : "cloud_alert"
    readonly property string description: cc ? getWeatherCondition(cc.weatherCode) : Tr.tr("No weather")
    readonly property string temp: formatTemp(cc?.tempC)
    readonly property string feelsLike: formatTemp(cc?.feelsLikeC)
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    // Ryoku gives "HH:mm"; format it like Caelestia does, following its 12/24-hour setting.
    readonly property string sunrise: formatClock(src?.sunrise)
    readonly property string sunset: formatClock(src?.sunset)

    function formatClock(hhmm: var): string {
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(hhmm ?? ""));
        if (!m)
            return "--:--";
        const t = new Date();
        t.setHours(Number(m[1]), Number(m[2]), 0, 0);
        return Qt.formatDateTime(t, Units.twelveHourClock ? "h:mm A" : "h:mm");
    }

    function formatTemp(temp: var, compact = false): string {
        if (temp === undefined || temp === null)
            return "--";
        return `${Math.round(temp)}°${compact ? "" : root.unit}`;
    }

    // Caelestia's cards call this each time they appear; Ryoku's daemon keeps
    // the data fresh on its own schedule, so there is nothing to refetch.
    function reload(): void {
    }

    function getWeatherCondition(code: string): string {
        const conditions = {
            "0": Tr.tr("Clear"),
            "1": Tr.tr("Clear"),
            "2": Tr.tr("Partly cloudy"),
            "3": Tr.tr("Overcast"),
            "45": Tr.tr("Fog"),
            "48": Tr.tr("Fog"),
            "51": Tr.tr("Drizzle"),
            "53": Tr.tr("Drizzle"),
            "55": Tr.tr("Drizzle"),
            "56": Tr.tr("Freezing drizzle"),
            "57": Tr.tr("Freezing drizzle"),
            "61": Tr.tr("Light rain"),
            "63": Tr.tr("Rain"),
            "65": Tr.tr("Heavy rain"),
            "66": Tr.tr("Light rain"),
            "67": Tr.tr("Heavy rain"),
            "71": Tr.tr("Light snow"),
            "73": Tr.tr("Snow"),
            "75": Tr.tr("Heavy snow"),
            "77": Tr.tr("Snow"),
            "80": Tr.tr("Light rain"),
            "81": Tr.tr("Rain"),
            "82": Tr.tr("Heavy rain"),
            "85": Tr.tr("Light snow showers"),
            "86": Tr.tr("Heavy snow showers"),
            "95": Tr.tr("Thunderstorm"),
            "96": Tr.tr("Thunderstorm with hail"),
            "99": Tr.tr("Thunderstorm with hail")
        };
        return conditions[code] || Tr.trCtx("Unknown", "weather condition");
    }
}
