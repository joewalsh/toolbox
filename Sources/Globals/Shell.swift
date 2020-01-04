import NIO
import Foundation

public func todo(file: StaticString = #file) -> Never {
    let file = file.description.split(separator: "/").last ?? "<>"
    print("file: \(file)")
    fatalError()
}

public struct Shell {
    private init() {}
    
    @discardableResult
    public static func bash(_ input: String) throws -> String {
        return try Process.run("/bin/sh", args: ["-c", input])
    }

    public static func delete(_ path: String) throws {
        try bash("rm -rf \(path)")
    }

    public static func move(_ source: String, to destination: String) throws {
        try bash("mv \(source) \(destination)")
    }

    public static func makeDirectory(_ name: String) throws {
        try bash("mkdir -p \(name)")
    }

    public static func cwd() throws -> String {
        return try ProcessInfo.processInfo.environment["TEST_DIRECTORY"] ?? bash("pwd")
    }

    public static func allFiles(in dir: String? = nil) throws -> String {
        var command = "ls -a"
        if let dir = dir {
            command += " \(dir)"
        }
        return try Shell.bash(command)
    }

    public static func readFile(path: String) throws -> String {
        return try bash("cat \(path)").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func homeDirectory() throws -> String {
        return try bash("echo $HOME").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    public static func programExists(_ prgrm: String) throws -> Bool {
        _ = try Process.resolve(program: prgrm)
        return true
    }
}

/// Different types of process output.
public enum ProcessOutput {
    /// Standard process output.
    case stdout(Data)
    
    /// Standard process error output.
    case stderr(Data)
    
    public var out: String? {
        guard case .stdout(let o) = self else { return nil }
        return String(data: o, encoding: .utf8)
    }
    
    public var err: String? {
        guard case .stderr(let e) = self else { return nil }
        return String(data: e, encoding: .utf8)
    }
}

extension FileHandle {
    fileprivate func read() -> String {
        let data = readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}

extension Process {
    public static var running: Process?
}

extension Process {
    public static func run(_ program: String, args: [String]) throws -> String {
        // observers
        let out = Pipe()
        let err = Pipe()
        let `in` = Pipe()
        let task = try launchProcess(path: program, args, stdout: out, stderr: err, stdin: `in`)
        task.waitUntilExit()

        // read output
        let stdout = out.fileHandleForReading.read()
        let stderr = err.fileHandleForReading.read()
        guard stderr.isEmpty else { throw stderr }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    @discardableResult
    public static func run(_ program: String, args: [String], updates: @escaping (ProcessOutput) -> Void) throws -> Int32 {
        print("\(program) \(args.joined(separator: " "))")
        let process = try launchProcess(
            path: program,
            args,
            stdout: FileHandle.standardOutput,
            stderr: FileHandle.standardError,
            stdin: FileHandle.standardInput
        )
        Process.running = process
        process.waitUntilExit()
        Process.running = nil
        return process.terminationStatus
    }
    
    static func resolve(program: String) throws -> String {
        if program.hasPrefix("/") { return program }
        let path = try Shell.bash("which \(program)")
        guard path.hasPrefix("/") else { throw "unable to find executable for \(program)" }
        return path
    }
    
    /// Powers `Process.execute(_:_:)` methods. Separated so that `/bin/sh -c which` can run as a separate command.
    private static func launchProcess(path: String, _ arguments: [String], stdout: Any, stderr: Any, stdin: Any) throws -> Process {
        let path = try resolve(program: path)
        let process = Process()
        process.environment = ProcessInfo.processInfo.environment
        process.launchPath = path
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdin
        process.launch()
        return process
    }
}
