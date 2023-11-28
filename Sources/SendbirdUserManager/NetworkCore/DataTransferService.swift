//
//  DataTransferService.swift
//  
//
//  Created by Yongun Lim on 2023/11/23.
//

import Foundation

public struct APIErrorResponse: Codable {
    let message: String
    let code: Int
    let error: Bool
}

public enum DataTransferError: Error {
    case noResponse
    case parsing(Error)
    case networkFailure(NetworkError)
    case resolvedNetworkFailure(Error)
    case errorResponse(APIErrorResponse)
}

public protocol DataTransferDispatchQueue {
    func asyncExecute(work: @escaping () -> Void)
}

extension DispatchQueue: DataTransferDispatchQueue {
    public func asyncExecute(work: @escaping () -> Void) {
        async(group: nil, execute: work)
    }
}

public protocol DataTransferErrorResolver {
    func resolve(error: NetworkError) -> Error
}

public protocol ResponseDecoder {
    func decode<T: Decodable>(_ data: Data) throws -> T
}

protocol DataTransferErrorLogger {
    func log(error: Error)
}

final public class DefaultDataTransferService: SBNetworkClient {
    
    public var networkService: NetworkService
    private let errorResolver: DataTransferErrorResolver
    private let errorLogger: DataTransferErrorLogger
    
    public init() {
        self.networkService = DefaultNetworkService()
        self.errorResolver = DefaultDataTransferErrorResolver()
        self.errorLogger = DefaultDataTransferErrorLogger()
    }
    
    init(
        with networkService: NetworkService,
        errorResolver: DataTransferErrorResolver = DefaultDataTransferErrorResolver(),
        errorLogger: DataTransferErrorLogger = DefaultDataTransferErrorLogger()
    ) {
        self.networkService = networkService
        self.errorResolver = errorResolver
        self.errorLogger = errorLogger
    }
}

extension DefaultDataTransferService {
    public func request<T: Decodable, E: Request>(
        with endpoint: E,
        on queue: DataTransferDispatchQueue,
        completion: @escaping CompletionHandler<T>
    ) -> NetworkCancellable? where E.Response == T {
        return networkService.request(endpoint: endpoint) { result in
            switch result {
                case .success(let data):
                    let result: Result<T, DataTransferError> = self.decode(
                        data: data,
                        decoder: endpoint.responseDecoder
                    )
                    switch result {
                        case .success(let value):
                            queue.asyncExecute { completion(.success(value)) }
                        case .failure:
                            let result: Result<APIErrorResponse, DataTransferError> = self.decode(
                                data: data,
                                decoder: endpoint.responseDecoder
                            )
                            switch result {
                                case .success(let value):
                                    queue.asyncExecute { completion(.failure(.errorResponse(value))) }
                                case .failure(let error):
                                    queue.asyncExecute { completion(.failure(error)) }
                            }
                    }
                case .failure(let error):
                    self.errorLogger.log(error: error)
                    let error = self.resolve(networkError: error)
                    queue.asyncExecute { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Private
    private func decode<T: Decodable>(
        data: Data?,
        decoder: ResponseDecoder
    ) -> Result<T, DataTransferError> {
        do {
            guard let data = data else { return .failure(.noResponse) }
            let result: T = try decoder.decode(data)
            return .success(result)
        } catch {
            self.errorLogger.log(error: error)
            return .failure(.parsing(error))
        }
    }
    
    private func resolve(networkError error: NetworkError) -> DataTransferError {
        let resolvedError = self.errorResolver.resolve(error: error)
        return resolvedError is NetworkError
        ? .networkFailure(error)
        : .resolvedNetworkFailure(resolvedError)
    }
}

// MARK: - Logger
final public class DefaultDataTransferErrorLogger: DataTransferErrorLogger {
    init() { }
    
    func log(error: Error) {
        printIfDebug("-------------")
        printIfDebug("\(error)")
    }
}

// MARK: - Error Resolver
public class DefaultDataTransferErrorResolver: DataTransferErrorResolver {
    init() { }
    public func resolve(error: NetworkError) -> Error {
        return error
    }
}

// MARK: - Response Decoders
public class JSONResponseDecoder: ResponseDecoder {
    private let jsonDecoder = JSONDecoder()
    init() { }
    public func decode<T: Decodable>(_ data: Data) throws -> T {
        return try jsonDecoder.decode(T.self, from: data)
    }
}

public class RawDataResponseDecoder: ResponseDecoder {
    init() { }
    
    enum CodingKeys: String, CodingKey {
        case `default` = ""
    }
    public func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self is Data.Type, let data = data as? T {
            return data
        } else {
            let context = DecodingError.Context(
                codingPath: [CodingKeys.default],
                debugDescription: "Expected Data type"
            )
            throw Swift.DecodingError.typeMismatch(T.self, context)
        }
    }
}
