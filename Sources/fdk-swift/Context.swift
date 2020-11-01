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
    let callId: String?
    let deadLine: String?
    let method: String?
    let requestURL: String?
    let headers: HTTPHeaders
}
