//
//  UploadEvent.swift
//  NetworkService
//
//  Created by Kashif Hussain on 17/02/26.
//

import Foundation

//Helper Methods
public enum UploadEvent<T: Decodable & Sendable>: Sendable {
    case progress(Double)
    case response(T)  // T surfaces to the caller ✅
}
