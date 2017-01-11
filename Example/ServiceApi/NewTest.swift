//  NewTest.swift
//  ServiceManager
//
//  Created by utsav.patel on 10/01/17.
//  Copyright © 2017 utsav.patel. All rights reserved.
//

import Foundation
import ServiceApi

let appDomainURL = "http://localhost:3000/"

// Test Data
class TestData {
    
    static let params = [UploadData(key: "stringTypeKey", value: "Utsav"),
                        UploadData(key: "numberTypeKey", value: 123),
                        UploadData(key: "boolTypeKey", value: true),
                        UploadData(key: "floatTypeKey", value: 2.2),
                        UploadData(key: "arrayTypeKey", value: ["a","b"]),
                        UploadData(key: "dictionaryTypeKey", value : ["a":1,"b":"2","c":true]) ]
    
    static let headers = [UploadHeader(key: "HEADER1", value: "hed1"),
                  UploadHeader(key: "HEADER2", value: "hed2")]
    
    static let files = [UploadFile(key: "WhiteApple", URLString: Bundle.main.path(forResource: "WhiteApple", ofType: "jpg")!, name: "WhiteApple.jpg")]

}

// Test Service
public struct NodeTest {
    
    @discardableResult
    static func callService(header: Bool, file: Bool, param: Bool, serviceType: WebMethod) -> ServiceApi {
        
        let path = "Test"
        
        let service = ServiceApi(url: appDomainURL + path)
        
        service.requestMethod = serviceType
        
        service.requestParams = param ? TestData.params : nil
        service.requestHeader = header ? TestData.headers : nil
        
        if serviceType == .POST || serviceType == .PUT  {
            service.requestFiles  = file ? ( TestData.files ) : nil
        }
        
        try! service.request { (result) in
            
            switch result {
            case .success(let json) :
                print(json)
                
            case .failer(let errorString) :
                print("error \(errorString)")
            }
        }
        
        service.callService()

        return service
    }
}
