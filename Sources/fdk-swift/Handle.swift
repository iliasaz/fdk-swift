//
//  Handle.swift
//
//
//  Created by Ilia Sazonov on 10/29/20.
//  Credits for ideas of Singleton pattern implementation in Swift to:
//  Reinder de Vries, https://learnappmaking.com/singletons-swift/
//  Bart Jacobs, https://cocoacasts.com/what-is-a-singleton-and-how-to-create-one-in-swift


import NIO
import NIOHTTP1
import Foundation

public protocol Fnable {
    func handler(ctx: Context, reqBody: HTTPBody?) -> HTTPBody?
}


// Singleton class to run the server
open class Handle
{
    private var udsFn: String?
    // for testing locally
    private let defaultHost = "127.0.0.1"
    private let defaultPort = 8888
    
    private enum BindTo {
        case ip(host: String, port: Int)
        case unixDomainSocket(path: String)
    }

    private var bindTarget: BindTo
    private var uds: String?
    private var group: MultiThreadedEventLoopGroup
    
    public static let main = Handle()

    private init()
    {
        udsFn = ProcessInfo.processInfo.environment["FN_LISTENER"]
        log("FN_LISTENER: \(udsFn)")
        
        // are we running local (ip socket) or in a Fn server (unix socket)?
        if let udsFn = udsFn {
            uds = udsFn.chopPrefix("unix:")!
            bindTarget = BindTo.unixDomainSocket(path: uds!)
        } else {
            bindTarget = BindTo.ip(host: defaultHost, port: defaultPort)
            log("Starting in local mode")
        }
        
        group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }
    
    public func run(_ fn: Fnable) {
        defer {
            log("Shutting down gracefully")
            try! group.syncShutdownGracefully()
        }
        
        let reuseAddrOpt = ChannelOptions.socket(
                                 SocketOptionLevel(SOL_SOCKET),
                                 SO_REUSEADDR)
        let socketBootstrap = ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(reuseAddrOpt, value: 1)
            
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(responder: Router(fn)))
                }
            }
            
            .childChannelOption(reuseAddrOpt, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        
        do {
            let channel = try { () -> Channel in
                switch bindTarget {
                case .ip(let host, let port):
                    return try socketBootstrap.bind(host: host, port: port).wait()
                case .unixDomainSocket(let path):
                    return try socketBootstrap.bind(unixDomainSocketPath: path).wait()
                }
            }()

            let localAddress: String
            guard let channelLocalAddress = channel.localAddress else {
                    fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
                }
            localAddress = "\(channelLocalAddress)"
            log("Server started and listening on \(localAddress)")
            
            // This will never unblock as we don't close the ServerChannel
            try channel.closeFuture.wait()
            log("Server closed")
        } catch {
            log("Unexpected error: \(error).")
        }
    }
}


var standardError = FileHandle.standardError

extension FileHandle : TextOutputStream {
  public func write(_ string: String) {
    guard let data = string.data(using: .utf8) else { return }
    self.write(data)
  }
}

public func log<T>(_ s:T) {
    print(s, to: &standardError)
}

extension DefaultStringInterpolation {
  mutating func appendInterpolation<T>(_ optional: T?) {
    appendInterpolation(String(describing: optional))
  }
}

extension String {
    func chopPrefix(_ prefix: String) -> String? {
        if self.unicodeScalars.starts(with: prefix.unicodeScalars) {
            return String(self[self.index(self.startIndex, offsetBy: prefix.count)...])
        } else {
            return nil
        }
    }

    func containsDotDot() -> Bool {
        for idx in self.indices {
            if self[idx] == "." && idx < self.index(before: self.endIndex) && self[self.index(after: idx)] == "." {
                return true
            }
        }
        return false
    }
}


