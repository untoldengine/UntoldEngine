//
//  ComponentPool.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation

// Global dictionary to store component IDs for each type
var componentIDs = [ObjectIdentifier: Int]()

// Function to get or create a component ID for a specific type
func getComponentId<T>(for type: T.Type) -> Int {
    let typeId = ObjectIdentifier(type)
    if let id = componentIDs[typeId] {
        return id
    } else {
        let id = s_componentCounter
        s_componentCounter += 1
        componentIDs[typeId] = id
        return id
    }
}

protocol Component {
    init() //Requires a default initializer
}

struct ComponentPool{
    private var data:UnsafeMutableRawPointer?
    private let elementSize:Int
    
    
    init(_ elementSize:Int){
        self.elementSize = elementSize
        //allocate memory
        data=UnsafeMutableRawPointer.allocate(byteCount: elementSize*MAX_ENTITIES, alignment: MemoryLayout<UInt8>.alignment)
    }
    
    mutating func deallocate(){
        data?.deallocate()
        data=nil
    }
    
    func get(_ index:Int)->UnsafeMutableRawPointer?{
        guard let data=data else {return nil}
        //get component at desired index
        return data.advanced(by: index*elementSize)
    }
    
    // Add a new component to the pool at a specified index
    mutating func add<T: Component>(component: T, at index: Int) {
        guard let data = data else { fatalError("Data in ComponentPool is nil.") }
        let componentPointer = data.advanced(by: index * elementSize).assumingMemoryBound(to: T.self)
        componentPointer.initialize(to: component)
    }
}

struct ComponentMask{
    private var bits = [Bool](repeating: false, count: MAX_COMPONENTS)
    
    //set the bit at a specific index to true
    mutating func set(_ index: Int){
        guard index<MAX_COMPONENTS else {return}
        bits[index]=true
    }
    
    //Resets the bit at a specific index to false
    mutating func reset(_ index: Int? = nil){
        if let index = index, index < MAX_COMPONENTS {
                    bits[index] = false
                } else if index == nil {
                    bits = [Bool](repeating: false, count: MAX_COMPONENTS)
                }
    }
    
    // Checks if the bit at a specific index is true
        func test(_ index: Int) -> Bool {
            guard index < MAX_COMPONENTS else { return false }
            return bits[index]
        }
}


