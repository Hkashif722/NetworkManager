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
        return try await request(type: type, model: model, payload: payload, method: .post)
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
        return try await request(type: type, model: model, payload: EmptyPayload?.none, method: .get)
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
        return try await request(type: type, model: model, payload: payload, method: .put)
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
        return try await request(type: type, model: model, payload: EmptyPayload?.none, method: .delete)
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
        return try await request(type: type, model: model, payload: payload, method: .patch)
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
            
            for validator in effectiveValidators(for: model) {
                processedData = try validator.validate(data: processedData, response: httpResponse)
            }
            
            // Handle empty response body
            if processedData.isEmpty {
                if let empty = EmptyResponse() as? T {
                    return empty
                }
                throw APIError.noData
            }

            // Decode response
            do {
                return try decoder.decode(T.self, from: processedData)
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

// MARK: - File Upload
extension ApiService {
    // MARK: - File Upload Methods with Detailed Progress

    /// Upload a single file with detailed progress tracking
    /// - Parameters:
    ///   - type: Response type conforming to Decodable
    ///   - model: Endpoint model defining the request
    ///   - fileURL: URL of the file to upload (optional)
    ///   - fileName: Form field name for the file (default: "file")
    ///   - parameters: Additional form parameters
    /// - Returns: AsyncThrowingStream emitting progress and response
    public func uploadFile<T: Decodable, E: EndpointModel>(
        type: T.Type,
        model: E,
        fileURL: URL?,
        fileName: String = "file",
        parameters: [String: String]? = nil
    ) -> AsyncThrowingStream<UploadEvent<T>, Error> {
        
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Construct URL
                    guard let url = URL(string: model.baseURL + model.path) else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }
                    
                    #if DEBUG
                    print("📤 Upload URL: \(url.absoluteString)")
                    #endif
                    
                    // Create boundary for multipart form data
                    let boundary = "Boundary-\(UUID().uuidString)"
                    
                    // Create request
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    
                    // Add custom headers from model
                    model.headers?.forEach { key, value in
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                    
                    #if DEBUG
                    print("📤 Upload Headers: \(model.headers ?? [:])")
                    #endif
                    
                    // Build multipart form data
                    var body = Data()
                    
                    // Add file if provided
                    if let fileURL = fileURL {
                        do {
                            let fileData = try Data(contentsOf: fileURL)
                            let mimeType = NetworkHelperMethods.mimeType(for: fileURL.pathExtension)
                            
                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"\(fileName)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
                            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                            body.append(fileData)
                            body.append("\r\n".data(using: .utf8)!)
                            
                            // Auto-inject FileType field
                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"FileType\"\r\n\r\n".data(using: .utf8)!)
                            body.append("\(mimeType)\r\n".data(using: .utf8)!)

                            
                            #if DEBUG
                            print("📤 File: \(fileURL.lastPathComponent) (\(fileData.count) bytes, \(mimeType))")
                            #endif
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    
                    // Add parameters
                    parameters?.forEach { key, value in
                        body.append("--\(boundary)\r\n".data(using: .utf8)!)
                        body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                        body.append("\(value)\r\n".data(using: .utf8)!)
                    }
                    
                    // Close boundary
                    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                    
                    // Apply middleware to prepare request
                    for middleware in middlewares {
                        request = try middleware.prepare(request: request)
                    }
                    
                    // Create delegate
                    let delegate = UploadDelegate<T>(
                        continuation: continuation,
                        decoder: decoder,
                        middlewares: middlewares,
                        validators: effectiveValidators(for: model)
                    )
                    
                    // Create custom session with delegate for progress tracking
                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 300 // 5 minutes for large files
                    config.timeoutIntervalForResource = 600 // 10 minutes
                    
                    let uploadSession = URLSession(
                        configuration: config,
                        delegate: delegate,
                        delegateQueue: nil
                    )
                    
                    // Create and start upload task
                    let task = uploadSession.uploadTask(with: request, from: body)
                    delegate.task = task
                    task.resume()
                    
                    #if DEBUG
                    print("📤 Upload task started")
                    #endif
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Upload multiple files with detailed progress tracking
    /// - Parameters:
    ///   - type: Response type conforming to Decodable
    ///   - model: Endpoint model defining the request
    ///   - fileURLs: Array of file URLs to upload
    ///   - fileName: Base form field name for files
    ///   - parameters: Additional form parameters
    /// - Returns: AsyncThrowingStream emitting progress and response
    public func uploadMultipleFiles<T: Decodable, E: EndpointModel>(
        type: T.Type,
        model: E,
        fileURLs: [URL],
        fileName: String = "file",
        parameters: [String: String]? = nil
    ) -> AsyncThrowingStream<UploadEvent<T>, Error> {
        
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Construct URL
                    guard let url = URL(string: model.baseURL + model.path) else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }
                    
                    #if DEBUG
                    print("📤 Multiple Upload URL: \(url.absoluteString)")
                    print("📤 Files count: \(fileURLs.count)")
                    #endif
                    
                    // Create boundary for multipart form data
                    let boundary = "Boundary-\(UUID().uuidString)"
                    
                    // Create request
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    
                    // Add custom headers from model
                    model.headers?.forEach { key, value in
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                    
                    // Build multipart form data
                    var body = Data()
                    var totalFileSize: Int64 = 0
                    
                    // Add files
                    for (index, fileURL) in fileURLs.enumerated() {
                        do {
                            let fileData = try Data(contentsOf: fileURL)
                            totalFileSize += Int64(fileData.count)
                            let mimeType = fileURL.pathExtension.mimeType  // ✅ updated
                            
                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"\(fileName)\(index)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
                            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                            body.append(fileData)
                            body.append("\r\n".data(using: .utf8)!)
                            
                            // Auto-inject FileType field
                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"FileType\"\r\n\r\n".data(using: .utf8)!)
                            body.append("\(mimeType)\r\n".data(using: .utf8)!)
                            
                            #if DEBUG
                            print("📤 File \(index + 1): \(fileURL.lastPathComponent) (\(fileData.count) bytes)")
                            #endif
                        } catch {
                            #if DEBUG
                            print("⚠️ Error reading file at \(fileURL): \(error)")
                            #endif
                            continue
                        }
                    }
                    
                    #if DEBUG
                    print("📤 Total file size: \(totalFileSize) bytes")
                    #endif
                    
                    // Add parameters
                    parameters?.forEach { key, value in
                        body.append("--\(boundary)\r\n".data(using: .utf8)!)
                        body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                        body.append("\(value)\r\n".data(using: .utf8)!)
                    }
                    
                    // Close boundary
                    body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                    
                    // Apply middleware to prepare request
                    for middleware in middlewares {
                        request = try middleware.prepare(request: request)
                    }
                    
                    // Create delegate
                    let delegate = UploadDelegate<T>(
                        continuation: continuation,
                        decoder: decoder,
                        middlewares: middlewares,
                        validators: effectiveValidators(for: model)
                    )
                    
                    // Create custom session with delegate for progress tracking
                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 300 // 5 minutes
                    config.timeoutIntervalForResource = 600 // 10 minutes
                    
                    let uploadSession = URLSession(
                        configuration: config,
                        delegate: delegate,
                        delegateQueue: nil
                    )
                    
                    // Create and start upload task
                    let task = uploadSession.uploadTask(with: request, from: body)
                    delegate.task = task
                    task.resume()
                    
                    #if DEBUG
                    print("📤 Multiple upload task started")
                    #endif
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func uploadMultipleFiles<T: Decodable, E: EndpointModel, P: Encodable>(
        type: T.Type,
        model: E,
        fileURLs: [URL],
        fileName: String = "file",
        parameters: P? = nil
    ) -> AsyncThrowingStream<UploadEvent<T>, Error> {

        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: model.baseURL + model.path) else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }

                    #if DEBUG
                    print("📤 Multiple Upload URL: \(url.absoluteString)")
                    print("📤 Files count: \(fileURLs.count)")
                    #endif

                    let boundary = "Boundary-\(UUID().uuidString)"

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

                    model.headers?.forEach { key, value in
                        request.setValue(value, forHTTPHeaderField: key)
                    }

                    var body = Data()
                    var totalFileSize: Int64 = 0

                    // Add files
                    for (index, fileURL) in fileURLs.enumerated() {
                        do {
                            let fileData = try Data(contentsOf: fileURL)
                            totalFileSize += Int64(fileData.count)
                            let mimeType = fileURL.pathExtension.mimeType  // ✅ updated

                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"\(fileName)\(index)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
                            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                            body.append(fileData)
                            body.append("\r\n".data(using: .utf8)!)
                            
                            // Auto-inject FileType field
                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"FileType\"\r\n\r\n".data(using: .utf8)!)
                            body.append("\(mimeType)\r\n".data(using: .utf8)!)

                            #if DEBUG
                            print("📤 File \(index + 1): \(fileURL.lastPathComponent) (\(fileData.count) bytes)")
                            #endif
                        } catch {
                            #if DEBUG
                            print("⚠️ Error reading file at \(fileURL): \(error)")
                            #endif
                            continue
                        }
                    }

                    #if DEBUG
                    print("📤 Total file size: \(totalFileSize) bytes")
                    #endif

                    // Encode Encodable parameters into flat multipart fields
                    if let parameters {
                        let encoded = try JSONEncoder().encode(parameters)

                        guard let dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
                            throw APIError.encodingFailed
                        }

                        for (key, value) in dict {
                            body.append("--\(boundary)\r\n".data(using: .utf8)!)
                            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                            body.append("\(value)\r\n".data(using: .utf8)!)
                        }

                        #if DEBUG
                        print("📤 Parameters encoded from \(P.self): \(dict.keys.joined(separator: ", "))")
                        #endif
                    }

                    // Close boundary
                    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

                    for middleware in middlewares {
                        request = try middleware.prepare(request: request)
                    }

                    let delegate = UploadDelegate<T>(
                        continuation: continuation,
                        decoder: decoder,
                        middlewares: middlewares,
                        validators: effectiveValidators(for: model)
                    )

                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 300
                    config.timeoutIntervalForResource = 600

                    let uploadSession = URLSession(
                        configuration: config,
                        delegate: delegate,
                        delegateQueue: nil
                    )

                    let task = uploadSession.uploadTask(with: request, from: body)
                    delegate.task = task
                    task.resume()

                    #if DEBUG
                    print("📤 Multiple upload task started")
                    #endif

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

//MARK: API calls with custom token
public extension ApiService {
    func postRequestAsyncWithCustomToken<T: Decodable, E: EndpointModel, P: Encodable>(
        _ request: E,
        payload: P,
        responseType: T.Type,
        token: String,
        baseURL: String? = nil,
        timeoutInterval: TimeInterval = 60
    ) async throws -> T {
        // MARK: URL
        guard let url = URL(string: (baseURL ?? request.baseURL) + request.path) else {
            throw APIError.invalidURL
        }

        // MARK: URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeoutInterval
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        request.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // MARK: Body
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        // MARK: Network Call
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            #if DEBUG
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 Raw JSON [\(httpResponse.statusCode)] \(httpResponse.url?.absoluteString ?? ""):\n\(jsonString)")
            }
            #endif

            var processedData = data
            for validator in effectiveValidators(for: request) {
                processedData = try validator.validate(data: processedData, response: httpResponse)
            }

            // Handle empty response body
            if processedData.isEmpty {
                if let empty = EmptyResponse() as? T {
                    return empty
                }
                throw APIError.noData
            }

            // Decode response
            do {
                return try JSONDecoder().decode(T.self, from: processedData)
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

// MARK: - Download File

public extension ApiService {
    
    func downloadFile<T: Decodable, E: EndpointModel>(
        type: T.Type,
        model: E,
        destinationFileName: String? = nil
    ) -> AsyncThrowingStream<DownloadEvent<T>, Error> {
        downloadFile(
            type: type,
            model: model,
            destinationFileName: destinationFileName,
            parameters: Optional<String>.none
        )
    }
    
    func downloadFile<T: Decodable, E: EndpointModel, P: Encodable>(
        type: T.Type,
        model: E,
        destinationFileName: String? = nil,
        parameters: P? = nil
    ) -> AsyncThrowingStream<DownloadEvent<T>, Error> {
        
        var delegateRef: DownloadDelegate<T>?
        
        return AsyncThrowingStream { continuation in
            
            // ✅ Model-aware validators
            let delegate = DownloadDelegate<T>(
                continuation: continuation,
                decoder: decoder,
                middlewares: middlewares,
                validators: effectiveValidators(for: model),
                destinationFileName: destinationFileName
            )
            delegateRef = delegate
            
            Task {
                do {
                    guard let url = URL(string: model.baseURL + model.path) else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }
                    
                    #if DEBUG
                    print("📥 Download URL: \(url.absoluteString)")
                    #endif
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = model.method.rawValue
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    model.headers?.forEach { key, value in
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                    
                    if let parameters {
                        request.httpBody = try encoder.encode(parameters)
                    }
                    
                    for middleware in middlewares {
                        request = try middleware.prepare(request: request)
                    }
                    
                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 300
                    config.timeoutIntervalForResource = 600
                    
                    let downloadSession = URLSession(
                        configuration: config,
                        delegate: delegate,
                        delegateQueue: nil
                    )
                    
                    delegate.session = downloadSession
                    
                    let task = downloadSession.downloadTask(with: request)
                    delegate.task = task
                    task.resume()
                    
                    #if DEBUG
                    print("📥 Download task started")
                    #endif
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { _ in
                delegateRef?.task?.cancel()
                delegateRef = nil
            }
        }
    }
}

// MARK: - Helpers
private extension ApiService {
    /// Builds model-aware validators — ContentTypeValidator uses the
    /// endpoint's declared expectedContentTypes instead of the global default.
    func effectiveValidators<E: EndpointModel>(for model: E) -> [ResponseValidator] {
        validators.map { validator in
            if validator is ContentTypeValidator {
                return ContentTypeValidator(expectedContentTypes: model.expectedContentTypes)
            }
            return validator
        }
    }
}
