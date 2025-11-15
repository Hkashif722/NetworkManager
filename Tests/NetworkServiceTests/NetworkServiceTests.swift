import XCTest
@testable import NetworkService

final class NetworkServiceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset service for each test
        ApiService.shared.clearMiddleware()
        ApiService.shared.clearValidators()
    }
    
    func testAPIEndpointCreation() {
        let endpoint = APIEndpoint(
            path: "/users",
            method: .get,
            baseURL: "https://api.example.com"
        )
        
        XCTAssertEqual(endpoint.path, "/users")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.baseURL, "https://api.example.com")
    }
    
    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
    }
    
    func testAPIErrorDescriptions() {
        let invalidURLError = APIError.invalidURL
        XCTAssertEqual(invalidURLError.localizedDescription, "Invalid URL")
        
        let noDataError = APIError.noData
        XCTAssertEqual(noDataError.localizedDescription, "No data received")
        
        let serverError = APIError.serverError(statusCode: 404, message: "Not Found")
        XCTAssertTrue(serverError.localizedDescription.contains("404"))
    }
    
    func testStatusCodeValidator() {
        let validator = StatusCodeValidator()
        let validData = Data()
        
        // Create mock response with 200 status
        let url = URL(string: "https://api.example.com")!
        let response200 = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        do {
            let result = try validator.validate(data: validData, response: response200)
            XCTAssertEqual(result, validData)
        } catch {
            XCTFail("Should not throw error for 200 status code")
        }
        
        // Test with 404 status
        let response404 = HTTPURLResponse(
            url: url,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!
        
        XCTAssertThrowsError(try validator.validate(data: validData, response: response404)) { error in
            if case APIError.serverError(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Expected serverError")
            }
        }
    }
    
    func testEmptyResponseValidator() {
        let validator = EmptyResponseValidator()
        let url = URL(string: "https://api.example.com")!
        
        // Test with 204 status and empty data (should pass)
        let response204 = HTTPURLResponse(
            url: url,
            statusCode: 204,
            httpVersion: nil,
            headerFields: nil
        )!
        
        do {
            _ = try validator.validate(data: Data(), response: response204)
        } catch {
            XCTFail("Should not throw error for 204 with empty data")
        }
        
        // Test with 200 status and empty data (should fail)
        let response200 = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        XCTAssertThrowsError(try validator.validate(data: Data(), response: response200))
    }
    
    func testContentTypeValidator() {
        let validator = ContentTypeValidator(expectedContentType: "application/json")
        let data = Data()
        let url = URL(string: "https://api.example.com")!
        
        // Test with correct content type
        let responseWithJSON = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        do {
            _ = try validator.validate(data: data, response: responseWithJSON)
        } catch {
            XCTFail("Should not throw error for correct content type")
        }
        
        // Test with incorrect content type
        let responseWithHTML = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/html"]
        )!
        
        XCTAssertThrowsError(try validator.validate(data: data, response: responseWithHTML))
    }
    
    func testLoggingMiddleware() {
        let middleware = LoggingMiddleware(logLevel: .basic)
        let url = URL(string: "https://api.example.com")!
        let request = URLRequest(url: url)
        
        // Test prepare
        do {
            let preparedRequest = try middleware.prepare(request: request)
            XCTAssertEqual(preparedRequest.url, url)
        } catch {
            XCTFail("Should not throw error")
        }
        
        // Test process
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let data = Data()
        
        do {
            let processedData = try middleware.process(data: data, response: response)
            XCTAssertEqual(processedData, data)
        } catch {
            XCTFail("Should not throw error")
        }
    }
    
    func testAuthenticationMiddleware() {
        let token = "test-token-123"
        let middleware = AuthenticationMiddleware {
            return token
        }
        
        let url = URL(string: "https://api.example.com")!
        var request = URLRequest(url: url)
        
        do {
            request = try middleware.prepare(request: request)
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            XCTAssertEqual(authHeader, "Bearer \(token)")
        } catch {
            XCTFail("Should not throw error")
        }
    }
    
    func testRateLimitMiddleware() {
        let middleware = RateLimitMiddleware()
        let url = URL(string: "https://api.example.com")!
        let data = Data()
        
        // Test with 429 status code
        let response429 = HTTPURLResponse(
            url: url,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )!
        
        XCTAssertThrowsError(try middleware.process(data: data, response: response429)) { error in
            if case APIError.rateLimitExceeded(let retryAfter) = error {
                XCTAssertEqual(retryAfter, "60")
            } else {
                XCTFail("Expected rateLimitExceeded error")
            }
        }
        
        // Test with normal status code
        let response200 = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        do {
            _ = try middleware.process(data: data, response: response200)
        } catch {
            XCTFail("Should not throw error for 200 status code")
        }
    }
}
