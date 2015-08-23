//
//  U4DSphericalBoundingTree.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DSphericalBoundingTree.h"
#include <algorithm>
#include "U4DBoundingSphere.h"

void U4DSphericalBoundingTree::addGeometry(){

    //GET PARENT
    float max0=MAX(treeCoordinates.dimensions.x,treeCoordinates.dimensions.y);
    float parentRadius=MAX(max0,treeCoordinates.dimensions.z);
    

    U4DBoundingVolume *parentSphere=new U4DBoundingSphere();
    
    U4DVector3n vec(treeCoordinates.position.x,treeCoordinates.position.y,treeCoordinates.position.z);
    parentSphere->initSphereGeometry(parentRadius,vec,15, 15);
    parentSphere->translateTo(vec);

    //add the geometry to the parent
    
    childrenGeometry=parentSphere;
    
    //GET THE CHILD
     for (int i=0; i<children.size(); i++) {
     
     U4DOctTreeHierachy *tempChild=children.at(i);
     
  
     U4DBoundingVolume *childSphere=new U4DBoundingSphere();
     

    float max1=MAX(tempChild->treeCoordinates.dimensions.x,tempChild->treeCoordinates.dimensions.y);
    float childRadius=MAX(max1,tempChild->treeCoordinates.dimensions.z);
         
         
     childSphere->initSphereGeometry(childRadius,tempChild->treeCoordinates.position, 15, 15);
     childSphere->translateTo(tempChild->treeCoordinates.position);
     
       
     //add the geometry to the child
     
     children.at(i)->childrenGeometry=childSphere;
         
     //GET GRAND CHILD
     for (int n=0; n<children.at(i)->children.size(); n++) {
     
     
     U4DOctTreeHierachy *tempGrandChild=children.at(i)->children.at(n);
    
     
     U4DBoundingVolume *grandChildSphere=new U4DBoundingSphere();
     
          
     float max2=MAX(tempGrandChild->treeCoordinates.dimensions.x,tempGrandChild->treeCoordinates.dimensions.y);
     float grandChildRadius=MAX(max2,tempGrandChild->treeCoordinates.dimensions.z);
     
     grandChildSphere->initSphereGeometry(grandChildRadius,tempGrandChild->treeCoordinates.position, 15, 15);
     
     grandChildSphere->translateTo(tempGrandChild->treeCoordinates.position);
     
     children.at(i)->children.at(n)->childrenGeometry=grandChildSphere;
     
     }
     
     }
    
}


