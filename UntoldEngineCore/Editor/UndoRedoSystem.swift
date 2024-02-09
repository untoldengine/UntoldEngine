//
//  UndoRedoSystem.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 7/4/23.
//

import Foundation

func undoOperation(){
    
    //check if the stack is empty
    if undoStack.isEmpty(){
        //stack is empty
        return
    }
    
    if let topElement=undoStack.popLast(){
        //perform action with the top element
        let userOperation=topElement
        
        //add the operation to the redo stack
        redoStack.append(userOperation)
        
        if userOperation.voxelAction == .add {
            //if user operation was to add, then we need to remove
            //removeBlockFromGPU(uGuid: userOperation.neighborGuid, action: userOperation.action,storeAction: false)
        }else if userOperation.voxelAction == .remove {
            //if user operation was to remove, then we need to add
            //insertBlockIntoGPU(uGuid: userOperation.guid, uNormal: userOperation.normal, action: userOperation.action, floor: userOperation.floor,storeAction: false)
        }else if userOperation.voxelAction == .color{
            
            //changeVoxelColor(uGuid: userOperation.guid,color: userOperation.previousColor, action: userOperation.action, storeAction: false)
        }
    }
    
}

func redoOperation(){
    
    //check if the stack is empty
    if redoStack.isEmpty(){
        
        return
    }
    
    if let topElement=redoStack.popLast(){
        //perform action with the top element
        let userOperation=topElement
        
        if userOperation.voxelAction == .add {
        
            //insertBlockIntoGPU(uGuid: userOperation.guid, uNormal: userOperation.normal, action: userOperation.action, floor: userOperation.floor,storeAction: true)
            
        }else if userOperation.voxelAction == .remove {
            
            //removeBlockFromGPU(uGuid: userOperation.guid, action: userOperation.action,storeAction: true)
            
        }else if userOperation.voxelAction == .color {
            
            //changeVoxelColor(uGuid: userOperation.guid, color: userOperation.color, action: userOperation.action, storeAction: true)
        }
    }
    
}
