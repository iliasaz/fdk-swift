// TODO: rewrite this implementation to avoid a potential license conflict with the below statement

/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import NIO
import NIOHTTP1
import Foundation

/// A simplified HTTPRequest type as you'll come across in many web frameworks
public struct HTTPRequest {
  /// The EventLoop is stored in the HTTP request so that promises can be created
  public let eventLoop: EventLoop

  /// The head contains all request "metadata" like the URI and request method
  ///
  /// The headers are also found in the head, and they are often used to describe the body as well
  public let head: HTTPRequestHead

  /// The bodyBuffer is internal because the HTTPBody API is exposed for simpler access
  internal var bodyBuffer: ByteBuffer?

  /// This initializer is necessary because the `bodyBuffer` is a private property
  init(eventLoop: EventLoop, head: HTTPRequestHead, bodyBuffer: ByteBuffer?) {
    self.eventLoop = eventLoop
    self.head = head
    self.bodyBuffer = bodyBuffer
  }

  /// The body is a wrapped used to provide simpler access to body data like JSON
  public var body: HTTPBody? {
    guard let bodyBuffer = bodyBuffer else {
      return nil
    }

    return HTTPBody(buffer: bodyBuffer)
  }
}

/// An HTTPResponse as you'll commonly see in web frameworks. This response can be a failure or success case depending on the status code in the `head`
public struct HTTPResponse {
  /// The success or failure status and HTTP headers
  public let head: HTTPResponseHead

  /// The body which contains any data you want to send back to the client
  /// This can be HTML, an image or JSON among many other data types
  public let body: HTTPBody?

  /// Creates a new response using a status code, headers and body
  /// If no headers are provided, an empty list will be assumed
  ///
  /// The body's content-length and mimeType will overwrite those that may be present in the header
  public init(status: HTTPResponseStatus,
              headers: HTTPHeaders = HTTPHeaders(),
              body: HTTPBody?) {
    self.head = HTTPResponseHead(version: HTTPVersion(major: 1, minor: 1),
                                 status: status,
                                 headers: headers)
    self.body = body
  }
}

/// The contents of the request or response. The type of information can be read from the request/response's HTTP headers
public struct HTTPBody: ExpressibleByStringLiteral {
  /// Used to create new ByteBuffers
  private static let allocator = ByteBufferAllocator()

  /// The binary data in this body
  internal let buffer: ByteBuffer

  /// The mime type of the data stored in this HTTPBody
  /// Used to set the `content-type` header when sending back a response
  public let mimeType: String?

  /// Creates a new body from a binary `NIO.ByteBuffer`
  public init(buffer: ByteBuffer, mimeType: String? = nil) {
    self.buffer = buffer
    self.mimeType = mimeType
  }

  /// Creates a new text/plain body containing the text
  public init(text: String) {
    var buffer = HTTPBody.allocator.buffer(capacity: text.utf8.count)
    buffer.writeString(text)
    self.buffer = buffer
    self.mimeType = "text/plain"
  }

  /// Creates a new body from a binary `Foundation.Data`
  public init(data: Data, mimeType: String? = nil) {
    var buffer = HTTPBody.allocator.buffer(capacity: data.count)
    buffer.writeBytes(data)
    self.buffer = buffer
    self.mimeType = mimeType
  }

  /// Encodes an object to JSON with optional pretty printing as a response
  public init<E: Encodable>(json: E, pretty: Bool = false) throws {
    let encoder = JSONEncoder()

    if pretty {
      encoder.outputFormatting = .prettyPrinted
    }

    let data = try encoder.encode(json)

    self.init(data: data, mimeType: "application/json")
  }

  /// The same as the `text` initializer which allows this HTTPBody to be initialized from a String literal
  public init(stringLiteral value: String) {
    self.init(text: value)
  }

  /// Reads the Data from this body
  public var data: Data {
    return buffer.withUnsafeReadableBytes { buffer -> Data in
      let buffer = buffer.bindMemory(to: UInt8.self)
      return Data.init(buffer: buffer)
    }
  }

  /// Decodes the body as JSON into the provided Decodable type
  public func decodeJSON<D: Decodable>(as type: D.Type) throws -> D {
    return try JSONDecoder().decode(type, from: data)
  }
}

/// Any type that can respond to HTTP requests
protocol HTTPResponder {
  func respond(to request: HTTPRequest) -> EventLoopFuture<HTTPResponse>
}
