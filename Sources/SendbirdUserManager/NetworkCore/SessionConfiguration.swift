//
//  SessionConfiguration.swift
//  
//
//  Created by Yongun Lim on 2023/11/22.
//

import Foundation

public protocol NetworkConfigurable {
    var applicationId: String? { get set }
    var apiToken: String? { get set }
    var baseURL: URL { get }
    var headers: HTTPHeaders { get }
    var queryParameters: ParametersValue { get }
}

public struct ApiDataNetworkConfig: NetworkConfigurable {
    public var applicationId: String?
    public var apiToken: String?
    public var queryParameters: ParametersValue = [:]
    public var headers: HTTPHeaders {
        get {
            (_headers ?? [:]).merging(defaultHeaders) { (old, new) in new }
        }
        set {
            _headers = newValue
        }
    }
    
    private var _headers: HTTPHeaders?
    
    private var defaultHeaders: HTTPHeaders {
        guard let apiToken else {
            return [:]
        }
        return ["Api-Token": apiToken]
    }
    
    public var baseURL: URL {
        guard let applicationId else {
            fatalError("\(self) :: application-id가 설정되지 않았습니다.")
        }
        return URL(string: "https://api-\(applicationId).sendbird.com/")!
    }
}
