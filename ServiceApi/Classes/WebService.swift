//
//  ServiceApi.swift
//  ServiceManager
//
//  Created by utsav.patel on 10/01/17.
//  Copyright © 2017 utsav.patel. All rights reserved.
//

import Foundation
import MobileCoreServices
import SystemConfiguration
import SwiftyJSON

/// WebMethod is ServiceApi class supported Methods.
///
/// This Methods will define how to create request and bind data into request
///
/// - GET:      Bind data in URL encode.
/// - POST:     Bind data in request body as multi-part or json encoading
/// - DELETE:   Structure same as GET request but it is use for delete data
/// - PUT:      Structure same as POST request but it is use for add/update data

public enum WebMethod : String {
    case GET, POST, DELETE, PUT
}


/// WebDebuge is fro internal use
///
/// This use for seprating logging in WebMethod class
///

enum WebDebuge : String {
    case MakeRequest
    case SendRequest
    case GetResponse
}

/// WebError is ServiceApi class errors
///
/// This will throw and give information about perticuler error while creating request
///
/// - errorInBody:      Error Occure while creating request Body
/// - errorInRequest:   Error Occure while creating Url request
/// - error:            Common Errors

enum WebError : Error {
    case errorInBody(String)
    case errorInRequest(String)
    case error(String)
}

/// JsonResponce is custom Responce type
///
/// - success(JSON):    Success With JSON(Swifty Json) object (optional)
/// - failer(String):   Responcd error with failer message    (optional)

public enum JsonResponce {
    case success(JSON)
    case failer(String)
}

/// extension of NSNumber

extension NSNumber {
    /// Hepler extension of NSNumber
    var isBool: Bool { return CFBooleanGetTypeID() == CFGetTypeID(self) }
}

/// UploadFile is Struct that contain all information about file which will uploaded throgh ServiceApi class
///
/// - key:          String Key which is use for identify resource (Required)
/// - data:         File data that will actually uploaded (Optional)
/// - URLString:    File URL fromwhere file will uploaded (Optional) data/URLString must be required
/// - mime:         File mime type (optional)
/// - name:         File name string (optional)

public struct UploadFile {
    
    let key : String
    
    var data : Data? = nil
    var URLString  : String? = nil

    let mime : String?
    let name : String?
    
    /// Custom init method for uplaod file with URLString
    
   public init(key : String, URLString  : String, mime : String? = nil , name : String? = nil) {
        
        self.URLString = URLString
        self.key = key
        self.mime = mime
        self.name = name
        
        try! checkURL()
    }
    
    /// checkURL() is function for checking that file url is valid for uploading task or not it can throws error
    
    mutating func checkURL() throws {
        
        if let url = URL(string: self.URLString!), url.isFileURL {
            return
        }
        
        let urlFile = URL(fileURLWithPath: self.URLString!)
        guard urlFile.isFileURL else {
            throw WebError.errorInRequest("FileURLNotConvertable")
        }
        
        self.URLString = urlFile.relativeString
    }
    
    /// Custom init method for uplaod file with data
    
   public init(key : String, data: Data, mime : String? = nil , name : String? = nil){
        self.data = data
        self.key = key
        self.mime = mime
        self.name = name
    }
}

/// UploadData is Struct that contain all information about data Parameters which will send with request
///
/// - key:          String Key which is use for identify resource   (Required)
/// - data:         File data that will actually send with request  (Optional)
/// - json:         Json format of data( user for simplyfy data)

public struct UploadData {
    
    let key : String
    var data : Data
    
    var json : JSON
    
    /// Custom init method for with key and any data Type

    public init( key : String, value: Any) {
        
        self.json = JSON(value)
        self.key = key
     
        let string = json.rawString()!
        
        self.data = string.data(using: String.Encoding.utf8)!
    }
}

/// UploadHeader is Struct that contain all information about request header
///
/// - key:          String Key use for identify header key   (Required)
/// - value:        String Key use for identify header value (Required)

public struct UploadHeader {
    let key : String
    var value : String
    
    public init( key : String, value: String) {
        
        self.value = value
        self.key = key
    }
}

/// Cancelable protocol for giving support of cancel service after all
///
/// - isCancelable:     Give status of Service is cancelable or not
/// - cancel():         Function user for cancel Service

public protocol Cancelable {
    var isCancelable : Bool { set get }
    func cancel()
}

/// Common configuration file ServiceApi 
///
/// - requestCount:     Total request counts
/// - isLogging:        Enabled Logging
/// - validateWebResponce():  Function use for validating responce from web for status code or other

public struct ServiceApiConfig {
    static var requestCount = 0
    static let isLogging = true
    
/// validateWebResponce
    /// - jsonString:     Parameter as JSON(Swifty) object
    /// - (Bool, String):  return true for success or false and reason for error
    static func validateWebResponce(_ jsonString : JSON) -> (Bool, String) {
        // if status code is 0 then error or something else depance on web service
        return (true,"")  // validate json responce
    }
}

/// ServiceApiv class use for create and calling ServiceApi with diff features

open class ServiceApi : Cancelable {
    
    // MARK: - Cancelable

    ///  It will give status of Service is cancelable or not
    public var isCancelable : Bool = true
    
    /// cancel():     Function user for cancel Service
    public func cancel() {
        if isCancelable{
            webTask.cancel()
            printWs("WebRequest Cancel", type: .SendRequest)
        }
    }
    
    // MARK: - setup

    ///  Main urlString of web request (Required)
    var urlString : String

    // Data
    /// List header which is bind with request (Optional)
    
    public var requestHeader : [UploadHeader]?
    
    /// List parameters which is bind with request (Optional)
    
    public var requestParams : [UploadData]?
    
    /// List file which is bind with request (Optional)
    
    public var requestFiles : [UploadFile]?
    
    
    
    /// Web request type use for identify binding methosd for parameter and file (default is GET)
    
    public var requestMethod : WebMethod = .GET
    
    
    
    // internal use
    /// webRequest Request object user for calling web service
    
    private var webRequest : NSMutableURLRequest!
    
    /// webTask is session object of given webRequest
    
    private var webTask : URLSessionTask!
    
    /// timeOut Interval for webRequest
    
    private var timeOut : TimeInterval = 10
    
    
    // MARK: - debug
    
    /// requestId it store id of request help debug service

    private var requestId  = 0
    
    /// ifDebuge private variable user for log printting while calling service
    
    private let ifDebuge   = ServiceApiConfig.isLogging
    
    /// startDate private variable use for calculate total service time
    
    private var startDate : Date!

    
    // MARK: - Init

    /// Custom init With url string

    public init(url urlString: String) {
        
        if ifDebuge {
            ServiceApiConfig.requestCount += 1
            requestId = ServiceApiConfig.requestCount
        }
        
        self.urlString = urlString
    }
    
    /// Print log function with some custom functionality

    private func printWs(_ str : String, type : WebDebuge , value: Any? = nil) {
        
        if ifDebuge {
            var string : String? = nil
            if value != nil {
                if value is [UploadHeader] {
                    let header = value as! [UploadHeader]
                    string = header.reduce("") { $0 + "\n  \($1.key) : \($1.value)" }
                }
                
                if value is [UploadFile] {
                    let files = value as! [UploadFile]
                    string = files.reduce("") { $0 + "\n  key:\($1.key) mime:\($1.mime) name:\($1.name)" }
                }
                
                if value is [UploadData] {
                    let param = value as! [UploadData]
                    string = param.reduce("") { $0 + "\n  \($1.key) : \($1.json)" }
                }
            }
            
            print("\(type.rawValue)(\(requestId)) : *---- ---- ---- ----* \(str) \( (string == nil) ? "" : "\( string!)")")
        }
    }
    
    // MARK: - Prepare and call Service
    
    /// Use for calling web service
    
    open func callService() {
        beforeSend()
        startDate = Date()
        webTask.resume()
    }
    
    /// Use for creating web service according to request type it can throw error
    
    open func request(_ onCompletionHandler:@escaping (JsonResponce) -> ()) throws {
        
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy // this is the default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        
        let webSession = URLSession(configuration: configuration)
        
        switch requestMethod {
        case .POST:
            if let _ = requestFiles { // multiPart
                // multipart/form-data
                try prepareBody4MultiPartPOST()
            }else{ // json encode
                try prepareBodyJsonPOST()
            }
        case .GET: // url encode
            try prepareURL4GET()
        case .DELETE:
            try prepareURL4DELETE()
        case  .PUT:
            if let _ = requestFiles { // multiPart
                // multipart/form-data
                try prepareBody4MultiPartPUT()
            }else{ // json encode
                try prepareBodyJsonPUT()
            }
        }
        
        webTask =  webSession.dataTask(with: webRequest as URLRequest) { res in
            onCompletionHandler(self.handle(Response: res))
        }
    }
    
    /// This function use for handle responce from server
    
    private func handle(Response res: (Data?, URLResponse?, Error?)) -> JsonResponce {
        
        isCancelable  = false
        
        afterCompleted()
        
        let (data,response,error) = res
        
        if error != nil {
            
            self.printWs("Error", type: .GetResponse, value: error)
            
            return .failer(error!.localizedDescription)
        }
        
        if (response as! HTTPURLResponse).statusCode == 200 {
            
            let json = JSON(data: data!)
            
            let (status, msg) = ServiceApiConfig.validateWebResponce(json)
            
            if status {
                
                self.printWs("Data", type: .GetResponse, value: json)
                return .success(json)
                
            }else {
                return .failer(msg)
            }
        }else{
            return .failer("Something want wrong")
        }
    }
    
    // MARK: - Private methods
    
    /// This method call before calling web service

    private func beforeSend() {
        isCancelable  = true
        printWs("WebRequest Start", type: .SendRequest)
    }

    /// This call after web service Completed
    
    private func afterCompleted() {
        
        /// It will count time of request and return time in string format
        
        func timeLeftSinceStart() -> String {
            
            var timeLeft = ""
            
            var seconds =  Date().timeIntervalSince(startDate)
           
            // minutes
            let minutes = TimeInterval(floor(Double(seconds / 60)))
            if minutes > 0 {
                seconds -= minutes * 60
                timeLeft += "\(minutes) Minutes "
            }
            
            if seconds > 0 {
                timeLeft +=  String(format: "%.2f", seconds) + "Seconds"
            }
            
            return timeLeft
        }
        printWs("Request Completed in \(timeLeftSinceStart())", type: .GetResponse)
    }
    
    /// This function will add header and request type string to Webrequest

    private func addHeaderAndTypeToRequest() {
        webRequest.httpMethod = requestMethod.rawValue
        
        // Request Header
        if let headers = requestHeader {
            printWs("Header", type: .MakeRequest, value: headers )
            for header in headers {
                webRequest.setValue(header.value , forHTTPHeaderField: header.key)
            }
        }
    }
    
    /// This function convert any type to json data
    
    private func jsonData(using any:Any) throws -> Data {
        return try JSONSerialization.data(withJSONObject: any, options: .prettyPrinted)
    }
    
    /// It will Convert requestParams to dictionary format
    
    private func getParamInDic() -> [String: Any] {
        var parameters : [String:Any] = [:]
        
        if requestParams != nil {
            for data in requestParams! {
                parameters[data.key] =  data.json.object
            }
        }
       
        return parameters
    }
    
    // MARK: - encode request adn data to different format accoding to it's type
    
    /// It will create parameter and file to multi-part format use in POST(Multipart) and PUT(Multipart)
    
    private func createMultiPartEncoading() throws {
        
        try createRequest()
        
        // Body Parameter and Files
        let mBody = MultipartFormData()
        
        if let param = requestParams {   // Body Parameter
            self.printWs("Parameters", type: .MakeRequest, value: param )

            for data in param {
                mBody.append(data.data, withName: data.key)
             }
        }
        
        if let files = requestFiles {    // Files
            
            printWs("File/Image uploads", type: .MakeRequest, value: files )
                
                for file in files {
               
                if let data = file.data { // data
                    
                    // append bodyparts
                    if let mime = file.mime {
                        if let name = file.name {  //name, mime
                            mBody.append(data, withName: file.key, fileName: name, mimeType: mime)
                        }else{ // mime
                            mBody.append(data, withName: file.key, mimeType: mime)
                        }
                    }else{
                        mBody.append(data, withName: file.key)
                    }
                    
                }else if let urlFile = file.URLString {  // url
                    
                    // Creating file URL
                    guard let fileURL = URL(string: urlFile) else {
                        throw WebError.errorInRequest("Invalid file url String")
                    }
                    
                    // append bodyparts
                    if let mime = file.mime, let name = file.name  { //name, mime
                        mBody.append(fileURL, withName: file.key, fileName: name, mimeType: mime)
                    }else{
                        mBody.append(fileURL, withName: file.key)
                    }
                    
                }else{
                    throw WebError.errorInRequest("Invalid request File")
                }
            }
        }
        
        webRequest.setValue(mBody.contentType, forHTTPHeaderField: "Content-Type")
        
        // encode and set body to request
        webRequest.httpBody = try mBody.encode()
    }
    
    /// It will create parameter and file to body/json format use in POST and PUT

    private func prepareBody4Json() throws {
        
        try createRequest()
        
        webRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Body Parameter and Files
        var mBody = Data()
        
        if let param = requestParams {   // Body Parameter
            printWs("Parameters", type: .MakeRequest, value : param)
            
            var dic : [String: Any] = [:]
            
            for par in param {
                dic[par.key] = par.json.rawValue
            }
            let data = try jsonData(using: dic)

            mBody.append(data)
        }
        
        webRequest.httpBody = mBody
    }
    
    /// This function use for binding request data to Webrequest
    
    private func prepareBodyJsonPOST() throws {
        self.printWs("POST(Json)", type: .MakeRequest, value: urlString)
        
        try prepareBody4Json()
    }
    
    private func prepareBodyJsonPUT() throws {
        self.printWs("PUT(Json)", type: .MakeRequest, value: urlString)
        
        try prepareBody4Json()
    }
    
    private func prepareBody4MultiPartPOST() throws {
        self.printWs("POST(multiPart)", type: .MakeRequest, value: urlString)
        
        try createMultiPartEncoading()
    }
    
    private func prepareBody4MultiPartPUT() throws {
        self.printWs("PUT(multiPart)", type: .MakeRequest, value: urlString)
        
        try createMultiPartEncoading()
    }
    
    private func prepareURL4GET() throws {
        self.printWs("GET URL Encode", type: .MakeRequest, value: urlString)
        
        try createURLEncoading()
    }
    
    private func prepareURL4DELETE() throws {
        self.printWs("DELETE URL Encode", type: .MakeRequest, value: urlString)
        
        try createURLEncoading()
    }
    
    // MARK: - request
    
    private func createURLEncoading() throws { // GET, DELETE
        
        if let param = requestParams {   // Body Parameter
            self.printWs("Parameters", type: .MakeRequest, value: param )
        }
        
        let requestURL = try URLEncode.encodeParamToURL(urlString: urlString, requestParams: getParamInDic())
        urlString = requestURL.relativeString
        
        try createRequest()
    }
    
    private func createRequest() throws {
        
        // Creating Request URL
        guard let requestURL = URL(string: urlString) else {
            throw WebError.errorInRequest("Invalid url String")
        }
        
        // Creating initial POST Request
        webRequest = NSMutableURLRequest(url: requestURL,
                                         cachePolicy: .reloadIgnoringLocalCacheData,
                                         timeoutInterval: timeOut)
        addHeaderAndTypeToRequest()
    }
}
