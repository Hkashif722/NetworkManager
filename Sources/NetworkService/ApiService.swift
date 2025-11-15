import Foundation

/// Main networking service class
public class ApiService {
    
    /// Shared singleton instance
    public static let shared = ApiService()
    
    private let session: URLSession
    private(set) var decoder: JSONDecoder
    private(set) var encoder: JSONEncoder
    
    // Middleware and validators
    private var middlewares: [NetworkMiddleware] = []
    private var validators: [ResponseValidator] = []
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        // Setup default middleware and validators
        setupDefaultMiddleware()
    }
    
    private func setupDefaultMiddleware() {
        // Add default validators
        validators = [
            StatusCodeValidator(),
            EmptyResponseValidator(),
            ContentTypeValidator()
        ]
        
        // Add default middleware
        #if DEBUG
        middlewares.append(LoggingMiddleware(logLevel: .detailed))
        #endif
        
        middlewares.append(RateLimitMiddleware())
    }
    
    // MARK: - Configuration Methods
    
    /// Add custom middleware to the service
    /// - Parameter middleware: The middleware to add
    public func addMiddleware(_ middleware: NetworkMiddleware) {
        middlewares.append(middleware)
    }
    
    /// Add custom validator to the service
    /// - Parameter validator: The validator to add
    public func addValidator(_ validator: ResponseValidator) {
        validators.append(validator)
    }
    
    /// Clear all middleware
    public func clearMiddleware() {
        middlewares.removeAll()
    }
    
    /// Clear all validators
    public func clearValidators() {
        validators.removeAll()
    }
    
    /// Set custom validators, replacing all existing ones
    /// - Parameter validators: Array of validators
    public func setCustomValidators(_ validators: [ResponseValidator]) {
        self.validators = validators
    }
    
    /// Set authentication token provider
    /// - Parameter tokenProvider: Closure that returns the auth token
    public func setAuthToken(_ tokenProvider: @escaping () -> String?) {
        middlewares.append(AuthenticationMiddleware(tokenProvider: tokenProvider))
    }
    
    /// Configure custom JSON decoder
    /// - Parameter decoder: Custom JSONDecoder
    public func setDecoder(_ decoder: JSONDecoder) {
        self.decoder = decoder
    }
    
    /// Configure custom JSON encoder
    /// - Parameter encoder: Custom JSONEncoder
    public func setEncoder(_ encoder: JSONEncoder) {
        self.encoder = encoder
    }
    
    // MARK: - Request Methods
    
    /// Perform a POST request
    /// - Parameters:
    ///   - type: Response type conforming to Decodable
    ///   - model: Endpoint model defining the request
    ///   - payload: Request payload conforming to Encodable
    /// - Returns: Decoded response of type T
    /// - Throws: APIError if the request fails
    public func requestPostHeader<T: Decodable, E: EndpointModel, P: Encodable>(
        type: T.Type,
        model: E,
        payload: P
    ) async throws -> T {
        return try await request(
            type: type,
            model: model,
            payload: payload,
            method: .post
        )
    }
    
    /// Perform a GET request
    /// - Parameters:
    ///   - type: Response type conforming to Decodable
    ///   - model: Endpoint model defining the request
    /// - Returns: Decoded response of type T
    /// - Throws: APIError if the request fails
    public func requestGetHeader<T: Decodable, E: EndpointModel>(
        type: T.Type,
        model: E
    ) async throws -> T {
        return try await request(
            type: type,
            model: model,
            payload: EmptyPayload?.none,
            method: .get
        )
    }
    
    /// Perform a PUT request
    /// - Parameters:
    ///   - type: Response type conforming to Decodable
    ///   - model: Endpoint model defining the request
    ///   - payload: Request payload conforming to Encodable
    /// - Returns: Decoded response of type T
    /// - Throws: APIError if the request fails
    public func requestPutHeader<T: Decodable, E: EndpointModel, P: Encodable>(
        type: T.Type,
        model: E,
        payload: P
    ) async throws -> T {
        return try await request(
            type: type,
            model: model,
            payload: payload,
            method: .put
        )
    }
    
    /// Perform a DELETE request
    /// - Parameters:
    ///   - type: Response type conforming to Decodable
    ///   - model: Endpoint model defining the request
    /// - Returns: Decoded response of type T
    /// - Throws: APIError if the request fails
    public func requestDeleteHeader<T: Decodable, E: EndpointModel>(
        type: T.Type,
        model: E
    ) async throws -> T {
        return try await request(
            type: type,
            model: model,
            payload: EmptyPayload?.none,
            method: .delete
        )
    }
    
    /// Perform a PATCH request
    /// - Parameters:
    ///   - type: Response type conforming to Decodable
    ///   - model: Endpoint model defining the request
    ///   - payload: Request payload conforming to Encodable
    /// - Returns: Decoded response of type T
    /// - Throws: APIError if the request fails
    public func requestPatchHeader<T: Decodable, E: EndpointModel, P: Encodable>(
        type: T.Type,
        model: E,
        payload: P
    ) async throws -> T {
        return try await request(
            type: type,
            model: model,
            payload: payload,
            method: .patch
        )
    }
    
    // MARK: - Generic Request Method
    
    private func request<T: Decodable, E: EndpointModel, P: Encodable>(
        type: T.Type,
        model: E,
        payload: P?,
        method: HTTPMethod
    ) async throws -> T {
        
        // Construct URL
        guard let url = URL(string: model.baseURL + model.path) else {
            throw APIError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        model.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add payload for POST/PUT/PATCH
        if let payload = payload, method != .get && method != .delete {
            do {
                request.httpBody = try encoder.encode(payload)
            } catch {
                throw APIError.decodingError(error)
            }
        }
        
        // Apply middleware to prepare request
        for middleware in middlewares {
            request = try middleware.prepare(request: request)
        }
        
        // Perform request
        do {
            let (data, response) = try await session.data(for: request)
            
            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            // Process response through middleware
            var processedData = data
            for middleware in middlewares {
                processedData = try middleware.process(data: processedData, response: httpResponse)
            }
            
            // Run validators
            for validator in validators {
                processedData = try validator.validate(data: processedData, response: httpResponse)
            }
            
            // Decode response
            do {
                let decodedResponse = try decoder.decode(T.self, from: processedData)
                return decodedResponse
            } catch {
                throw APIError.decodingError(error)
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}

// MARK: - Empty Payload Helper
private struct EmptyPayload: Encodable {}
