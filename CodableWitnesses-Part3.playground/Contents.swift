import Foundation

struct User {
    let id: UUID
    let name: String
    let ageInYears: Int
    let city: String?
    let isAdmin: Bool
}

extension User: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ageInYears = "age"
        case city
        case isAdmin = "is_admin"
    }
}

struct Decoding<Value> {
    var decode: (Decoder) throws -> Value
}

let sampleDecoding = Decoding<User> { decoder in
    let container = try decoder.container(keyedBy: User.CodingKeys.self)
    let id = try container.decode(UUID.self, forKey: .id)
    let name = try container.decode(String.self, forKey: .name)
    let age = try container.decode(Int.self, forKey: .ageInYears)
    
    let city = try container.decodeIfPresent(String.self, forKey: .city)
    let isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
    
    return User(id: id, name: name, ageInYears: age, city: city, isAdmin: isAdmin)
}


let json = """
    {
        "id": "dea9e624-de07-4f06-abb7-f88e54cd2752",
        "name": "Tim Cook",
        "age": 60
    }
    """

let decoder = JSONDecoder()
//let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)
//print(user)

import Combine

struct DecodingProxy: Decodable {
    let decoder: Decoder
    
    init(from decoder: Decoder) throws {
        self.decoder = decoder
    }
}

extension TopLevelDecoder {
    func decode<T>(_ input: Input, as decoding: Decoding<T>) throws -> T {
        let proxy = try decode(DecodingProxy.self, from: input)
        return try decoding.decode(proxy.decoder)
    }
}

print("UserTwo: ")
let userTwo = try decoder.decode(json.data(using: .utf8)!, as: sampleDecoding)
print(userTwo)

extension Decoding where Value: Decodable {
    static var singleValue: Decoding<Value> {
        .init { decoder in
            let container = try decoder.singleValueContainer()
            return try container.decode(Value.self)
        }
    }
    
    static func keyed<K: CodingKey>(as key: K) -> Decoding<Value> {
        .init { decoder in
            let container = try decoder.container(keyedBy: K.self)
            return try container.decode(Value.self, forKey: key)
        }
    }

    static var unkeyed: Decoding<Value> {
        .init { decoder in
            var container = try decoder.unkeyedContainer()
            return try container.decode(Value.self)
        }
    }
    
    static func optional<K: CodingKey>(as key: K) -> Decoding<Value?> {
        .init { decoder in
            let container = try decoder.container(keyedBy: K.self)
            return try container.decodeIfPresent(Value.self, forKey: key)
        }
    }
}

extension Decoding {
    func replaceNil<T>(with defaultValue: T) -> Decoding<T> where Value == T? {
        .init { decoder in
            try self.decode(decoder) ?? defaultValue
        }
    }
}


let idDecoding = Decoding<UUID>.keyed(as: User.CodingKeys.id)
let nameDecoding = Decoding<String>.keyed(as: User.CodingKeys.name)
let ageDecoding = Decoding<Int>.keyed(as: User.CodingKeys.ageInYears)
let cityDecoding = Decoding<String>.optional(as: User.CodingKeys.city)
let isAdminDecoding = Decoding<Bool>.optional(as: User.CodingKeys.isAdmin)
    .replaceNil(with: true)

extension Decoding {
    func map<T>(_ f: @escaping (Value) -> T) -> Decoding<T> {
        .init { decoder in
            try f(self.decode(decoder))
        }
    }
}

// Decoding<(UUID, String, Int)>

// (Array<A>, Array<B) -> Array<(A, B)>
let a = [1, 2, 3]
let b = [4, 5, 6]

func zip<A, B>(_ a: Decoding<A>, _ b: Decoding<B>) -> Decoding<(A, B)> {
    .init { decoder in
        try (a.decode(decoder), b.decode(decoder))
    }
}

let newDecoding = zip(idDecoding, nameDecoding)

func zip<A, B, C>(
    _ a: Decoding<A>,
    _ b: Decoding<B>,
    _ c: Decoding<C>) -> Decoding<(A, B, C)> {
    zip(zip(a, b), c).map { ($0.0, $0.1, $1)}
}

func zip<A, B, C, D>(
    _ a: Decoding<A>,
    _ b: Decoding<B>,
    _ c: Decoding<C>,
    _ d: Decoding<D>
) -> Decoding<(A, B, C, D)> {
    zip(zip(a, b), c, d).map { ($0.0, $0.1, $1, $2)}
}

func zip<A, B, C, D, E>(
    _ a: Decoding<A>,
    _ b: Decoding<B>,
    _ c: Decoding<C>,
    _ d: Decoding<D>,
    _ e: Decoding<E>
) -> Decoding<(A, B, C, D, E)> {
    zip(zip(a, b), c, d, e).map { ($0.0, $0.1, $1, $2, $3)}
}

let combinedUserDecoding = zip(idDecoding, nameDecoding, ageDecoding, cityDecoding, isAdminDecoding)
let newUserDecoding = combinedUserDecoding.map(User.init)

let userThree = try decoder.decode(json.data(using: .utf8)!, as: newUserDecoding)
print(userThree)

//let uppercaseNameUserDecoding = zip(idDecoding, nameDecoding.map { $0.uppercased() }, ageDecoding).map(User.init)
//
//let userFour = try decoder.decode(json.data(using: .utf8)!, as: uppercaseNameUserDecoding)
//print(userFour)

extension Decoding where Value == User {
    static let id = Decoding<UUID>.keyed(as: User.CodingKeys.id)
    static let name = Decoding<String>.keyed(as: User.CodingKeys.name)
    static let age = Decoding<Int>.keyed(as: User.CodingKeys.ageInYears)
    static let city = Decoding<String>.optional(as: User.CodingKeys.city)
    static let isAdmin = Decoding<Bool>.optional(as: User.CodingKeys.isAdmin)
        .replaceNil(with: true)
    
    static let defaultDecoding = zip(id, name, age, city, isAdmin).map(User.init)
}

let userFour: User = try decoder.decode(json.data(using: .utf8)!, as: .defaultDecoding)
print(userFour)
