import Vapor

public struct CloudUser: Content {
    public let id: UUID
    public let firstName: String
    public let lastName: String
    public let email: String
}

/// The User API is a specialized resource access controller
/// since most of its endpoints have specialized
/// functionality
public struct UserApi {

    public let container: Container
    public init(on container: Container) {
        self.container = container
    }

    public func signup(
        email: String,
        firstName: String,
        lastName: String,
        organizationName: String,
        password: String
    ) -> Future<CloudUser> {
        struct Package: Content {
            let email: String
            let firstName: String
            let lastName: String
            let organizationName: String
            let password: String
        }
        let content = Package(
            email: email,
            firstName: firstName,
            lastName: lastName,
            organizationName: organizationName,
            password: password
        )

        let client = makeClient(on: container)
        let response = client.send(.POST, to: userUrl) { try $0.content.encode(content) }
        return response.become(CloudUser.self)
    }

    public func login(
        email: String,
        password: String
    ) -> Future<Token> {
        let combination = email + ":" + password
        let data = combination.data(using: .utf8)!
        let encoded = data.base64EncodedString()

        let headers: HTTPHeaders = [
            "Authorization": "Basic \(encoded)"
        ]
        let client = makeClient(on: container)
        let response = client.send(.POST, headers: headers, to: loginUrl)
        return response.become(Token.self)
    }

    public func me(token: Token) -> Future<CloudUser> {
        let access = CloudUser.Access(with: token, baseUrl: meUrl, on: container)
        return access.view()
    }

    public func reset(email: String) -> Future<Void> {
        struct Package: Content {
            let email: String
        }
        let content = Package(email: email)
        let client = makeClient(on: container)
        let response = client.send(.POST, to: resetUrl) { try $0.content.encode(content) }
        return response.validate().void()
    }
}
