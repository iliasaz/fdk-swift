//
//  HTTPHandler.swift
//  
//
//  Created by Ilia Sazonov on 10/29/20.
//  Credits for NIO, NIOHTTP1, piece of code and ideas to the author of:
//  https://github.com/apple/swift-nio/blob/main/Sources/NIOHTTP1Server/main.swift
// 


import NIO
import NIOHTTP1
import Foundation

private func httpResponseHead(request: HTTPRequestHead, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders()) -> HTTPResponseHead {
    var head = HTTPResponseHead(version: request.version, status: status, headers: headers)
    let connectionHeaders: [String] = head.headers[canonicalForm: "connection"].map { $0.lowercased() }

    if !connectionHeaders.contains("keep-alive") && !connectionHeaders.contains("close") {
        // the user hasn't pre-set either 'keep-alive' or 'close', so we might need to add headers

        switch (request.isKeepAlive, request.version.major, request.version.minor) {
        case (true, 1, 0):
            // HTTP/1.0 and the request has 'Connection: keep-alive', we should mirror that
            head.headers.add(name: "Connection", value: "keep-alive")
        case (false, 1, let n) where n >= 1:
            // HTTP/1.1 (or treated as such) and the request has 'Connection: close', we should mirror that
            head.headers.add(name: "Connection", value: "close")
        default:
            // we should match the default or are dealing with some HTTP that we don't support, let's leave as is
            ()
        }
    }
    return head
}

 final class HTTPHandler: ChannelInboundHandler {

    internal typealias InboundIn = HTTPServerRequestPart
    internal typealias OutboundOut = HTTPServerResponsePart
    
    // A temporary local HTTPRequest that is used to accumulate data into
    private var request: HTTPRequest?

    // The Responder type that responds to requests
    private let responder: Router

    init(responder: Router) {
        self.responder = responder
    }

    private var buffer: ByteBuffer! = nil
    private var keepAlive = false
//    private var state = State.idle

    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        switch part {
        case .head(let requestHead):
            self.keepAlive = requestHead.isKeepAlive

            let contentLength: Int
            let body: ByteBuffer?

            // We need to check the content length to reserve memory for the body
            if let length = requestHead.headers["content-length"].first {
              contentLength = Int(length) ?? 0
            } else {
              contentLength = 0
            }

            // Disallows bodies over 50 megabytes of data
            // 50MB is a huge amount of data to receive and accumulate in one request
            if contentLength > 50_000_000 {
                context.close(promise: nil)
              return
            }

            // Allocates the memory for accumulation
            if contentLength > 0 {
              body = context.channel.allocator.buffer(capacity: contentLength)
            } else {
              body = nil
            }

            self.request = HTTPRequest(eventLoop: context.eventLoop,
                                       head: requestHead,
                                       bodyBuffer: body)

        case .body(var newData):
            // Appends new data to the already reserved buffer
            self.request?.bodyBuffer?.writeBuffer(&newData)

        case .end:
            guard let request = request else { return }
            // Responds to the request
            let response = responder.respond(to: request)
            self.request = nil

            // Writes the response when done
            self.writeResponse(response, to: context)
        }
    }

    @discardableResult
    private func writeResponse(_ response: EventLoopFuture<HTTPResponse>, to context: ChannelHandlerContext) -> EventLoopFuture<Void> {

        func writeBody(_ buffer: ByteBuffer) {
            context.write(self.wrapOutboundOut(.body(IOData.byteBuffer(buffer))), promise: nil)
        }

        func writeHead(_ head: HTTPResponseHead) {
            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
        }

        let responded = response.map { response -> Void in
            var responseHead = response.head
            responseHead.headers.remove(name: "content-length")
            if let body = response.body {
                let buffer = body.buffer
                responseHead.headers.add(name: "content-length", value: String(buffer.writerIndex))

                if let mimeType = body.mimeType {
                    responseHead.headers.remove(name: "content-type")
                    responseHead.headers.add(name: "content-type", value: mimeType)
                }

                writeHead(response.head)
                writeBody(buffer)
            } else {
                writeHead(response.head)
            }
        }.flatMap {
            return context.writeAndFlush(self.wrapOutboundOut(.end(nil)))
        }

        responded.whenComplete {_ in
            if self.keepAlive {
                context.close(promise: nil)
            }
        }

        return responded
    }

    private func completeResponse(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        let promise = self.keepAlive ? promise : (promise ?? context.eventLoop.makePromise())
        if !self.keepAlive {
            promise!.futureResult.whenComplete { (_: Result<Void, Error>) in context.close(promise: nil) }
        }
        context.writeAndFlush(self.wrapOutboundOut(.end(trailers)), promise: promise)
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    
//    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//        let reqPart = unwrapInboundIn(data)
//
//        switch reqPart {
//        case .head(let header):
//          print("req:", header)
//
//        // ignore incoming content to keep it micro :-)
//        case .body, .end: break
//        }
//    }
    
}
