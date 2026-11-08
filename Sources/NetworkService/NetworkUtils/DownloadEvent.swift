//
//  DownloadEvent.swift
//  NetworkService
//
//  Created by Kashif Hussain on 10/04/26.
//

import Foundation

// MARK: - Download Event for Stream Progress
public enum DownloadEvent<T: Decodable> {
    case progress(Double)           // 0.0 to 1.0
    case response(T, URL)           // Decoded response + saved file URL
}
