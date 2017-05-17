//
//  Task.swift
//  SwiftAsync
//
//  Created by Sergey Minakov on 05.01.17.
//
//

@_exported import Dispatch

fileprivate let TaskIDGenerator = IDGenerator(key: "task.id")

public protocol Taskable {
    
    associatedtype Element
}

public let yield: Void = { return }()

public class Task<T>: Taskable {
    
    public typealias Element = T
    
    deinit { }
    
    public private(set) var id = TaskIDGenerator.next()
    
    public private(set) var state = State<Element>.ready
    
    internal var condition = DispatchCondition()
    
    internal var observer = Observer<Element>()
    internal lazy var options: Options<Element> = Options<Element>()
    
    public init(on queue: DispatchQueue = .task,
                _ action: @escaping (Task<Element>) -> Void) {
        self.commonInit(on: queue, delay: nil, action)
    }
    
    public init(on queue: DispatchQueue = .task,
                delay: @autoclosure @escaping () -> DispatchTime,
                _ action: @escaping (Task<Element>) -> Void) {
        self.commonInit(on: queue, delay: delay, action)
    }
    
    public init(on queue: DispatchQueue = .task,
                value action: @autoclosure @escaping () throws -> Element) {
        self.commonInit(on: queue, delay: nil, action)
    }
    
    public init(on queue: DispatchQueue = .task,
                delay: @autoclosure @escaping () -> DispatchTime,
                value action: @autoclosure @escaping () throws -> Element) {
        self.commonInit(on: queue, delay: delay, action)
    }
    
    public init(on queue: DispatchQueue = .task,
                state: State<Element>) {
        self.state = state
        self.commonInit(queue: queue)
    }
    
    public init(on queue: DispatchQueue = .task) {
        self.commonInit(queue: queue)
    }
    
    
    private func commonInit(queue: DispatchQueue) {
        self.commonInit()
        self.options.start = Options<Element>
            .StartHandler(queue: queue,
                          delay: nil,
                          action: { _ in })
        
        self.start()
    }
    
    private func commonInit() { }
    
    private func commonInit(on queue: DispatchQueue,
                            delay: (() -> DispatchTime)?,
                            _ action: @escaping (Task<Element>) -> Void) {
        self.commonInit()
        self.options.start = Options<Element>.StartHandler(
            queue: queue,
            delay: delay,
            action: action)
        
        self.start()
    }
    
    private func commonInit(on queue: DispatchQueue,
                            delay: (() -> DispatchTime)?,
                            _ action: @autoclosure @escaping () throws -> Element) {
        self.commonInit()
        self.options.start = Options<Element>.StartHandler(
            queue: queue,
            delay: delay) { task in
                do {
                    let value = try action()
                    task.send(value)
                } catch {
                    task.throw(error)
                }
        }
        
        self.start()
    }
    
    private func start() {
        guard case .ready = self.state else {
            self.updateState(to: self.state)
            return
        }
        self.options.start?.perform(with: self)
    }
    
    internal func update() {
        if case .ready = self.state { return }
        
        self.updateState(to: self.state)
    }
    
    fileprivate func updateState(to state: State<Element>) {
        (self.options.start?.queue ?? .task).async {
            self.condition.mutex.lock()
            defer {
                self.condition.broadcast()
                self.condition.mutex.unlock()
            }
            
            self.state = state
            guard var result = self.state.result else {
                return
            }
            
            defer {
                self.options.clear()
            }
            
            switch result {
            case .some(let value):
                self.options.done?.perform(with: value)
            case .error(let error):
                self.options.error?.perform(with: error)
                if let newState = self.options.recover(from: error, at: self),
                    let newResult = newState.result {
                    self.state = newState
                    result = newResult
                }
            }
            
            self.options.always?.perform(with: result)
            
            self.observer.fire(with: result) {
                self.observer.clear()
            }
        }
    }
}

public extension Task {
    
    public func send(_ value: Element) {
        self.updateState(to: .finished(value))
    }
    
    public func `throw`(_ error: Swift.Error) {
        self.updateState(to: .error(error))
    }
}


