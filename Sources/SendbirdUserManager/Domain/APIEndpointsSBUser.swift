//
//  APIEndpointsSBUser.swift
//  
//
//  Created by Yongun Lim on 2023/11/24.
//

import Foundation

public struct APIEndpointsSBUser {
    
    static func getUser(with userId: String) -> Endpoint<SBUser> {
        return Endpoint(
            path: "v3/users/\(userId)",
            method: .get
        )
    }
    
    static func getUsers(with nickName: String) -> Endpoint<SBUserList> {
        return Endpoint(
            path: "v3/users",
            method: .get,
            queryParameters: !nickName.isEmpty ? ["nickname" : nickName,
                                                  "limit" : 10] : ["limit" : 10]
        )
    }
    
    static func createUser(with param: UserCreationParams) -> Endpoint<SBUser> {
        return Endpoint(
            path: "v3/users",
            method: .post,
            bodyParametersEncodable: param
        )
    }
    
    static func updateUser(with param: UserUpdateParams) -> Endpoint<SBUser> {
        return Endpoint(
            path: "v3/users/\(param.userId)",
            method: .put,
            bodyParametersEncodable: param
        )
    }
}
