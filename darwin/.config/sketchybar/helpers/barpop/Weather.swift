import Foundation
import Observation

struct Forecast: Sendable {
	struct Hour: Sendable {
		let time: Date
		let temp: Double
		let precip: Double
	}

	struct Day: Sendable {
		let date: Date
		let low: Double
		let high: Double
		let precip: Double
		let code: Int
		let sunrise: Date
		let sunset: Date
	}

	let fetched: Date
	let timeZone: TimeZone
	let temp: Double
	let feels: Double
	let humidity: Double
	let dewPoint: Double
	let wind: Double
	let gusts: Double
	let windFrom: Double
	let code: Int
	let isDay: Bool
	let hours: [Hour]
	let days: [Day]
}

// Location from helpers/location.sh (CoreLocationCLI, with its last good fix
// when macOS has none), forecast from Open-Meteo. The last good forecast is kept through
// failures.
@MainActor
@Observable
final class Weather {
	private(set) var forecast: Forecast?
	private(set) var place: String?
	private(set) var failure: String?

	@ObservationIgnored private var coords: (lat: String, lon: String, at: Date)?
	@ObservationIgnored private var loading: Task<Void, Never>?
	@ObservationIgnored private var timer: Timer?

	init() {
		refresh()
		let timer = Timer(timeInterval: 600, repeats: true) { [weak self] _ in
			MainActor.assumeIsolated { self?.refresh() }
		}
		RunLoop.main.add(timer, forMode: .common)
		self.timer = timer
	}

	// Opening the popup refreshes unless the data is under a minute old.
	func refreshIfStale() {
		if let f = forecast, Date().timeIntervalSince(f.fetched) < 60 { return }
		refresh()
	}

	func refresh() {
		guard loading == nil else { return }
		loading = Task {
			defer { loading = nil }
			// A failed fix falls back to the last one.
			if coords == nil || Date().timeIntervalSince(coords!.at) > 1800, let fix = await Self.locate() {
				coords = (fix.lat, fix.lon, Date())
				place = fix.place
			}
			guard let coords else {
				failure = "Your location isn't available."
				return
			}
			guard let f = await Self.fetch(lat: coords.lat, lon: coords.lon) else {
				failure = "Open-Meteo didn't answer."
				return
			}
			forecast = f
			failure = nil
		}
	}

	private nonisolated static func locate() async -> (lat: String, lon: String, place: String?)? {
		let script = NSString(string: "~/.config/sketchybar/helpers/location.sh").expandingTildeInPath
		let out = await Shell.output(script)
		let parts = out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "|", maxSplits: 1)
		let ll = parts.first?.split(separator: ",") ?? []
		guard ll.count == 2, Double(ll[0]) != nil, Double(ll[1]) != nil else { return nil }
		let place = parts.count == 2 && parts[1] != ", " ? String(parts[1]) : nil
		return (String(ll[0]), String(ll[1]), place)
	}

	private nonisolated static func fetch(lat: String, lon: String) async -> Forecast? {
		var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
		url.queryItems = [
			.init(name: "latitude", value: lat), .init(name: "longitude", value: lon),
			.init(
				name: "current",
				value: "temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,weather_code,is_day,"
					+ "wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
			.init(name: "hourly", value: "temperature_2m,precipitation_probability"),
			.init(
				name: "daily",
				value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"),
			.init(name: "temperature_unit", value: "fahrenheit"), .init(name: "wind_speed_unit", value: "mph"),
			.init(name: "timezone", value: "auto"), .init(name: "timeformat", value: "unixtime"),
			.init(name: "forecast_days", value: "5"), .init(name: "forecast_hours", value: "13"),
		]
		var request = URLRequest(url: url.url!)
		request.timeoutInterval = 10
		guard let (data, response) = try? await URLSession.shared.data(for: request),
			(response as? HTTPURLResponse)?.statusCode == 200
		else { return nil }
		return try? JSONDecoder().decode(Response.self, from: data).forecast
	}
}

private struct Response: Decodable {
	struct Current: Decodable {
		let temperature2m: Double
		let apparentTemperature: Double
		let relativeHumidity2m: Double
		let dewPoint2m: Double
		let weatherCode: Int
		let isDay: Int
		let windSpeed10m: Double
		let windDirection10m: Double
		let windGusts10m: Double

		enum CodingKeys: String, CodingKey {
			case temperature2m = "temperature_2m", apparentTemperature = "apparent_temperature"
			case relativeHumidity2m = "relative_humidity_2m", dewPoint2m = "dew_point_2m"
			case weatherCode = "weather_code", isDay = "is_day", windSpeed10m = "wind_speed_10m"
			case windDirection10m = "wind_direction_10m", windGusts10m = "wind_gusts_10m"
		}
	}

	struct Hourly: Decodable {
		let time: [TimeInterval]
		let temperature2m: [Double?]
		let precipitationProbability: [Double?]

		enum CodingKeys: String, CodingKey {
			case time, temperature2m = "temperature_2m", precipitationProbability = "precipitation_probability"
		}
	}

	struct Daily: Decodable {
		let time: [TimeInterval]
		let weatherCode: [Int?]
		let temperature2mMax: [Double?]
		let temperature2mMin: [Double?]
		let precipitationProbabilityMax: [Double?]
		let sunrise: [TimeInterval]
		let sunset: [TimeInterval]

		enum CodingKeys: String, CodingKey {
			case time, sunrise, sunset, weatherCode = "weather_code", temperature2mMax = "temperature_2m_max"
			case temperature2mMin = "temperature_2m_min", precipitationProbabilityMax = "precipitation_probability_max"
		}
	}

	let utcOffsetSeconds: Int
	let current: Current
	let hourly: Hourly
	let daily: Daily

	enum CodingKeys: String, CodingKey {
		case current, hourly, daily, utcOffsetSeconds = "utc_offset_seconds"
	}

	var forecast: Forecast {
		let c = current
		let hours = hourly.time.indices.compactMap { i -> Forecast.Hour? in
			guard let t = hourly.temperature2m[i] else { return nil }
			return .init(time: Date(timeIntervalSince1970: hourly.time[i]), temp: t, precip: hourly.precipitationProbability[i] ?? 0)
		}
		let days = daily.time.indices.compactMap { i -> Forecast.Day? in
			guard let lo = daily.temperature2mMin[i], let hi = daily.temperature2mMax[i] else { return nil }
			return .init(
				date: Date(timeIntervalSince1970: daily.time[i]), low: lo, high: hi,
				precip: daily.precipitationProbabilityMax[i] ?? 0, code: daily.weatherCode[i] ?? 0,
				sunrise: Date(timeIntervalSince1970: daily.sunrise[i]), sunset: Date(timeIntervalSince1970: daily.sunset[i]))
		}
		return Forecast(
			fetched: Date(), timeZone: TimeZone(secondsFromGMT: utcOffsetSeconds) ?? .current, temp: c.temperature2m,
			feels: c.apparentTemperature, humidity: c.relativeHumidity2m, dewPoint: c.dewPoint2m, wind: c.windSpeed10m,
			gusts: c.windGusts10m, windFrom: c.windDirection10m, code: c.weatherCode, isDay: c.isDay != 0, hours: hours,
			days: days)
	}
}

// WMO weather interpretation codes, as Open-Meteo reports them.
struct Condition {
	let name: String
	let sky: SkyCondition
	let symbol: String

	init(code: Int) {
		switch code {
		case 0: (name, sky, symbol) = ("Clear", .clear, "sun.max")
		case 1: (name, sky, symbol) = ("Mostly clear", .partlyCloudy, "sun.max")
		case 2: (name, sky, symbol) = ("Partly cloudy", .partlyCloudy, "cloud.sun")
		case 3: (name, sky, symbol) = ("Cloudy", .cloudy, "cloud")
		case 45, 48: (name, sky, symbol) = ("Fog", .cloudy, "cloud.fog")
		case 51...57: (name, sky, symbol) = ("Drizzle", .rain, "cloud.drizzle")
		case 61...67: (name, sky, symbol) = ("Rain", .rain, "cloud.rain")
		case 71...77, 85, 86: (name, sky, symbol) = ("Snow", .snow, "cloud.snow")
		case 80...82: (name, sky, symbol) = ("Showers", .rain, "cloud.sun.rain")
		case 95...99: (name, sky, symbol) = ("Thunderstorms", .storm, "cloud.bolt.rain")
		default: (name, sky, symbol) = ("Unknown", .cloudy, "cloud")
		}
	}
}
