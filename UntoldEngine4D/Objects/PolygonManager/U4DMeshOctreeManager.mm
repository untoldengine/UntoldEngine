//
//  U4DMeshOctreeManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/28/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DMeshOctreeManager.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
    U4DMeshOctreeManager::U4DMeshOctreeManager(U4DStaticModel *uModel):model(uModel){
        
        //compute mesh faces in absolute space (recall mesh faces are in local space. You need to convert them to absolute space)
        computeMeshFacesAbsoluteSpace();
        
    }
    
    U4DMeshOctreeManager::~U4DMeshOctreeManager(){
        
        //clear oct tree
        treeContainer.clear();
        
    }
    
    void U4DMeshOctreeManager::buildOctree(int uSubDivisions){
    
        //0 subdivisions=1 node
        //1 subdivision=9 nodes
        //2 subdivisions=73 nodes
        //3 subdivisions=585 nodes
        
        //calculate the max dimension of the 3d model for the halfwidth
        U4DVector3n modelDimensions=model->getModelDimensions();
        
        //get the position of the 3d model
        U4DVector3n modelPosition=model->getAbsolutePosition();
        
        //Compute maximum halfwidth for AABB
        float maxHalfWidth=std::max(std::max(modelDimensions.x,modelDimensions.y),modelDimensions.z);
        maxHalfWidth*=0.5;
        
        U4DPoint3n centerOfAABB=modelPosition.toPoint();
        
        //get pointer to mesh that make up the model
        std::shared_ptr<U4DMeshOctreeNode> rootNode(new U4DMeshOctreeNode());
        
        //store rootNode at treeContainer position 0.
        treeContainer.push_back(rootNode);
        
        //build the octree
        buildOctreeNode(rootNode.get(), centerOfAABB, maxHalfWidth, uSubDivisions);
        
        //assign the triangles (faces of polygon) to each leaf node
        assignFacesToNodeLeaf();
        
    }
    
    void U4DMeshOctreeManager::buildOctreeNode(U4DMeshOctreeNode *uNode, U4DPoint3n &uCenter, float uHalfwidth, int uSubDivisions){
        
        if (uSubDivisions>=0){
            
            //construct and fill in 'root' of this subtree
            std::shared_ptr<U4DMeshOctreeNode> nodeLeaf(new U4DMeshOctreeNode());
            
            treeContainer.push_back(nodeLeaf);
            
            uNode->addChild(nodeLeaf.get());
            
            U4DAABB aabb(uHalfwidth,uHalfwidth,uHalfwidth,uCenter);
            
            nodeLeaf->aabbVolume=aabb;
            
            //Recursively construct the eight children of the subtree
            U4DPoint3n offset;
            float step=uHalfwidth*0.5;
            
            for (int i=0; i<8; i++) {
                
                offset.x=((i&1)?step:-step);
                offset.y=((i&2)?step:-step);
                offset.z=((i&4)?step:-step);
                
                U4DPoint3n p=uCenter+offset;
                
                buildOctreeNode(nodeLeaf.get(),p, step, uSubDivisions-1);
                
            }
            
        }
        
    }
    
    void U4DMeshOctreeManager::assignFacesToNodeLeaf(){
        
        //Traverse the tree
        U4DMeshOctreeNode* child=treeContainer.at(0).get();

        while (child!=NULL) {

            if(child->isRoot()){
                
            }else if(child->isLeaf()){
               
                //For each leaf test which triangles intersect with its AABB box and store index in a
                //vector container
                
                for(int i=0;i<meshFacesAbsoluteSpaceContainer.size();i++){
                    
                    U4DTriangle face=meshFacesAbsoluteSpaceContainer.at(i);
                    
                    if(child->aabbVolume.intersectionWithTriangle(face)){
                        child->triangleIndexContainer.push_back(i);
                    }
                    
                }
                
            }

            child=child->next;

        }
        
    }
    
    U4DMeshOctreeNode *U4DMeshOctreeManager::getRootNode(){
        
        //return root node store at index location 0 in the tree container
        return treeContainer.at(0).get();
        
    }
    
    void U4DMeshOctreeManager::computeMeshFacesAbsoluteSpace(){
        
        std::vector<U4DTriangle> facesLocalSpaceContainer=model->polygonInformation.getFacesDataFromContainer();
        
        for(auto n:facesLocalSpaceContainer){
            
            U4DVector3n pointA=model->getAbsoluteMatrixOrientation()*n.pointA.toVector();
            pointA=pointA+model->getAbsolutePosition();
            
            U4DVector3n pointB=model->getAbsoluteMatrixOrientation()*n.pointB.toVector();
            pointB=pointB+model->getAbsolutePosition();
            
            U4DVector3n pointC=model->getAbsoluteMatrixOrientation()*n.pointC.toVector();
            pointC=pointC+model->getAbsolutePosition();
            
            U4DPoint3n a=pointA.toPoint();
            U4DPoint3n b=pointB.toPoint();
            U4DPoint3n c=pointC.toPoint();
            
            U4DTriangle triangle(a,b,c);
            
            meshFacesAbsoluteSpaceContainer.push_back(triangle);
            
        }
        
    }
    
    std::vector<U4DTriangle> U4DMeshOctreeManager::getMeshFacesAbsoluteSpaceContainer(){
        
        return meshFacesAbsoluteSpaceContainer;
    }
    
}
