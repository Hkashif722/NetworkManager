//
//  UploadDelegate.swift
//  NetworkService
//
//  Created by Kashif Hussain on 17/02/26.
//

import Foundation

// MARK: - Upload Delegate for Progress Tracking

internal class UploadDelegate<T: Decodable>: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    let continuation: AsyncThrowingStream<UploadEvent<T>, Error>.Continuation
    let decoder: JSONDecoder
    let middlewares: [NetworkMiddleware]
    let validators: [ResponseValidator]
    
    var task: URLSessionTask?
    var receivedData = Data()
    
    init(
        continuation: AsyncThrowingStream<UploadEvent<T>, Error>.Continuation,
        decoder: JSONDecoder,
        middlewares: [NetworkMiddleware],
        validators: [ResponseValidator]
    ) {
        self.continuation = continuation
        self.decoder = decoder
        self.middlewares = middlewares
        self.validators = validators
    }
    
    // Track upload progress
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        continuation.yield(.progress(progress))
        
        #if DEBUG
        print("📤 Upload Progress: \(Int(progress * 100))% (\(totalBytesSent)/\(totalBytesExpectedToSend) bytes)")
        #endif
    }
    
    // Collect response data
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
    }
    
    // Handle completion
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            session.invalidateAndCancel()
        }
        
        if let error = error {
            continuation.finish(throwing: error)
            return
        }
        
        guard let httpResponse = task.response as? HTTPURLResponse else {
            continuation.finish(throwing: APIError.invalidResponse)
            return
        }
        
        do {
            // Process response through middleware
            var processedData = receivedData
            for middleware in middlewares {
                processedData = try middleware.process(data: processedData, response: httpResponse)
            }
            
            // Run validators
            for validator in validators {
                processedData = try validator.validate(data: processedData, response: httpResponse)
            }
            
            #if DEBUG
            if let responseString = String(data: processedData, encoding: .utf8) {
                print("📥 Response Data: \(responseString)")
            }
            #endif
            
            // Handle raw string responses (e.g. file URLs returned as plain text)
            let rawString = String(data: processedData, encoding: .utf8) ?? ""
            let isRawString = !rawString.hasPrefix("{") && !rawString.hasPrefix("[")
            
           
            if isRawString {
                let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
                let isAlreadyQuoted = trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2
                
                // Only wrap if NOT already quoted
                if !isAlreadyQuoted {
                    if let quoted = "\"\(trimmed)\"".data(using: .utf8) {
                        processedData = quoted
                    }
                }
            }
            
            // Decode and yield the strongly-typed response
            let decodedResponse = try decoder.decode(T.self, from: processedData)
            continuation.yield(.response(decodedResponse))
            continuation.finish()
            
        } catch {
            continuation.finish(throwing: error)
        }
    }
}
