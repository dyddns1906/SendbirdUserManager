//
//  SBUserService.swift
//  
//
//  Created by Yongun Lim on 2023/11/22.
//

import Foundation

public enum SBUserManagerError: Error {
    case accessLimit
    case createPartialFailed
    case needToNotEmptyParams
    case dataTransferError(DataTransferError)
}

final public class SBUserService: SBUserManager {
    static let shared = SBUserService()
    
    public var networkClient: SBNetworkClient
    public var userStorage: SBUserStorage
    
    private let queue: DispatchQueue
    
    private let requestManager: RequestManager
    
    public init() {
        self.networkClient = DefaultDataTransferService()
        self.userStorage = UserRepository()
        self.queue = DispatchQueue(label: "com.SendbirdUserManager.SBUserService", attributes: .concurrent)
        self.requestManager = RequestManager(maxConcurrentRequests: 10, queue: queue)
    }
    
    public init(networkService: SBNetworkClient,
                queue: DispatchQueue = DispatchQueue.global(qos: .background)) {
        self.networkClient = networkService
        self.userStorage = UserRepository()
        self.queue = queue
        self.requestManager = RequestManager(maxConcurrentRequests: 10, queue: queue)
    }
    
    public func initApplication(applicationId: String, apiToken: String) {
        if self.networkClient.networkService.config.applicationId != applicationId {
           let _ = self.userStorage.removeAll()
        }
        self.networkClient.networkService.config.applicationId = applicationId
        self.networkClient.networkService.config.apiToken = apiToken
    }
    
    public func createUser(params: UserCreationParams, completionHandler: ((UserResult) -> Void)?) {
        self.requestManager.enqueueRequest({ [weak self] in
            guard let self else { return }
            let endpoint = APIEndpointsSBUser.createUser(with: params)
            self.networkClient.request(with: endpoint,
                                       on: self.queue) { result in
                switch result {
                    case .success(let item):
                        completionHandler?(.success(item))
                        self.userStorage.upsertUser(item)
                    case .failure(let error):
                        print(error.localizedDescription)
                        completionHandler?(.failure(SBUserManagerError.dataTransferError(error)))
                }
            }
        }, failure: {
            self.queue.async {
                completionHandler?(.failure(SBUserManagerError.accessLimit))
            }
        })
    }
    
    public func createUsers(params: [UserCreationParams], completionHandler: ((UsersResult) -> Void)?) {
        guard params.count < 11 else {
            completionHandler?(.failure(SBUserManagerError.accessLimit))
            return
        }
        
        var userList: [SBUser] = []
        let dispatchGroup = DispatchGroup()
        for user in params {
            dispatchGroup.enter()
            createUser(params: user) { result in
                switch result {
                    case .success(let item):
                        userList.append(item)
                    case .failure(let error):
                        print(error.localizedDescription)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: queue) {
            if userList.count == params.count {
                completionHandler?(.success(userList))
            } else {
                completionHandler?(.failure(SBUserManagerError.createPartialFailed))
            }
        }
    }
    
    public func updateUser(params: UserUpdateParams, completionHandler: ((UserResult) -> Void)?) {
        requestManager.enqueueRequest({ [weak self] in
            guard let self = self else { return }
            let endpoint = APIEndpointsSBUser.updateUser(with: params)
            self.networkClient.request(with: endpoint,
                                       on: queue) { result in
                switch result {
                    case .success(let item):
                        self.queue.async {
                            completionHandler?(.success(item))
                        }
                        self.userStorage.upsertUser(item)
                    case .failure(let error):
                        print(error.localizedDescription)
                        self.queue.async {
                            completionHandler?(.failure(SBUserManagerError.dataTransferError(error)))
                        }
                }
            }
        }, failure: {
            self.queue.async {
                completionHandler?(.failure(SBUserManagerError.accessLimit))
            }
        })
    }
    
    public func getUser(userId: String, completionHandler: ((UserResult) -> Void)?) {
        guard !userId.isEmpty else {
            completionHandler?(.failure(SBUserManagerError.needToNotEmptyParams))
            return
        }
        requestManager.enqueueRequest({ [weak self] in
            guard let self = self else { return }
            if let users = self.userStorage.getUser(for: userId) {
                completionHandler?(.success(users))
            } else {
                let endpoint = APIEndpointsSBUser.getUser(with: userId)
                self.networkClient.request(with: endpoint,
                                           on: self.queue) { result in
                    switch result {
                        case .success(let item):
                            self.queue.async {
                                completionHandler?(.success(item))
                            }
                        case .failure(let error):
                            print(error.localizedDescription)
                            self.queue.async {
                                completionHandler?(.failure(SBUserManagerError.dataTransferError(error)))
                            }
                    }
                }
            }
        }, failure: {
            self.queue.async {
                completionHandler?(.failure(SBUserManagerError.accessLimit))
            }
        })
    }
    
    public func getUsers(nicknameMatches: String, completionHandler: ((UsersResult) -> Void)?) {
        let nicknameMatches = nicknameMatches.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard !nicknameMatches.isEmpty else {
            completionHandler?(.failure(SBUserManagerError.needToNotEmptyParams))
            return
        }
        requestManager.enqueueRequest({ [weak self] in
            guard let self = self else { return }
            let users = userStorage.getUsers(for: nicknameMatches)
            if !users.isEmpty {
                self.queue.async {
                    completionHandler?(.success(users))
                }
            } else {
                let endpoint = APIEndpointsSBUser.getUsers(with: nicknameMatches)
                self.networkClient.request(with: endpoint,
                                           on: queue) { result in
                    switch result {
                        case .success(let item):
                            self.queue.async {
                                completionHandler?(.success(item.users ?? []))
                            }
                        case .failure(let error):
                            print(error.localizedDescription)
                            self.queue.async {
                                completionHandler?(.failure(SBUserManagerError.dataTransferError(error)))
                            }
                    }
                }
            }
        }, failure: {
            self.queue.async {
                completionHandler?(.failure(SBUserManagerError.accessLimit))
            }
        })
    }
}

