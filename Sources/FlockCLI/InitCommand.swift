//
//  InitCommand.swift
//  FlockCLI
//
//  Created by Jake Heiser on 10/26/16.
//
//

import Rainbow
import SwiftCLI

class InitCommand: FlockCommand {
  
    let name = "init"
    let shortDescription = "Initializes Flock in the current directory"
    
    func execute() throws {
        guard !flockIsInitialized else {
            throw CLI.Error(message: "Error: ".red + "Flock has already been initialized")
        }
        
        print("Creating Flock.swift")
        
        try flockPath.write(defaultFlockfile)
        
        print("Building dependencies")
        do {
            try Beak.execute(args: ["run", "--path", flockPath.string])
        } catch {
            print("Dependency build failed".red)
            return
        }
        
        print("Successfully initialized Flock".green)
    }
    
}

let defaultFlockfile = """
// beak: jakeheis/Flock @ .branch("beak")

import Flock
import Foundation
import Shout

// MARK: - Environments

let myProject = Project(
    name: "MyProject",
    repoURL: "https://github.com/me/Project"
)

public let production = Environment(
    project: myProject,
    name: "production",
    servers: [
        ServerLogin(ip: "1.1.1.1", user: "deploy", auth: SSHKey(privateKey: "aKey"))
    ]
)

//
// Uncomment if you have a staging environment:
//
/*
public let staging = Environment(
    project: myProject,
    name: "staging",
    servers: [
        ServerLogin(ip: "1.1.1.1", user: "deploy", auth: SSHKey(privateKey: "aKey"))
    ]
)
*/

// MARK: - Tasks

/// Deploy the project
public func deploy(env: Environment = production) {
    Flock.run(in: env) { (server) in
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYYMMddHHMMSS"
        let timestamp = formatter.string(from: Date())
        
        let cloneDirectory = "\\(env.releasesDirectory)/\\(timestamp)"
        try server.execute("git clone --depth 1 \\(env.project.repoURL) \\(cloneDirectory)")
        
        // Uncomment if using swiftenv:
        // try swiftenv(on: server, env: env)
        
        try server.execute("swift build -C \\(cloneDirectory) -c release")
        
        try server.execute("ln -sfn \\(cloneDirectory) \\(env.currentDirectory)")
        
        try restartServer(on: server, env: env)
    }
}

/// Start the server
public func startServer(env: Environment = production) {
    Flock.run(in: env) { (server) in
        try startServer(on: server, env: env)
    }
}

/// Print the status of the server
public func status(env: Environment = production) {
    Flock.run(in: env) { (server) in
        try status(on: server, env: env)
    }
}

/// Stop the server
public func stopServer(env: Environment = production) {
    Flock.run(in: env) { (server) in
        try stopServer(on: server, env: env)
    }
}

/// Restart the server
public func restartServer(env: Environment = production) {
    Flock.run(in: env) { (server) in
        try restartServer(on: server, env: env)
    }
}

// MARK: - Helpers

func swiftenv(on server: Server, env: Environment) throws {
    guard server.commandExists("swiftenv") else {
        throw TaskError(message: "swiftenv not found; ensure it is installed and executable")
    }
    
    guard let fileVersion = try? String(contentsOfFile: ".swift-version", encoding: .utf8) else {
        throw TaskError(message: "You must specify which Swift version to use in a `.swift-version` file.")
    }
    
    let swiftVersion = fileVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    
    let existingSwifts = try server.capture("swiftenv versions")
    if !existingSwifts.contains(swiftVersion) {
        try server.execute("swiftenv install \\(swiftVersion)")
        try server.execute("swiftenv rehash")
    }
}

func startServer(on server: Server, env: Environment) throws {
    //
    // Uncomment the following if you *are* using supervisord:
    //
    /*
    try executeSupervisor(command: "start", server: server, env: env)
    */
    
    //
    // Uncomment the following if you *are not* using supervisord:
    //
    /*
    try server.withPty(nil) {
        var command = "swift run -c release"
     
        //
        // Some frameworks encourage additional arguments to be passed
        // Check their documention for details; the following are examples:
        //
        // Vapor:
        // command += " --env \\(env.name) --workDir=\\(env.currentDirectory)"
        // Kitura:
        // command += " --env=\\(env.name)"
        // Perfect (example; many options available):
        // command += " --port customPort --root customRoot"
     
        try server.execute("nohup \\(command) > /dev/null 2>&1 &")
    }
    */
}

func status(on server: Server, env: Environment) throws {
    //
    // Uncomment the following if you *are* using supervisord:
    //
    /*
     try executeSupervisor(command: "status", server: server, env: env)
     */
    
    //
    // Uncomment the following if you *are not* using supervisord:
    //
    /*
    if let pid = try findServerPid(on: server) {
        print("Server running as process \\(pid)")
    } else {
        print("Server not running")
    }
    */
}

func stopServer(on server: Server, env: Environment) throws {
    //
    // Uncomment the following if you *are* using supervisord:
    //
    /*
    try executeSupervisor(command: "stop", server: server, env: env)
    */
    
    //
    // Uncomment the following if you *are not* using supervisord:
    //
    /*
    if let pid = try findServerPid(on: server) {
        try server.execute("kill -9 \\(pid)")
    } else {
        print("Server not running")
    }
    */
}

func restartServer(on server: Server, env: Environment) throws {
    //
    // Uncomment the following if you *are* using supervisord:
    //
    /*
     try executeSupervisor(command: "restart", server: server, env: env)
     */
    
    //
    // Uncomment the following if you *are not* using supervisord:
    //
    /*
     try stopServer(on: server, project: project)
     try startServer(on: server, project: project)
     */
}

// MARK: - Internal helpers

func executeSupervisor(command: String, server: Server, env: Environment) throws {
    try server.execute("supervisorctl \\(command) \\(env.project.name):*")
}

func findServerPid(on server: Server) throws -> String? {
    let processes = try server.capture("ps aux | grep \\"swift run\\"")
    
    let lines = processes.components(separatedBy: "\\n")
    for line in lines where !line.contains("grep") {
        let segments = line.components(separatedBy: " ").filter { !$0.isEmpty }
        if segments.count > 1 {
            return segments[1]
        }
        return segments.count > 1 ? segments[1] : nil
    }
    return nil
}

"""
