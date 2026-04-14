![Ping Identity](https://www.pingidentity.com/content/dam/picr/nav/Ping-Logo-2.svg)

# Ping SDK – Network Module

[![Swift Version](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

## Overview

PingNetwork provides a protocol-based HTTP client abstraction for the Ping iOS SDK. It offers a Swift-idiomatic interface for making HTTP requests with support for async/await, request/response interceptors, and automatic injection of standard headers.

The module is built on Apple's native URLSession framework, ensuring zero external dependencies while providing excellent performance and seamless integration with iOS.

## Key Features

- **Protocol-Based Design**: Flexible abstractions enable easy testing and custom implementations
- **Swift Concurrency**: Native async/await support for all network operations
- **Request/Response Interceptors**: Add cross-cutting concerns like authentication, logging, and error handling
- **Standard Headers**: Automatically injects platform identification headers (`x-requested-with`, `x-requested-platform`)
- **Builder Pattern**: Fluent API for constructing HTTP requests
- **Type-Safe Methods**: Enum-based HTTP methods (GET, POST, PUT, DELETE, etc.)
- **Cookie Management**: Built-in cookie handling via URLSession
- **Redirect Prevention**: Automatic prevention of HTTP redirects for security
- **Thread-Safe**: Full `Sendable` conformance for Swift 6+ concurrency
- **Zero Dependencies**: Uses only native iOS frameworks

## Integrating the SDK into your project

Use Cocoapods or Swift Package Manager

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ForgeRock/ping-ios-sdk.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "PingNetwork", package: "ping-ios-sdk")
        ]
    )
]
```

### CocoaPods

```ruby
pod 'PingNetwork'
```

## How to Use the SDK

### Basic HTTP Request

Make a simple GET request:

```swift
import PingNetwork

let client = HttpClient.createClient()

let response = try await client.request { request in request in
    request.url = "https://api.example.com/users"
    request.get()
}

```

### POST Request with JSON Body

Send a POST request with a JSON body:

```swift
let response = try await client.request { request in request in
    request.url = "https://api.example.com/users"
    request.setHeader(name: "Content-Type", value: "application/json")
    request.post(json: [
        "name": "John Doe",
        "email": "john@example.com"
    ])
}
```

### Form-Encoded POST Request

Submit form data:

```swift
let response = try await client.request { request in request in
    request.url = "https://api.example.com/login"
    request.form(parameters: [
        "username": "user@example.com",
        "password": "secret123"
    ])
}
```

### Adding Query Parameters

Add query parameters to a request:

```swift
let response = try await client.request { request in request in
    request.url = "https://api.example.com/search"
    request.setParameter(name: "q", value: "swift")
    request.setParameter(name: "page", value: "1")
    request.get()
}
// Executes: GET https://api.example.com/search?q=swift&page=1
```

### Adding Headers

Set custom headers:

```swift
let response = try await client.request { request in request in
    request.url = "https://api.example.com/protected"
    request.setHeader(name: "Authorization", value: "Bearer \(token)")
    request.setHeader(name: "Accept", value: "application/json")
    request.get()
}
```

### Configuring the HTTP Client

Create a client with custom configuration:

```swift
let client = HttpClient.createClient { config in
    config.timeout = 30.0  // Set timeout to 30 seconds
    config.logger = LogManager.standard  // Enable logging
}
```

### Request Interceptors

Add request interceptors to modify all outgoing requests:

```swift
let client = HttpClient.createClient { config in
    // Add authentication token to all requests
    config.onRequest { request in
        request.setHeader(name: "Authorization", value: "Bearer \(token)")
    }
    
    // Add custom user agent
    config.onRequest { request in
        request.setHeader(name: "User-Agent", value: "MyApp/1.0")
    }
}
```

Request interceptors are executed in the order they are registered, before the request is sent to the server.

### Response Interceptors

Add response interceptors to process all responses:

```swift
let client = HttpClient.createClient { config in
    // Log all responses
    config.onResponse { response in
        print("Response: \(response.status) - \(response.request.url?.absoluteString ?? "")")
    }
    
    // Extract and store cookies
    config.onResponse { response in
        let cookies = response.getCookies()
        storeCookies(cookies)
    }
}
```

Response interceptors are executed in the order they are registered, after the response is received from the server.

### Working with Responses

Access response data:

```swift
let response = try await client.request { request in request in
    request.url = "https://api.example.com/data"
    request.get()
}

if response.status.isSuccess() {
    // Get body as string
    let bodyString = response.bodyAsString()

    // Get raw body data
    if let bodyData = response.body {
        let json = try? JSONSerialization.jsonObject(with: bodyData)
    }

    // Get specific header
    if let contentType = response.getHeader(name: "Content-Type") {
        print("Content-Type: \(contentType)")
    }

    // Get all headers
    let allHeaders = response.headers

    // Get cookies
    let cookies = response.getCookies()
    let cookieStrings = response.getCookieStrings()
}

```

### Status Code Checking

Use convenience methods to check response status:

```swift
if response.status.isSuccess() {
    // 2xx status code
} else if response.status.isRedirect() {
    // 3xx status code
} else if response.status.isClientError() {
    // 4xx status code
} else if response.status.isServerError() {
    // 5xx status code
}
```

### Closing the Client

Clean up resources when done:

```swift
client.close()
```

## Advanced Usage

### Custom HTTP Client Implementation

Create a custom HTTP client by implementing the `HttpClient` protocol:

```swift
class MyCustomHttpClient: HttpClient {
    func request() -> HttpRequest {
        MyCustomHttpRequest()
    }
    
    func request(request: HttpRequest) async -> Result<HttpResponse, Error> {
        // Custom implementation
    }
    
    func request(builder: @escaping @Sendable (HttpRequest) -> Void) async -> Result<HttpResponse, Error> {
        let request = self.request()
        builder(request)
        return await self.request(request: request)
    }
    
    func close() {
        // Clean up resources
    }
}
```

### Reusing HttpRequest Objects

Build a request and execute it separately:

```swift
let request = client.request()
request.url = "https://api.example.com/users"
request.setHeader(name: "Accept", value: "application/json")
request.get()

let result = await client.request(request: request)
```

### Error Handling

Handle different types of network errors:

```swift
do {
    let response = try await client.request { request in request in
        request.url = "https://api.example.com/data"
        request.get()
    }

    if !response.status.isSuccess() {
        // HTTP error (4xx, 5xx)
        print("HTTP Error: \(response.status)")
    }
} catch {
    if let networkError = error as? NetworkError {
        switch networkError {
        case .timeout:
            print("Request timed out")
        case .invalidRequest(let message):
            print("Invalid request: \(message)")
        case .networkError(let underlying):
            print("Network error: \(underlying)")
        case .invalidResponse(let message):
            print("Invalid response: \(message)")
        }
    }
}
```

## Architecture

### Core Protocols

```mermaid
classDiagram
    class HttpClient {
        <<protocol>>
        +request() HttpRequest
        +request(request) Result~HttpResponse, Error~
        +request(builder) Result~HttpResponse, Error~
        +close()
    }
    
    class HttpRequest {
        <<protocol>>
        +url String?
        +setParameter(name, value)
        +setHeader(name, value)
        +get()
        +post(json)
        +put(json)
        +delete()
        +form(parameters)
    }
    
    class HttpResponse {
        <<protocol>>
        +request HttpRequest
        +status Int
        +body Data?
        +headers [String: [String]]
        +getHeader(name) String?
        +getCookies() [HTTPCookie]
        +bodyAsString() String
    }
    
    HttpClient ..> HttpRequest : creates
    HttpClient ..> HttpResponse : returns
    HttpResponse ..> HttpRequest : references
```

### Request Lifecycle

```mermaid
sequenceDiagram
    participant App
    participant Client as HttpClient
    participant Interceptors as Request Interceptors
    participant Session as URLSession
    participant Server
    
    App->>Client: request { ... }
    Client->>Client: Create HttpRequest
    App->>Client: Configure request
    Client->>Interceptors: Apply interceptors
    Interceptors->>Interceptors: Modify request
    Client->>Session: Execute request
    Session->>Server: HTTP Request
    Server-->>Session: HTTP Response
    Session-->>Client: URLResponse + Data
    Client->>Client: Create HttpResponse
    Client->>Interceptors: Apply response interceptors
    Client-->>App: Result<HttpResponse, Error>
```

## Available HTTP Methods

| Method  | Method Call               | Description                                      |
|---------|---------------------------|--------------------------------------------------|
| GET     | `request.get()`           | Retrieve data from a server                      |
| POST    | `request.post(json:)`     | Send data to create a resource                   |
| PUT     | `request.put(json:)`      | Send data to update a resource                   |
| DELETE  | `request.delete()`        | Remove a resource from the server                |
| PATCH   | `request.setMethod(.patch)` | Partially update a resource                    |
| HEAD    | `request.setMethod(.head)`  | Retrieve headers without body                  |
| OPTIONS | `request.setMethod(.options)` | Get supported HTTP methods                   |

## Standard Headers

All requests automatically include the following headers:

| Header                | Value      | Description                        |
|-----------------------|------------|------------------------------------|
| x-requested-with      | ping-sdk   | Identifies requests from the SDK   |
| x-requested-platform  | ios        | Identifies the iOS platform        |

These headers help servers identify and process SDK requests appropriately.

## Thread Safety

All PingNetwork types conform to Swift's `Sendable` protocol, ensuring thread-safe usage in concurrent contexts:

- **HttpClient**: Can be safely shared across actors and tasks
- **HttpRequest**: Sendable for concurrent configuration
- **HttpResponse**: Immutable and safely shareable
- **Interceptors**: Must be `@Sendable` closures

## Performance Considerations

- **Connection Pooling**: URLSession automatically manages connection reuse
- **Request Timeout**: Default 15 seconds (configurable per client)
- **Non-Blocking**: All operations use async/await for efficient concurrency
- **Memory Efficient**: Responses loaded in memory (suitable for typical SDK use cases)
- **Logging Overhead**: Use appropriate log levels in production (WARN or ERROR)

## Security

### HTTPS/TLS

All network communication uses HTTPS by default. URLSession handles certificate validation and TLS negotiation automatically.

### Redirect Prevention

HTTP redirects are automatically prevented to avoid redirect-based attacks. If you need to handle redirects, implement custom logic in response interceptors.

### Cookie Security

Cookies are managed securely through URLSession's cookie storage. Use `getCookies()` to access cookies when needed.

### Sensitive Data

- Never log sensitive information (tokens, passwords) in request/response interceptors
- Use appropriate log levels in production environments
- Consider filtering sensitive headers in logger interceptors

## Testing

### Unit Testing

Mock the `HttpClient` protocol for testing:

```swift
class MockHttpClient: HttpClient {
    var mockResponse: Result<HttpResponse, Error>?
    
    func request() -> HttpRequest {
        MockHttpRequest()
    }
    
    func request(request: HttpRequest) async -> Result<HttpResponse, Error> {
        return mockResponse ?? .failure(NetworkError.invalidRequest("No mock response set"))
    }
    
    func request(builder: @escaping @Sendable (HttpRequest) -> Void) async -> Result<HttpResponse, Error> {
        let request = self.request()
        builder(request)
        return await self.request(request: request)
    }
    
    func close() {}
}
```

### URLProtocol Mocking

For more realistic testing, use URLProtocol to mock URLSession responses:

```swift
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

// Register in your tests
URLProtocol.registerClass(MockURLProtocol.self)
```

## Migration from Orchestrate Network Classes

If you're migrating from the old `Request` class in PingOrchestrate, here's a comprehensive guide covering all the changes:

### Creating a Request

**Before (Orchestrate):**
```swift
let request = Request()
// ... configure and send via custom logic
```

**After (PingNetwork):**
```swift
let client = HttpClient.createClient()
let response = try await client.request { request in
    // ... configure request
}
```

### URL Configuration

**Before (Orchestrate):**
```swift
request.url("https://api.example.com")
// or
request.url(urlRequest)
```

**After (PingNetwork):**
```swift
request.url = "https://api.example.com"
```

### Adding Headers

**Before (Orchestrate):**
```swift
request.header(name: "Authorization", value: "Bearer token")
```

**After (PingNetwork):**
```swift
request.setHeader(name: "Authorization", value: "Bearer token")
```

### Adding Query Parameters

**Before (Orchestrate):**
```swift
request.parameter(name: "page", value: "1")
```

**After (PingNetwork):**
```swift
request.setParameter(name: "page", value: "1")
```

### Setting Cookies

**Before (Orchestrate):**
```swift
request.cookies(cookies: [httpCookie1, httpCookie2])  // [HTTPCookie]
```

**After (PingNetwork):**
```swift
request.setCookie(cookie: "name=value")              // Single cookie string
request.setCookies(cookies: ["name1=value1", "name2=value2"])  // Multiple cookie strings
```

### JSON Body (POST/PUT/DELETE)

**Before (Orchestrate):**
```swift
request.body(body: ["key": "value"])  // Automatically sets POST method
```

**After (PingNetwork):**
```swift
request.post(json: ["key": "value"])   // POST with JSON
request.put(json: ["key": "value"])    // PUT with JSON
request.delete(json: ["key": "value"]) // DELETE with JSON
```

### String Body with Custom Content-Type

**Before (Orchestrate):**
Not directly supported - required manual setup

**After (PingNetwork):**
```swift
request.post(contentType: "text/plain", body: "raw string body")
request.put(contentType: "application/xml", body: "<xml>data</xml>")
request.delete(contentType: "application/json", body: "{\"id\": 123}")
```

### Form-Encoded Data

**Before (Orchestrate):**
```swift
request.form(formData: ["username": "john", "password": "secret"])
```

**After (PingNetwork):**
```swift
request.form(parameters: ["username": "john", "password": "secret"])
```

### HTTP Method

**Before (Orchestrate):**
```swift
request.method(.post)
let method = request.getMethod()  // Returns String?
```

**After (PingNetwork):**
```swift
request.setMethod(.post)
let method = request.getMethod()  // Returns HttpMethod enum
```

### Getting Headers

**Before (Orchestrate):**
Not available on Request class

**After (PingNetwork):**
```swift
let authHeader = request.getHeader(name: "Authorization")  // Single header
let allHeaders = request.getHeaders()                      // All headers as [String: String]
```

### Setting Raw Body Data

**Before (Orchestrate):**
Direct access to `urlRequest.httpBody`

**After (PingNetwork):**
```swift
request.setBody(myData)  // Sets raw Data? body
```

### GET Request

**Before (Orchestrate):**
```swift
request.method(.get)
```

**After (PingNetwork):**
```swift
request.get()  // Clears body and sets GET method
```

### Response Headers

**Before (Orchestrate):**
```swift
let headers: [String: String] = response.headers
```

**After (PingNetwork):**
```swift
let headers: [String: [String]] = response.headers  // Multi-value support
let firstValue = headers["Content-Type"]?.first
// or use convenience method:
let contentType = response.getHeader(name: "Content-Type")
```

### Complete Migration Example

**Before (Orchestrate):**
```swift
let request = Request()
request.url("https://api.example.com/users")
request.header(name: "Authorization", value: "Bearer \(token)")
request.header(name: "Accept", value: "application/json")
request.parameter(name: "page", value: "1")
request.body(body: ["name": "John", "email": "john@example.com"])
// Custom sending logic...
```

**After (PingNetwork):**
```swift
let client = HttpClient.createClient()
let response = try await client.request { request in
    request.url = "https://api.example.com/users"
    request.setHeader(name: "Authorization", value: "Bearer \(token)")
    request.setHeader(name: "Accept", value: "application/json")
    request.setParameter(name: "page", value: "1")
    request.post(json: ["name": "John", "email": "john@example.com"])
}
```

### Constants Migration

**Before (Orchestrate):**
```swift
Request.Constants.contentType      // "Content-Type"
Request.Constants.authorization    // "Authorization"
Request.ContentType.json.rawValue  // "application/json"
Request.HTTPMethod.post            // .post
```

**After (PingNetwork):**
```swift
// Use NetworkConstants or string literals directly
NetworkConstants.headerContentType    // "Content-Type"
NetworkConstants.contentTypeJSON      // "application/json"
HttpMethod.post                       // .post
```

## Platform Requirements

- **iOS**: 16.0+
- **Swift**: 6.0+
- **Xcode**: 15+

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.


© Copyright 2025-2026 Ping Identity Corporation. All Rights Reserved
