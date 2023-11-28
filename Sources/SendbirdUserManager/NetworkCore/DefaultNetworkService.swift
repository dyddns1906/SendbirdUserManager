//
//  NetworkService.swift
//  
//
//  Created by Yongun Lim on 2023/11/23.
//

import Foundation

public enum NetworkError: Error {
    case error(statusCode: Int, data: Data?)
    case notConnected
    case cancelled
    case generic(Error)
    case urlGeneration
    case rateLimitExceeded
    case noResponse
}

public protocol NetworkCancellable {
    func cancel()
}

extension URLSessionTask: NetworkCancellable { }

public protocol NetworkService {
    typealias CompletionHandler = (Result<Data?, NetworkError>) -> Void
    var config: NetworkConfigurable { get set }
    
    func request(endpoint: Requestable, completion: @escaping CompletionHandler) -> NetworkCancellable?
}

public protocol NetworkSessionManager {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    
    func request(_ request: URLRequest,
                 completion: @escaping CompletionHandler) -> NetworkCancellable
}

public protocol NetworkErrorLogger {
    func log(request: URLRequest)
    func log(responseData data: Data?, response: URLResponse?)
    func log(error: Error)
}

// MARK: - Implementation
final public class DefaultNetworkService {
    
    public var config: NetworkConfigurable = ApiDataNetworkConfig()
    private let sessionManager = DefaultNetworkSessionManager()
    private let logger = DefaultNetworkErrorLogger()
    
    private var lastRequestTime: TimeInterval = 0
    private let rateLimitQueue = DispatchQueue(label: "com.SendbirdUserManager.networkRateLimitQueue")
    private var isRequestQueued = false
    
    private let waitingNetworkingGroup = DispatchGroup()
    
    public func initConfigue(applicationId: String, apiToken: String) {
        self.config.applicationId = applicationId
        self.config.apiToken = apiToken
    }
    
    private func request(
        request: URLRequest,
        completion: @escaping CompletionHandler
    ) -> NetworkCancellable {
        let sessionDataTask = sessionManager.request(request) { data, response, requestError in
            
            if let requestError = requestError {
                var error: NetworkError
                if let response = response as? HTTPURLResponse {
                    error = .error(statusCode: response.statusCode, data: data)
                } else {
                    error = self.resolve(error: requestError)
                }
                
                self.logger.log(error: error)
                completion(.failure(error))
            } else {
                self.logger.log(responseData: data, response: response)
                completion(.success(data))
            }
        }
        
        logger.log(request: request)
        
        return sessionDataTask
    }
    
    private func resolve(error: Error) -> NetworkError {
        let code = URLError.Code(rawValue: (error as NSError).code)
        switch code {
            case .notConnectedToInternet: return .notConnected
            case .cancelled: return .cancelled
            default: return .generic(error)
        }
    }
}

extension DefaultNetworkService: NetworkService {
    public func request(
        endpoint: Requestable,
        completion: @escaping CompletionHandler
    ) -> NetworkCancellable? {
        var cancellable: NetworkCancellable?
        var completeResult: Result<Data?, NetworkError> = .failure(.noResponse)
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastRequestTime >= 1 {
            lastRequestTime = currentTime
            cancellable = performRequest(endpoint: endpoint, completion: { result in
                completeResult = result
            })
        } else {
            cancellable = queueRequest(endpoint: endpoint, delay: 1 - (currentTime - lastRequestTime), completion: {result in
                completeResult = result
            })
        }
        waitingNetworkingGroup.notify(queue: rateLimitQueue) {
            completion(completeResult)
        }
        
        return cancellable
    }
    
    private func performRequest(endpoint: Requestable, completion: @escaping CompletionHandler) -> NetworkCancellable? {
        waitingNetworkingGroup.enter()
        do {
            let urlRequest = try endpoint.urlRequest(with: config)
            return request(request: urlRequest, completion: { [weak self] result in
                completion(result)
                self?.waitingNetworkingGroup.leave()
            })
        } catch {
            completion(.failure(.urlGeneration))
            self.waitingNetworkingGroup.leave()
            return nil
        }
    }
    
    private func queueRequest(endpoint: Requestable, delay: TimeInterval, completion: @escaping CompletionHandler) -> NetworkCancellable? {
        var cancellable: NetworkCancellable?
        waitingNetworkingGroup.enter()
        rateLimitQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            cancellable = self?.performRequest(endpoint: endpoint, completion: { result in
                completion(result)
                self?.waitingNetworkingGroup.leave()
            })
        }
        
        waitingNetworkingGroup.wait()
        return cancellable
    }
}

// MARK: - Default Network Session Manager
final public class DefaultNetworkSessionManager: NetworkSessionManager {
    public func request(
        _ request: URLRequest,
        completion: @escaping CompletionHandler
    ) -> NetworkCancellable {
        let task = URLSession.shared.dataTask(with: request, completionHandler: completion)
        
        task.resume()
        return task
    }
}

// MARK: - Logger
final public class DefaultNetworkErrorLogger: NetworkErrorLogger {
    init() { }
    
    public func log(request: URLRequest) {
        printIfDebug("-------------")
        printIfDebug("request: \(request.url!)")
        printIfDebug("headers: \(request.allHTTPHeaderFields!)")
        printIfDebug("method: \(request.httpMethod!)")
        if let httpBody = request.httpBody, let result = ((try? JSONSerialization.jsonObject(with: httpBody, options: []) as? [String: AnyObject]) as [String: AnyObject]??) {
            printIfDebug("body: \(String(describing: result))")
        } else if let httpBody = request.httpBody, let resultString = String(data: httpBody, encoding: .utf8) {
            printIfDebug("body: \(String(describing: resultString))")
        }
    }
    
    public func log(responseData data: Data?, response: URLResponse?) {
        guard let data = data else { return }
        if let dataDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            printIfDebug("responseData: \(String(describing: dataDict))")
        }
    }
    
    public func log(error: Error) {
        printIfDebug("\(error)")
    }
}

// MARK: - NetworkError extension

extension NetworkError {
    var isNotFoundError: Bool { return hasStatusCode(404) }
    
    func hasStatusCode(_ codeError: Int) -> Bool {
        switch self {
            case let .error(code, _):
                return code == codeError
            default: return false
        }
    }
}

extension Dictionary where Key == String {
    func prettyPrint() -> String {
        var string: String = ""
        if let data = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted) {
            if let nstr = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                string = nstr as String
            }
        }
        return string
    }
}

func printIfDebug(_ string: String) {
#if DEBUG
    print(string)
#endif
}
