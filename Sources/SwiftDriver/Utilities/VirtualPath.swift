//===--------------- VirtualPath.swift - Swift Virtual Paths --------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import TSCBasic

/// A virtual path.
public enum VirtualPath: Hashable {
  /// A relative path that has not been resolved based on the current working
  /// directory.
  case relative(RelativePath)

  /// An absolute path in the file system.
  case absolute(AbsolutePath)

  /// Standard input
  case standardInput

  /// Standard output
  case standardOutput

  /// A temporary file with the given name.
  case temporary(RelativePath)

  /// Form a virtual path which may be either absolute or relative.
  public init(path: String) throws {
    if let absolute = try? AbsolutePath(validating: path) {
      self = .absolute(absolute)
    } else {
      let relative = try RelativePath(validating: path)
      self = .relative(relative)
    }
  }

  /// The name of the path for presentation purposes.
  public var name: String { description }

  /// The extension of this path, for relative or absolute paths.
  public var `extension`: String? {
    switch self {
    case .relative(let path), .temporary(let path):
      return path.extension

    case .absolute(let path):
      return path.extension

    case .standardInput, .standardOutput:
      return nil
    }
  }

  /// Whether this virtual path is to a temporary.
  public var isTemporary: Bool {
    switch self {
    case .relative(_):
      return false

    case .absolute(_):
      return false

    case .standardInput, .standardOutput:
      return false

    case .temporary(_):
      return true
    }
  }

  public var absolutePath: AbsolutePath? {
    switch self {
    case let .absolute(absolutePath): return absolutePath
    default: return nil
    }
  }

  /// Normalized string representation. This string is never empty.
  /// - Precondition: self is not `standardInput` or `standardOutput`
  public var pathString: String {
    switch self {
    case .relative(let path):
      return path.pathString
    case .absolute(let path):
      return path.pathString
    case .standardInput, .standardOutput:
      preconditionFailure("standardInput and standardOutput do not have a pathString")
    case .temporary(let path):
      return path.pathString
    }
  }

  /// Parent directory, uses .. for relative paths.
  /// - Precondition: self is not `standardInput` or `standardOutput`
  public var parentDirectory: VirtualPath {
    switch self {
    case .absolute(let path):
      return .absolute(path.parentDirectory)
    case .relative(let path):
      return .relative(path.appending(component: ".."))
    case .temporary(let path):
      return .temporary(path.appending(component: ".."))
    case .standardInput, .standardOutput:
      preconditionFailure("standardInput and standardOutput do not have a parentDirectory")
    }
  }

  /// Retrieve the basename of the path without the extension.
  public var basenameWithoutExt: String {
    switch self {
    case .absolute(let path):
      return path.basenameWithoutExt
    case .relative(let path), .temporary(let path):
      return path.basenameWithoutExt
    case .standardInput, .standardOutput:
      return ""
    }
  }

  /// Returns the virtual path with an additional literal component appended.
  ///
  /// This should not be used with `.standardInput` or `.standardOutput`.
  public func appending(component: String) -> VirtualPath {
    switch self {
    case .absolute(let path):
      return .absolute(path.appending(component: component))
    case .relative(let path):
      return .relative(path.appending(component: component))
    case .temporary(let path):
      return .temporary(path.appending(component: component))
    case .standardInput, .standardOutput:
      assertionFailure("Can't append path component to standard in/out")
      return self
    }
  }

  /// Returns the virtual path with additional literal components appended.
  ///
  /// This should not be used with `.standardInput` or `.standardOutput`.
  public func appending(components: String...) -> VirtualPath {
    // Need to copy implemations here because swift doesn't support forwarding variadic arguments
    switch self {
    case .absolute(let path):
      return .absolute(components.reduce(path, { path, name in
          path.appending(component: name)
      }))
    case .relative(let path):
      return .relative(RelativePath(path.pathString + "/" + components.joined(separator: "/")))
    case .temporary(let path):
      return .temporary(RelativePath(path.pathString + "/" + components.joined(separator: "/")))
    case .standardInput, .standardOutput:
      assertionFailure("Can't append path component to standard in/out")
      return self
    }
  }
}

extension VirtualPath: Codable {
  private enum CodingKeys: String, CodingKey {
    case relative, absolute, standardInput, standardOutput, temporary
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .relative(let a1):
      var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .relative)
      try unkeyedContainer.encode(a1)
    case .absolute(let a1):
      var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .absolute)
      try unkeyedContainer.encode(a1)
    case .standardInput:
      _ = container.nestedUnkeyedContainer(forKey: .standardInput)
    case .standardOutput:
      _ = container.nestedUnkeyedContainer(forKey: .standardOutput)
    case .temporary(let a1):
      var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .temporary)
      try unkeyedContainer.encode(a1)
    }
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard let key = values.allKeys.first(where: values.contains) else {
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Did not find a matching key"))
    }
    switch key {
    case .relative:
      var unkeyedValues = try values.nestedUnkeyedContainer(forKey: key)
      let a1 = try unkeyedValues.decode(RelativePath.self)
      self = .relative(a1)
    case .absolute:
      var unkeyedValues = try values.nestedUnkeyedContainer(forKey: key)
      let a1 = try unkeyedValues.decode(AbsolutePath.self)
      self = .absolute(a1)
    case .standardInput:
      self = .standardInput
    case .standardOutput:
      self = .standardOutput
    case .temporary:
      var unkeyedValues = try values.nestedUnkeyedContainer(forKey: key)
      let a1 = try unkeyedValues.decode(RelativePath.self)
      self = .temporary(a1)
    }
  }
}

extension VirtualPath: CustomStringConvertible {
  public var description: String {
    switch self {
    case .relative(let path):
      return path.pathString

    case .absolute(let path):
      return path.pathString

    case .standardInput, .standardOutput:
      return "-"

    case .temporary(let path):
      return path.pathString
    }
  }
}

extension VirtualPath {
  /// Replace the extension of the given path with a new one based on the
  /// specified file type.
  public func replacingExtension(with fileType: FileType) throws -> VirtualPath {
    let pathString: String
    if let ext = self.extension {
      pathString = String(name.dropLast(ext.count + 1))
    } else {
      pathString = name
    }

    return try VirtualPath(path: pathString.appendingFileTypeExtension(fileType))
  }
}

// FIXME: These belong in TSCBasic
extension RelativePath {
  /// Returns the relative path with an additional literal component appended.
  ///
  /// This method accepts pseudo-path like '.' or '..', but should not contain "/".
  public func appending(component name: String) -> RelativePath {
      assert(!name.contains("/"), "\(name) is invalid path component")

      switch name {
      case "", ".":
          return self
      default:
        return RelativePath(pathString + "/" + name)
      }
  }

  /// Returns the absolute path with additional literal components appended.
  public func appending(components names: String...) -> RelativePath {
    return RelativePath(pathString + "/" + names.joined(separator: "/"))
  }
}

enum FileSystemError: Swift.Error {
  case noCurrentWorkingDirectory
  case cannotResolveTempPath(RelativePath)
  case cannotResolveStandardInput
  case cannotResolveStandardOutput
}

extension TSCBasic.FileSystem {
  private func resolvingVirtualPath<T>(
    _ path: VirtualPath,
    apply f: (AbsolutePath) throws -> T
  ) throws -> T {
    switch path {
    case let .absolute(absPath):
      return try f(absPath)
    case let .relative(relPath):
      guard let cwd = currentWorkingDirectory else {
        throw FileSystemError.noCurrentWorkingDirectory
      }
      return try f(.init(cwd, relPath))
    case let .temporary(relPath):
      throw FileSystemError.cannotResolveTempPath(relPath)
    case .standardInput:
      throw FileSystemError.cannotResolveStandardInput
    case .standardOutput:
      throw FileSystemError.cannotResolveStandardOutput
    }
  }

  func exists(_ path: VirtualPath) -> Bool {
    do {
      return try resolvingVirtualPath(path, apply: exists)
    } catch {
      return false
    }
  }

  func isFile(_ path: VirtualPath) -> Bool {
    do {
      return try resolvingVirtualPath(path, apply: isFile)
    } catch {
      return false
    }
  }
}
