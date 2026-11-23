import Foundation

enum AppError: LocalizedError {
    case unauthenticated
    case unauthorized
    case invalidResponse
    case network(Error)
    case database(String)
    case validation(String)
    case configuration(String)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            "Please sign in to continue."
        case .unauthorized:
            "You do not have permission to perform this action."
        case .invalidResponse:
            "The service returned an invalid response."
        case .network:
            "We could not connect. Check your connection and try again."
        case .database:
            "The requested information is temporarily unavailable."
        case .validation(let message), .configuration(let message):
            message
        }
    }
}
