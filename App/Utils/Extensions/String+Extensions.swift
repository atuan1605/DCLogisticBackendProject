import Foundation
import PhoneNumberKit

let trackingNumberRegex = "^[a-zA-Z0-9]{8,}$|^(?=.*[a-zA-Z])[a-zA-Z0-9]{7}$|^[a-zA-Z]\\d{5,7}$"

extension String {
    func removingNonAlphaNumericCharacters() -> String {
        return self.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
    }

	func requireValidTrackingNumber() -> String? {
		let trimmed = self.removingNonAlphaNumericCharacters()

		guard trimmed.isValidTrackingNumber() else {
			return trimmed
		}

		return trimmed
	}
    
    func isValidTrackingNumber() -> Bool {
        let regex = try! NSRegularExpression(pattern: trackingNumberRegex)
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }

    func snakeCased() -> String { // firstName -> first_name
        let acronymPattern = "([A-Z]+)([A-Z][a-z]|[0-9])"
        let normalPattern = "([a-z0-9])([A-Z])"
        return self.processCamalCaseRegex(pattern: acronymPattern)?
            .processCamalCaseRegex(pattern: normalPattern)?.lowercased() ?? self.lowercased()
    }

    fileprivate func processCamalCaseRegex(pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: count)
        return regex?.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
    }

    func date(using dateFormatter: DateFormatter) -> Date? {
        let formats = [
            "yyyy-MM-dd",
            "yyyy-MM-dd' 'HH:mm:ss",
            "MM/dd-HH:mm:ss",
            "MM/dd",
            "M/d",
            "MM/dd/yyyy",
            "M/d/yyyy"
        ]
        
        for i in (0..<formats.count) {
            let targetFormat = formats[i]
            dateFormatter.dateFormat = targetFormat

            if let date = dateFormatter.date(from: self) {
                var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                if components.year == 2000 {
                    components.year = Calendar.current.component(.year, from: Date())
                }
                if let validDate = Calendar.current.date(from: components) {
                    return validDate
                }
            }
        }
        return nil
    }
    
    func validPhoneNumber() -> String? {
        let phoneNumberKit = PhoneNumberUtility()
        do {
            let phoneNumber = try phoneNumberKit.parse(self, ignoreType: true)
            let result = phoneNumberKit.format(phoneNumber, toType: .e164)
            return result
        }
        catch {
            return nil
        }
    }
    
    func validEmail() -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let regex = try! NSRegularExpression(pattern: emailRegex)
        return regex.matches(self)
    }
    
    static func randomCode(length: Int = 16) -> String {
        return NanoID(alphabet: .lowercasedLatinLetters, .numbers, .urlSafe, size: length).new()
    }
    
    func normalizeString() -> String {
        return self.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String? {
    func isNilOrEmpty() -> Bool {
        let isNil = self == nil
        let isEmpty = self != nil && self!.isEmpty
        return isNil || isEmpty
    }
}

extension NSRegularExpression {
    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return firstMatch(in: string, options: [], range: range) != nil
    }
}
