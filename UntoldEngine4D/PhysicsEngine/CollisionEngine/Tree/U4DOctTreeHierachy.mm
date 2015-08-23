//
//  U4DOctTreeHierachy.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/17/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DOctTreeHierachy.h"


void U4DOctTreeHierachy::buildTree(U4DDynamicModel* uBody){
    /*
    body=uBody;
    //calculate the oct tree
    
    //find the min and max of the bounding box
    
    vector<float> minXValue;
    vector<float> minYValue;
    vector<float> minZValue;
    
    vector<float> maxXValue;
    vector<float> maxYValue;
    vector<float> maxZValue;
    
    
    
    for (int i=0; i<uBody->openGlManager->numberOfVertices/8; i++) {
        
        minXValue.push_back(uBody->openGlManager->body[i][5]);
        minYValue.push_back(uBody->openGlManager->body[i][5+1]);
        minZValue.push_back(uBody->openGlManager->body[i][5+2]);
        
        maxXValue.push_back(uBody->openGlManager->body[i][5]);
        maxYValue.push_back(uBody->openGlManager->body[i][5+1]);
        maxZValue.push_back(uBody->openGlManager->body[i][5+2]);
    }
    
    auto minX=min_element(minXValue.cbegin(), minXValue.cend());
    auto minY=min_element(minYValue.cbegin(), minYValue.cend());
    auto minZ=min_element(minZValue.cbegin(), minZValue.cend());
    
    auto maxX=max_element(maxXValue.cbegin(), maxXValue.cend());
    auto maxY=max_element(maxYValue.cbegin(), maxYValue.cend());
    auto maxZ=max_element(maxZValue.cbegin(), maxZValue.cend());
    
    float minXValueForVector=*minX;
    float minYValueForVector=*minY;
    float minZValueForVector=*minZ;
    
    float maxXValueForVector=*maxX;
    float maxYValueForVector=*maxY;
    float maxZValueForVector=*maxZ;
    
    U4DVector3n min(minXValueForVector,minYValueForVector,minZValueForVector);
    U4DVector3n max(maxXValueForVector,maxYValueForVector,maxZValueForVector);
    
    //set the initial vertices for the parent
    treeCoordinates.position=uBody->getPosition();
    
    float width=abs(max.x-min.x);
    float height=abs(max.y-min.y);
    float depth=abs(max.z-min.z);
    
    U4DVector3n dimensions(width,height,depth);
    
    treeCoordinates.dimensions=dimensions;
    
    //set up the 8 first children
    
    vector<U4DVector3n> verticesPosition;
    
    
    U4DVector3n childDimensions(dimensions.x/2, dimensions.y/2, dimensions.z/2);
    verticesPosition=innerCubeVertices(childDimensions.x,childDimensions.y,childDimensions.z);
    
    for (int i=0; i<8; i++) {
        
        U4DOctTreeHierachy *child=new U4DOctTreeHierachy;
        child->treeCoordinates.position=verticesPosition.at(i)+treeCoordinates.position;
        child->treeCoordinates.dimensions=childDimensions;
        
        //add child to parent
        add(child);
    }
    
    //clear the vector
    verticesPosition.clear();
    
    
    float numberOfVerticesInsideSphere=0;
    
    //set up the 8 of each child
    
    for (int n=0; n<children.size(); n++) {
        
        U4DOctTreeHierachy *tempChild=children.at(n);
        
        U4DVector3n childrenOfChildrenDimension(tempChild->treeCoordinates.dimensions.x/2,tempChild->treeCoordinates.dimensions.y/2,tempChild->treeCoordinates.dimensions.z/2);
        
        verticesPosition=innerCubeVertices(childrenOfChildrenDimension.x,childrenOfChildrenDimension.y,childrenOfChildrenDimension.z);
        
        for (int i=0; i<8; i++) {
            
            U4DOctTreeHierachy *child=new U4DOctTreeHierachy;
            child->treeCoordinates.position=verticesPosition.at(i)+tempChild->treeCoordinates.position;
            child->treeCoordinates.dimensions=childrenOfChildrenDimension;
            
            //get the radius of the sphere
            float max1=MAX(child->treeCoordinates.dimensions.x,child->treeCoordinates.dimensions.y);
            float radius=MAX(max1,child->treeCoordinates.dimensions.z);
            
            radius=pow(radius, 2);
        
            //get the vertices of the body
            
            for (int i=0; i<uBody->openGlManager->numberOfVertices/8; i++) {
                
                U4DVector3n verticesOfBody(uBody->openGlManager->body[i][5],uBody->openGlManager->body[i][5+1],uBody->openGlManager->body[i][5+2]);
               
                U4DVector3n positionOfSphere(child->treeCoordinates.position.x,child->treeCoordinates.position.y,child->treeCoordinates.position.z);
                
                float pythagoras=pow(verticesOfBody.x-positionOfSphere.x, 2) + pow(verticesOfBody.y-positionOfSphere.y, 2) + pow(verticesOfBody.z-positionOfSphere.z, 2);
                
                if (pythagoras<=radius) {
                    
                    numberOfVerticesInsideSphere++;
                }
            
            }
            
            //add child(grandchild) to child 
            if (numberOfVerticesInsideSphere<=uBody->openGlManager->numberOfVertices) {
                children.at(n)->add(child);
            }
            
            numberOfVerticesInsideSphere=0;
        
        }
        
        
    }
    
    //clear the vector
    verticesPosition.clear();
    
    //add geometry to vertices
    addGeometry();
    */
}

vector<U4DVector3n> U4DOctTreeHierachy::innerCubeVertices(float uWidth,float uHeight,float uDepth){
    
    //get the vertices of the innter triangle
    float width=uWidth/2;
    float height=uHeight/2;
    float depth=uDepth/2;
    
    U4DVector3n v1(width,height,depth);
    U4DVector3n v2(width,height,-depth);
    U4DVector3n v3(-width,height,-depth);
    U4DVector3n v4(-width,height,depth);
    
    U4DVector3n v5(width,-height,depth);
    U4DVector3n v6(width,-height,-depth);
    U4DVector3n v7(-width,-height,-depth);
    U4DVector3n v8(-width,-height,depth);
    
    vector<U4DVector3n> vertices;
    vertices.push_back(v1);
    vertices.push_back(v2);
    vertices.push_back(v3);
    vertices.push_back(v4);
    
    vertices.push_back(v5);
    vertices.push_back(v6);
    vertices.push_back(v7);
    vertices.push_back(v8);
    
    
    return vertices;
}

void U4DOctTreeHierachy::add(U4DOctTreeHierachy *uChild){
    
    children.push_back(uChild);
}

/*
void U4DOctTreeHierachy::add(U4DBoundingVolume* uChild){
    
    childrenGeometry.push_back(uChild);

}
*/

void U4DOctTreeHierachy::remove(U4DOctTreeHierachy *uChild){
    
    //children.erase(remove(children.begin(), children.end(), uChild),children.end());
    vector<U4DOctTreeHierachy*>::iterator pos;
    
    pos=find(children.begin(), children.end(), uChild);
    
    children.erase(pos);
    
}

U4DOctTreeHierachy *U4DOctTreeHierachy::getChild(int i){
    
}
