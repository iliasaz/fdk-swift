//
//  Context.swift
//  
//
//  Created by Ilia Sazonov on 10/30/20.
//

import NIO
import NIOHTTP1
import Foundation


public struct Context {
    public let callId: String
    public let deadLine: String
    public let method: String
    public let requestURL: String
    public let headers: HTTPHeaders
    public lazy var urlComponents: URLComponents? = URLComponents(string: requestURL)
    public lazy var contentType: String? = headers.first(name: "Content-Type")
}
