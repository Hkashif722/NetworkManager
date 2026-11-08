# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-11-14

### Added
- Initial release of NetworkService
- URLSession-based networking layer with async/await support
- Generic type-safe API for making HTTP requests
- Middleware system for request/response processing
- Response validation system with chainable validators
- Built-in validators:
  - StatusCodeValidator - validates HTTP status codes
  - EmptyResponseValidator - checks for empty responses
  - ContentTypeValidator - validates content-type headers
  - CustomResponseValidator - custom validation logic
- Built-in middleware:
  - LoggingMiddleware - request/response logging
  - AuthenticationMiddleware - automatic token injection
  - RateLimitMiddleware - 429 response handling
- Comprehensive error handling with APIError enum
- Support for all HTTP methods (GET, POST, PUT, DELETE, PATCH)
- Customizable JSON encoder/decoder
- Timeout configuration
- EndpointModel protocol for defining API endpoints
- Full unit test coverage
- Comprehensive documentation and examples

### Supported Platforms
- iOS 15.0+
- macOS 12.0+
- tvOS 15.0+
- watchOS 8.0+

## [Unreleased]

### Planned Features
- Upload/Download progress tracking
- Background session support
- Certificate pinning
- Request retry logic with exponential backoff
- Cache policy configuration
- Request cancellation
- Mock response support for testing
- Combine publishers support
