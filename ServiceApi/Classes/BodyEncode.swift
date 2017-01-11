//
//  WebRequest.swift
//  ServiceManager
//
//  Created by utsav.patel on 10/01/17.
//  Copyright © 2017 utsav.patel. All rights reserved.
//

import Foundation
import MobileCoreServices
import SystemConfiguration

// MARK: - MultipartFormData

public typealias HTTPHeaders = [String: String]

open class MultipartFormData {
    
    // MARK: - Helper Types
    
    struct EncodingCharacters {
        static let crlf = "\r\n"
    }
    
    struct BoundaryGenerator {
        enum BoundaryType {
            case initial, encapsulated, final
        }
        
        static func randomBoundary() -> String {
            return String(format: "test.boundary.%08x%08x", arc4random(), arc4random())
        }
        
        static func boundaryData(forBoundaryType boundaryType: BoundaryType, boundary: String) -> Data {
            let boundaryText: String
            
            switch boundaryType {
            case .initial:
                boundaryText = "--\(boundary)\(EncodingCharacters.crlf)"
            case .encapsulated:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
            case .final:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
            }
            
            return boundaryText.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        }
    }
    
    class BodyPart {
        let headers: HTTPHeaders
        let bodyStream: InputStream
        let bodyContentLength: UInt64
        var hasInitialBoundary = false
        var hasFinalBoundary = false
        
        init(headers: HTTPHeaders, bodyStream: InputStream, bodyContentLength: UInt64) {
            self.headers = headers
            self.bodyStream = bodyStream
            self.bodyContentLength = bodyContentLength
        }
    }
    
    // MARK: - Properties
    
    /// The `Content-Type` header value containing the boundary used to generate the `multipart/form-data`.
    open var contentType: String { return "multipart/form-data; boundary=\(boundary)" }
    
    /// The content length of all body parts used to generate the `multipart/form-data` not including the boundaries.
    public var contentLength: UInt64 { return bodyParts.reduce(0) { $0 + $1.bodyContentLength } }
    
    /// The boundary used to separate the body parts in the encoded form data.
    public let boundary: String
    
    private var bodyParts: [BodyPart]
    private var bodyPartError: WebError?
    private let streamBufferSize: Int
    
    // MARK: - Lifecycle
    
    /// Creates a multipart form data object.
    ///
    /// - returns: The multipart form data object.
    public init() {
        self.boundary = BoundaryGenerator.randomBoundary()
        self.bodyParts = []
        
        ///
        /// The optimal read/write buffer size in bytes for input and output streams is 1024 (1KB). For more
        /// information, please refer to the following article:
        ///   - https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Streams/Articles/ReadingInputStreams.html
        ///
        
        self.streamBufferSize = 1024
    }
    
    public func append(_ data: Data, withName name: String) {
        let headers = contentHeaders(withName: name)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    /// Creates a body part from the data and appends it to the multipart form data object.
    ///
    /// The body part data will be encoded using the following format:
    ///
    /// - `Content-Disposition: form-data; name=#{name}` (HTTP Header)
    /// - `Content-Type: #{generated mimeType}` (HTTP Header)
    /// - Encoded data
    /// - Multipart form boundary
    ///
    /// - parameter data:     The data to encode into the multipart form data.
    /// - parameter name:     The name to associate with the data in the `Content-Disposition` HTTP header.
    /// - parameter mimeType: The MIME type to associate with the data content type in the `Content-Type` HTTP header.
    public func append(_ data: Data, withName name: String, mimeType: String) {
        let headers = contentHeaders(withName: name, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    /// Creates a body part from the data and appends it to the multipart form data object.
    ///
    /// The body part data will be encoded using the following format:
    ///
    /// - `Content-Disposition: form-data; name=#{name}; filename=#{filename}` (HTTP Header)
    /// - `Content-Type: #{mimeType}` (HTTP Header)
    /// - Encoded file data
    /// - Multipart form boundary
    ///
    /// - parameter data:     The data to encode into the multipart form data.
    /// - parameter name:     The name to associate with the data in the `Content-Disposition` HTTP header.
    /// - parameter fileName: The filename to associate with the data in the `Content-Disposition` HTTP header.
    /// - parameter mimeType: The MIME type to associate with the data in the `Content-Type` HTTP header.
    public func append(_ data: Data, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    /// Creates a body part from the file and appends it to the multipart form data object.
    ///
    /// The body part data will be encoded using the following format:
    ///
    /// - `Content-Disposition: form-data; name=#{name}; filename=#{generated filename}` (HTTP Header)
    /// - `Content-Type: #{generated mimeType}` (HTTP Header)
    /// - Encoded file data
    /// - Multipart form boundary
    ///
    /// The filename in the `Content-Disposition` HTTP header is generated from the last path component of the
    /// `fileURL`. The `Content-Type` HTTP header MIME type is generated by mapping the `fileURL` extension to the
    /// system associated MIME type.
    ///
    /// - parameter fileURL: The URL of the file whose content will be encoded into the multipart form data.
    /// - parameter name:    The name to associate with the file content in the `Content-Disposition` HTTP header.
    public func append(_ fileURL: URL, withName name: String) {
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension
        
        if !fileName.isEmpty && !pathExtension.isEmpty {
            let mime = mimeType(forPathExtension: pathExtension)
            append(fileURL, withName: name, fileName: fileName, mimeType: mime)
        } else {
            setBodyPartError(withReason: .errorInBody("bodyPartFilenameInvalid") )
        }
    }
    
    public func append(_ fileURL: URL, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        
        //============================================================
        //                 Check 1 - is file URL?
        //============================================================
        
        guard fileURL.isFileURL else {
            setBodyPartError(withReason: .errorInBody("bodyPartURLInvalid"))
            return
        }
        
        //============================================================
        //              Check 2 - is file URL reachable?
        //============================================================
        
        do {
            let isReachable = try fileURL.checkPromisedItemIsReachable()
            guard isReachable else {
                setBodyPartError(withReason: .errorInBody("bodyPartFileNotReachable") )
                return
            }
        } catch {
            setBodyPartError(withReason: .errorInBody("bodyPartFileNotReachableWithError") )
            return
        }
        
        //============================================================
        //            Check 3 - is file URL a directory?
        //============================================================
        
        var isDirectory: ObjCBool = false
        let path = fileURL.path
        
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue else
        {
            setBodyPartError(withReason: .errorInBody("bodyPartFileIsDirectory") )
            return
        }
        
        //============================================================
        //          Check 4 - can the file size be extracted?
        //============================================================
        
        let bodyContentLength: UInt64
        
        do {
            guard let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber else {
                setBodyPartError(withReason: .errorInBody("bodyPartFileSizeNotAvailable") )
                return
            }
            
            bodyContentLength = fileSize.uint64Value
        }
        catch {
            setBodyPartError(withReason: .errorInBody("bodyPartFileSizeQueryFailedWithError") )
            return
        }
        
        //============================================================
        //       Check 5 - can a stream be created from file URL?
        //============================================================
        
        guard let stream = InputStream(url: fileURL) else {
            setBodyPartError(withReason: .errorInBody("bodyPartInputStreamCreationFailed") )
            return
        }
        
        append(stream, withLength: bodyContentLength, headers: headers)
    }
    
    public func append(_ stream: InputStream, withLength length: UInt64, headers: HTTPHeaders) {
        let bodyPart = BodyPart(headers: headers, bodyStream: stream, bodyContentLength: length)
        bodyParts.append(bodyPart)
    }
    
    // MARK: - Private - Mime Type
    
    private func mimeType(forPathExtension pathExtension: String) -> String {
        if
            let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
            let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue()
        {
            return contentType as String
        }
        
        return "application/octet-stream"
    }
    
    // MARK: - Private - Content Headers
    
    private func contentHeaders(withName name: String, fileName: String? = nil, mimeType: String? = nil) -> [String: String] {
        var disposition = "form-data; name=\"\(name)\""
        if let fileName = fileName { disposition += "; filename=\"\(fileName)\"" }
        
        var headers = ["Content-Disposition": disposition]
        if let mimeType = mimeType { headers["Content-Type"] = mimeType }
        
        return headers
    }
    
    // MARK: - Private - Boundary Encoding
    
    private func initialBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary)
    }
    
    private func encapsulatedBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .encapsulated, boundary: boundary)
    }
    
    private func finalBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
    }
    
    // MARK: - Private - Errors
    
    private func setBodyPartError(withReason reason: WebError) {
        guard bodyPartError == nil else { return }
        bodyPartError = reason
    }
    
    
    // MARK: - Data Encoding
    
    /// Encodes all the appended body parts into a single `Data` value.
    ///
    /// It is important to note that this method will load all the appended body parts into memory all at the same
    /// time. This method should only be used when the encoded data will have a small memory footprint. For large data
    /// cases, please use the `writeEncodedDataToDisk(fileURL:completionHandler:)` method.
    ///
    /// - throws: An `AFError` if encoding encounters an error.
    ///
    /// - returns: The encoded `Data` if encoding is successful.
    public func encode() throws -> Data {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        
        var encoded = Data()
        
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true
        
        for bodyPart in bodyParts {
            let encodedData = try encode(bodyPart)
            encoded.append(encodedData)
        }
        
        return encoded
    }
    
    /// Writes the appended body parts into the given file URL.
    ///
    /// This process is facilitated by reading and writing with input and output streams, respectively. Thus,
    /// this approach is very memory efficient and should be used for large body part data.
    ///
    /// - parameter fileURL: The file URL to write the multipart form data into.
    ///
    /// - throws: An `AFError` if encoding encounters an error.
//    public func writeEncodedData(to fileURL: URL) throws {
//        if let bodyPartError = bodyPartError {
//            throw bodyPartError
//        }
//        
//        if FileManager.default.fileExists(atPath: fileURL.path) {
//            throw AFError.multipartEncodingFailed(reason: .outputStreamFileAlreadyExists(at: fileURL))
//        } else if !fileURL.isFileURL {
//            throw AFError.multipartEncodingFailed(reason: .outputStreamURLInvalid(url: fileURL))
//        }
//        
//        guard let outputStream = OutputStream(url: fileURL, append: false) else {
//            throw AFError.multipartEncodingFailed(reason: .outputStreamCreationFailed(for: fileURL))
//        }
//        
//        outputStream.open()
//        defer { outputStream.close() }
//        
//        self.bodyParts.first?.hasInitialBoundary = true
//        self.bodyParts.last?.hasFinalBoundary = true
//        
//        for bodyPart in self.bodyParts {
//            try write(bodyPart, to: outputStream)
//        }
//    }
    
    // MARK: - Private - Body Part Encoding
    
    private func encode(_ bodyPart: BodyPart) throws -> Data {
        var encoded = Data()
        
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
        encoded.append(initialData)
        
        let headerData = encodeHeaders(for: bodyPart)
        encoded.append(headerData)
        
        let bodyStreamData = try encodeBodyStream(for: bodyPart)
        encoded.append(bodyStreamData)
        
        if bodyPart.hasFinalBoundary {
            encoded.append(finalBoundaryData())
        }
        
        return encoded
    }
    
    private func encodeHeaders(for bodyPart: BodyPart) -> Data {
        var headerText = ""
        
        for (key, value) in bodyPart.headers {
            headerText += "\(key): \(value)\(EncodingCharacters.crlf)"
        }
        headerText += EncodingCharacters.crlf
        
        return headerText.data(using: String.Encoding.utf8, allowLossyConversion: false)!
    }
    
    private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer { inputStream.close() }
        
        var encoded = Data()
        
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            
            if let error = inputStream.streamError {
                throw WebError.errorInBody("multipartEncodingFailed inputStreamReadFailed \(error.localizedDescription)") // AFError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
            }
            
            if bytesRead > 0 {
                encoded.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        
        return encoded
    }
    
}

class URLEncode {
 
    static func encodeParamToURL(urlString : String, requestParams: [String:Any] = [:]) throws -> URL {
        
        guard var requestURL = URL(string: urlString) else {
            throw WebError.errorInRequest("Invalid url String")
        }
        
        if var urlComponents = URLComponents(url: requestURL, resolvingAgainstBaseURL: false), !requestParams.isEmpty {
            
            let percentEncodedQuery = (urlComponents.percentEncodedQuery.map { $0 + "&" } ?? "") + query(requestParams)
            urlComponents.percentEncodedQuery = percentEncodedQuery
            
            requestURL = urlComponents.url!
        }
        
        return requestURL
    }
   
    static func query(_ parameters: [String: Any]) -> String {
        var components: [(String, String)] = []
        
        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += URLEncode.queryComponents(fromKey: key, value: value)
        }
        
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    
    private static func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
        var components: [(String, String)] = []
        
        if let dictionary = value as? [String: Any] {
            for (nestedKey, value) in dictionary {
                components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
            }
        } else if let array = value as? [Any] {
            for value in array {
                components += queryComponents(fromKey: "\(key)[]", value: value)
            }
        } else if let value = value as? NSNumber {
            if value.isBool {
                components.append((escape(key), escape((value.boolValue ? "1" : "0"))))
            } else {
                components.append((escape(key), escape("\(value)")))
            }
        } else if let bool = value as? Bool {
            components.append((escape(key), escape((bool ? "1" : "0"))))
        } else {
            components.append((escape(key), escape("\(value)")))
        }
        
        return components
    }
    
    private static func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        
        var escaped = ""
        
        //==========================================================================================================
        //
        //  Batching is required for escaping due to an internal bug in iOS 8.1 and 8.2. Encoding more than a few
        //  hundred Chinese characters causes various malloc error crashes. To avoid this issue until iOS 8 is no
        //  longer supported, batching MUST be used for encoding. This introduces roughly a 20% overhead. For more
        //  info, please refer to:
        //
        //      - https://github.com/Alamofire/Alamofire/issues/206
        //
        //==========================================================================================================
        
        if #available(iOS 8.3, *) {
            escaped = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
        } else {
            let batchSize = 50
            var index = string.startIndex
            
            while index != string.endIndex {
                let startIndex = index
                let endIndex = string.index(index, offsetBy: batchSize, limitedBy: string.endIndex) ?? string.endIndex
                let range = startIndex..<endIndex
                
                let substring = string.substring(with: range)
                
                escaped += substring.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? substring
                
                index = endIndex
            }
        }
        
        return escaped
    }
}
