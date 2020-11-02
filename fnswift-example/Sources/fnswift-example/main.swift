//  This is user function code
//


import fdk_swift

struct MyFunction: Fnable {
    func handler(ctx: Context, reqBody: HTTPBody?) -> HTTPBody? {
        log("I'm running")
        let result = HTTPBody(stringLiteral: "Hello, world, I'm running!")
        return result
    }
}

let myFunc = MyFunction()

Handle.main.run(myFunc)

