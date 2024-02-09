//
//  Scene.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation

struct EntityDesc{
    var index:EntityID
    var mask:ComponentMask
}

struct Scene{
    
    mutating func remove<T: Component>(component type: T.Type, from index: EntityID) {
            let entityIndex = getEntityIndex(index)
            guard entities[Int(entityIndex)].index == index else { return }

            let componentId = getComponentId(for: T.self)
            entities[Int(entityIndex)].mask.reset(componentId)
        }
    
    mutating func destroyEntity(_ index: EntityID) {
            let entityIndex = getEntityIndex(index)
            let newId = createEntityId(EntityIndex(UInt32.max), getEntityVersion(index) + 1)
            entities[Int(entityIndex)].index = newId
            entities[Int(entityIndex)].mask.reset()
            freeEntities.append(entityIndex)
        }
    
    mutating func newEntity() -> EntityID {
            if let newIndex = freeEntities.popLast() {
                let newId = createEntityId(newIndex, getEntityVersion( entities[Int(newIndex)].index))
                entities[Int(newIndex)].index = newId
                return newId
            } else {
                let entityIndex = EntityIndex(UInt32(entities.count))
                let newEntity = EntityDesc(index: createEntityId(entityIndex, 0), mask: ComponentMask())
                entities.append(newEntity)
                return newEntity.index
            }
        }
    
    /* explicitly specify type*/
     mutating func assign<T: Component>(to id: EntityID, component type: T.Type) -> T {
         let componentId = getComponentId(for: T.self)
         let entityIndex = getEntityIndex(id)

         // Ensure the pool for this component type exists
         if componentPool[componentId] == nil {
             componentPool[componentId] = ComponentPool(MemoryLayout<T>.stride)
         }

         // Retrieve the specific component pool
         guard let pool = componentPool[componentId] else {
             fatalError("Component pool for type \(T.self) could not be found.")
         }

         // Allocate and initialize a new component in the pool
         guard let componentPointer = pool.get(Int(entityIndex)) else {
             fatalError("Failed to get component pointer from pool")
         }

         let typedPointer = componentPointer.bindMemory(to: T.self, capacity: 1)
         typedPointer.initialize(to: T())

         // Set the bit for this component to true
         entities[Int(entityIndex)].mask.set(componentId)

         return typedPointer.pointee
     }

     /*
    mutating func assign<T:Component>(to index:EntityID)->T{
        let componentId=getComponentId(for: T.self)
        let entityIndex=getEntityIndex(index)
        
        //Ensure the pool for this component type exists
        if componentPool[componentId]==nil{
            componentPool[componentId]=ComponentPool(MemoryLayout<T>.stride)
        }
        
        //Retrieve the specific component pool
        guard let pool=componentPool[componentId] else{
            fatalError("Component pool for type \(T.self) cound not be found.")
        }
        
        // Allocate and initialize a new component in the pool
        guard let componentPointer = pool.get(Int(entityIndex)) else {
            fatalError("Failed to get component pointer from pool")
        }

        // Initialize memory with the new component
        let typedPointer = componentPointer.bindMemory(to: T.self, capacity: 1)
        typedPointer.initialize(to: T())

        // Set the bit for this component to true
        entities[Int(entityIndex)].mask.set(componentId)

        // Return the newly created component
        return typedPointer.pointee
    }
    */
    func get<T: Component>(component type: T.Type, for index: EntityID) -> T? {
            let componentId = getComponentId(for: T.self)
            let entityIndex = getEntityIndex(index)

            // Check if the entity has this component
            guard entities[Int(entityIndex)].mask.test(componentId) else {
                return nil
            }

            // Retrieve the specific component pool
            guard let pool = componentPool[componentId] else {
                return nil
            }

            // Get the component from the pool
            if let componentPointer = pool.get(Int(entityIndex)) {
                let typedPointer = componentPointer.bindMemory(to: T.self, capacity: 1)
                return typedPointer.pointee
            }

            return nil
        }
    
    //data
    var componentPool: [Int:ComponentPool]=[:]
    var entities:[EntityDesc] = []
    var freeEntities:[EntityIndex]=[]
}


protocol ComponentChecker {
    static func hasRequiredComponents(entity: EntityDesc) -> Bool
}

struct ComponentQuery<Checker: ComponentChecker>: Sequence {
    private let scene: Scene

    init(scene: Scene) {
        self.scene = scene
    }

    struct Iterator: IteratorProtocol {
        private let scene: Scene
        private var currentIndex: Int = 0

        init(scene: Scene) {
            self.scene = scene
        }

        mutating func next() -> EntityID? {
            while currentIndex < scene.entities.count {
                let entity = scene.entities[currentIndex]
                currentIndex += 1

                if Checker.hasRequiredComponents(entity: entity) {
                    return entity.index
                }
            }
            return nil
        }
    }

    func makeIterator() -> Iterator {
        return Iterator(scene: scene)
    }
}
