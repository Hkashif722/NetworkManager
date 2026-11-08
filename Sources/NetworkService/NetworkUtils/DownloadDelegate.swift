//
//  DownloadDelegate.swift
//  NetworkService
//
//  Created by Kashif Hussain on 10/04/26.
//

import Foundation

// MARK: - Download Delegate for Progress Tracking

internal final class DownloadDelegate<T: Decodable>: NSObject, URLSessionDownloadDelegate {
    
    let continuation: AsyncThrowingStream<DownloadEvent<T>, Error>.Continuation
    let decoder: JSONDecoder
    let middlewares: [NetworkMiddleware]
    let validators: [ResponseValidator]
    let destinationFileName: String?
    
    var task: URLSessionDownloadTask?
    var tempFileLocation: URL?
    var tempFileCopyError: Error?          // ← stores copy failure from didFinishDownloadingTo
    var session: URLSession?               // ← retains session to prevent dealloc in SPM
    
    init(
        continuation: AsyncThrowingStream<DownloadEvent<T>, Error>.Continuation,
        decoder: JSONDecoder,
        middlewares: [NetworkMiddleware],
        validators: [ResponseValidator],
        destinationFileName: String?
    ) {
        self.continuation = continuation
        self.decoder = decoder
        self.middlewares = middlewares
        self.validators = validators
        self.destinationFileName = destinationFileName
    }
    
    // MARK: - Progress
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.continuation.yield(.progress(progress))
        }
        
        #if DEBUG
        print("📥 Download Progress: \(Int(progress * 100))% (\(totalBytesWritten)/\(totalBytesExpectedToWrite) bytes)")
        #endif
    }
    
    // MARK: - File Ready
    // ⚠️ `location` is ONLY valid during this callback — must copy immediately
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let tempCopy = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(location.pathExtension)
        
        do {
            try FileManager.default.copyItem(at: location, to: tempCopy)
            self.tempFileLocation = tempCopy
        } catch {
            self.tempFileCopyError = error
        }
    }
    
    // MARK: - Completion
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            self.session?.invalidateAndCancel()  // ← use self.session, not the param
            self.session = nil                   // ← break retain cycle cleanly
        }
        
        // 1. Network-level error
        if let error {
            continuation.finish(throwing: error)
            return
        }
        
        // 2. Temp file copy failed
        if let copyError = tempFileCopyError {
            continuation.finish(throwing: copyError)
            return
        }
        
        guard let httpResponse = task.response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let tempLocation = tempFileLocation else {
            
            #if DEBUG
            if task.response as? HTTPURLResponse == nil {
                print("❌ Guard failed: task.response is not HTTPURLResponse")
            } else if let http = task.response as? HTTPURLResponse,
                      !(200...299).contains(http.statusCode) {
                print("❌ Guard failed: statusCode \(http.statusCode) out of range")
            } else if tempFileLocation == nil {
                print("❌ Guard failed: tempFileLocation is nil")
            }
            #endif
            
            continuation.finish(throwing: APIError.invalidResponse)
            return
        }
        
        do {
            var data = try Data(contentsOf: tempLocation)
            
            // Cleanup our temp copy
            try? FileManager.default.removeItem(at: tempLocation)
            
            // Process through middleware
            for middleware in middlewares {
                data = try middleware.process(data: data, response: httpResponse)
            }
            
            // Run validators
            for validator in validators {
                data = try validator.validate(data: data, response: httpResponse)
            }
            
            #if DEBUG
            print("📥 Downloaded \(data.count) bytes")
            #endif
            
            // Resolve final destination
            let fileManager = FileManager.default
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            let fileName = destinationFileName ?? tempLocation.lastPathComponent
            let finalURL = documents.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: finalURL.path) {
                try fileManager.removeItem(at: finalURL)
            }
            
            // MARK: Raw Data shortcut (PDF, binary files — skip JSON decoding)
            if T.self == Data.self, let decoded = data as? T {
                try data.write(to: finalURL)
                
                #if DEBUG
                print("📥 Binary file saved to: \(finalURL.path)")
                #endif
                
                continuation.yield(.response(decoded, finalURL))
                continuation.finish()
                return
            }
            
            // MARK: JSON response — handle raw strings
            let rawString = String(data: data, encoding: .utf8) ?? ""
            let isRawString = !rawString.hasPrefix("{") && !rawString.hasPrefix("[")
            
            if isRawString {
                let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
                let isAlreadyQuoted = trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2
                if !isAlreadyQuoted, let quoted = "\"\(trimmed)\"".data(using: .utf8) {
                    data = quoted
                }
            }
            
            let decodedResponse = try decoder.decode(T.self, from: data)
            try data.write(to: finalURL)
            
            #if DEBUG
            print("📥 JSON response saved to: \(finalURL.path)")
            #endif
            
            continuation.yield(.response(decodedResponse, finalURL))
            continuation.finish()
            
        } catch {
            continuation.finish(throwing: error)
        }
    }
    
    // MARK: - Resume Support
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        #if DEBUG
        print("📥 Download resumed at offset: \(fileOffset)")
        #endif
    }
}
