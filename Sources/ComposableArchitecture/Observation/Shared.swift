import Foundation

@Perceptible
@dynamicMemberLookup
@propertyWrapper
public final class Shared<Value> {
  private var currentValue: Value
  private var previousValue: Value
  private let lock = NSRecursiveLock()

  public var wrappedValue: Value {
    get {
      self.lock.sync {
        if SharedLocals.isAsserting {
          self.previousValue
        } else {
          self.currentValue
        }
      }
    }
    set {
      self.lock.sync {
        @Dependency(\.context) var context
        guard context != .test else {
          if SharedLocals.isAsserting {
            self.previousValue = newValue
          } else {
            if SharedLocals.changeTracker == nil {
              self.previousValue = self.currentValue
            }
            self.currentValue = newValue
            SharedLocals.changeTracker?.onDeinit(id: self) { file, line in
              func open<T: Equatable>(_: T.Type) {
                guard
                  let currentValue = self.currentValue as? T,
                  let previousValue = self.previousValue as? T
                else { return }
                //                XCTAssertNoDifference(currentValue, previousValue, file: file, line: line)
              }
              if let type = Value.self as? any Equatable.Type {
                open(type)
              }
            }
          }
          return
        }
        self.currentValue = newValue
      }
    }
  }

  public var projectedValue: Shared {
    self
  }

  public init(_ value: Value) {
    self.currentValue = value
    self.previousValue = value
  }

  //  public convenience init(wrappedValue: Value) {
  //    self.init(wrappedValue)
  //  }

  public subscript<Member>(dynamicMember keyPath: WritableKeyPath<Value, Member>) -> Member {
    get { self.wrappedValue[keyPath: keyPath] }
    set { self.wrappedValue[keyPath: keyPath] = newValue }
  }

  public func copy() -> Shared {
    Shared(self.wrappedValue)
  }
}

// TODO: Write tests that try to break equatable/hashable invariants.

extension Shared: Equatable where Value: Equatable {
  public static func == (lhs: Shared, rhs: Shared) -> Bool {
    if SharedLocals.isAsserting, lhs === rhs {
      return lhs.previousValue == rhs.currentValue
    } else {
      return lhs.wrappedValue == rhs.wrappedValue
    }
  }
}

extension Shared: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    // TODO: hasher.combine(ObjectIdentifier(self))
    hasher.combine(self.wrappedValue)
  }
}

extension Shared: Identifiable where Value: Identifiable {
  public var id: Value.ID {
    self.wrappedValue.id
  }
}
extension Shared: Decodable where Value: Decodable {
  public convenience init(from decoder: Decoder) throws {
    do {
      self.init(try decoder.singleValueContainer().decode(Value.self))
    } catch {
      self.init(try .init(from: decoder))
    }
  }
}
extension Shared: Encodable where Value: Encodable {
  public func encode(to encoder: Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.wrappedValue)
    } catch {
      try self.wrappedValue.encode(to: encoder)
    }
  }
}

extension Shared: _CustomDiffObject {
  public var _customDiffValues: (Any, Any) {
    (self.previousValue, self.currentValue)
  }
}

extension Shared: @unchecked Sendable where Value: Sendable {}

extension Shared: TestDependencyKey where Value: TestDependencyKey {
  public static var testValue: Shared<Value.Value> {
    Shared<Value.Value>(Value.testValue)
  }
}
extension Shared: DependencyKey where Value: DependencyKey {
  public static var liveValue: Shared<Value.Value> {
    Shared<Value.Value>(Value.liveValue)
  }
}

enum SharedLocals {
  @TaskLocal static var changeTracker: ChangeTracker?
  @TaskLocal static var isAsserting = false
}

final class ChangeTracker {
  private let file: StaticString
  private let line: UInt
  private var onDeinit: [ObjectIdentifier: (_ file: StaticString, _ line: UInt) -> Void] = [:]
  var isEmpty: Bool { self.onDeinit.isEmpty }
  init(file: StaticString, line: UInt) {
    self.file = file
    self.line = line
  }
  deinit { self.onDeinit.values.forEach { $0(self.file, self.line) } }
  func onDeinit<T: AnyObject>(
    id: T,
    operation: @escaping (_ file: StaticString, _ line: UInt) -> Void
  ) {
    self.onDeinit[ObjectIdentifier(id)] = operation
  }
}