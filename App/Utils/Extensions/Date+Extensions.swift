import Foundation

extension Date {
    init?(isoDate: String) {
        self.init(isoDate, format: "yyyy-MM-dd")
    }

    init?(isoDateTime: String) {
        let dateFormatter = ISO8601DateFormatter.psaThreadSpecific
        dateFormatter.formatOptions = [.withInternetDateTime]
        guard let date = dateFormatter.date(from: isoDateTime) else {
            return nil
        }
        self = date
    }

    func toISOString(_ timeZone: TimeZone? = nil) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let timeZone = timeZone {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: self) // 2022-10-02T03:04:05
    }

    func toISODate(_ timeZone: TimeZone? = nil) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let timeZone = timeZone {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: self) // 2022-10-02
    }
}
