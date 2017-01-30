//
//  Taskable.swift
//  Concurrency
//
//  Created by Sergey Minakov on 30.01.17.
//
//

import Dispatch

public protocol Taskable: Sendable, Waitable {
    
    associatedtype Element
    
    //TODO: global error
    
    init(on queue: DispatchQueue?, _ builder: (Task.Sending<Self>) throws -> Void) rethrows
}