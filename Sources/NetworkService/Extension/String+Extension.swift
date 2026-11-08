//
//  File.swift
//  NetworkService
//
//  Created by Kashif Hussain on 27/04/26.
//

import Foundation

extension String {
    var mimeType: String {
        let ext = self.lowercased()
        switch ext {
        // Video
        case "mp4":             return "video/mp4"
        case "mov":             return "video/quicktime"
        case "avi":             return "video/x-msvideo"
        case "mkv":             return "video/x-matroska"
        case "webm":            return "video/webm"
        case "m4v":             return "video/x-m4v"
        // Audio
        case "mp3":             return "audio/mpeg"
        case "aac":             return "audio/aac"
        case "wav":             return "audio/wav"
        case "m4a":             return "audio/m4a"
        // Image
        case "jpg", "jpeg":     return "image/jpeg"
        case "png":             return "image/png"
        case "gif":             return "image/gif"
        case "webp":            return "image/webp"
        case "heic":            return "image/heic"
        case "svg":             return "image/svg+xml"
        // Document
        case "pdf":             return "application/pdf"
        case "doc":             return "application/msword"
        case "docx":            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":             return "application/vnd.ms-excel"
        case "xlsx":            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":             return "application/vnd.ms-powerpoint"
        case "pptx":            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt":             return "text/plain"
        case "csv":             return "text/csv"
        case "json":            return "application/json"
        case "zip":             return "application/zip"
        default:                return "application/octet-stream"
        }
    }
}
