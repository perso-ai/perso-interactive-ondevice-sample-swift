//
//  Copyright © 2025 ESTsoft. All rights reserved.
//

import Foundation

import PersoInteractiveOnDeviceSDK

// MARK: - GetWeatherForecastTool

struct WeatherTool: ChatTool {
    let name: String = "get_current_weather"

    let description: String? = "Get current weather information for a specific location"

    let parameters: JSONSchema? = .object(
        properties: [
            "location": .string(description: "City and country (e.g., 'Seoul, Korea')")
        ],
        required: ["location"]
    )

    let call: @Sendable ([String : String]?) async throws -> String = { arguments in
        guard let location = arguments?["location"] else {
            throw NSError(domain: "missingArgument", code: -1)
        }
        // Your weather API call here
        return "Current weather in \(location): \(Int.random(in: 0...100))°C"
    }
}
