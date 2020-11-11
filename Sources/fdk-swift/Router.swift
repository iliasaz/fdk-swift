//
//  Router.swift
//  
//
//  Created by Ilia Sazonov on 10/29/20.
//  Credits for ideas and example to:
//  Joannis Orlandos, https://www.raywenderlich.com/1124580-swiftnio-a-simple-guide-to-async-on-the-server
//

import NIO
import NIOHTTP1
import Foundation

internal struct Router: HTTPResponder {
    private var fn: Fnable?
    private let defaultResponse = HTTPResponse(status: .ok, body: HTTPBody(stringLiteral: "default ok"))
    
    init(_ fn: Fnable?) {
        self.fn = fn
    }
    
    func respond(to request: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        switch request.head.method {
            // Fn supports only POST method internally, and the only rounte is /call
            case .POST, .GET:
                guard request.head.uri.starts(with: "/call") else {break}
                /// HTTP Gateway Protocol Extension
                let ctx: Context = Context(
                    callId: request.head.headers.first(name: "Fn-Call-Id")!,
                    deadLine: request.head.headers.first(name: "Fn-Deadline")!,
                    method: request.head.headers.first(name: "Fn-Http-Method")!,
                    requestURL: request.head.headers.first(name: "Fn-Http-Request-Url")!,
                    headers: request.head.headers
                )
                guard let fn = fn else {return request.eventLoop.makeSucceededFuture(defaultResponse)}
                let respBody = fn.handler(ctx: ctx, reqBody: request.body)
                let ok = HTTPResponse(status: .ok, body: respBody)
                return request.eventLoop.makeSucceededFuture(ok)
            default:
                break
        }
        // either not a POST or not a /call
        let notfound = HTTPResponse(status: .notFound, body: HTTPBody(text: "Not found"))
        return request.eventLoop.makeSucceededFuture(notfound)
    }
}
