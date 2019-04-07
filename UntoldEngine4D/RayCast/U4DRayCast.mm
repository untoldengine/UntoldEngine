//
//  U4DRayCast.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/1/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DRayCast.h"
#include "U4DMeshOctreeManager.h"
#include "U4DMeshOctreeNode.h"

namespace U4DEngine{
    
    U4DRayCast::U4DRayCast(){
        
    }
    
    U4DRayCast::~U4DRayCast(){
        
    }
    
    bool U4DRayCast::hit(U4DRay &uRay,U4DStaticModel *uModel,U4DTriangle &uTriangle){
        
        //boolean to return hit or non-hit
        bool intersectionFound=false;
        
        //best distance between ray and triangle
        float closestDistance=FLT_MAX;
        
        //Get Octree Manager
        U4DMeshOctreeManager *meshManager=uModel->getMeshOctreeManager();
        
        if(meshManager!=nullptr){
         
            //Get the root node of the octree
            U4DMeshOctreeNode *rootNode=meshManager->getRootNode();
            
            //declare intersection point and intersection parameters
            U4DPoint3n intersectionPoint;
            float intersectionParameter;
            
            //search through the octree
            U4DMeshOctreeNode *child=rootNode->next;
            
            //get the mesh faces of the 3d model in absolute space
            std::vector<U4DTriangle> faceContainer=meshManager->getMeshFacesAbsoluteSpaceContainer();
            
            while(child!=nullptr){
                
                if(child->isRoot()){
                    
                }else{
                    
                    //get the AABB representing the node
                    U4DAABB aabb=child->aabbVolume;
                    
                    //If is a leaf, then do a ray vs triangle intersection
                    if(child->isLeaf()){
                        
                        //if aabb vs ray intersection is true
                        
                        if(uRay.intersectAABB(aabb, intersectionPoint, intersectionParameter)){
                            
                            for(int i=0;i<child->triangleIndexContainer.size();i++){
                                
                                //get triangle index
                                int triangleIndex=child->triangleIndexContainer.at(i);
                                
                                //get triangle at the specified index
                                U4DTriangle faceTriangle=faceContainer.at(triangleIndex);
                                
                                //do ray vs triangle intersection
                                if(uRay.intersectTriangle(faceTriangle, intersectionPoint, intersectionParameter)){
                                    
                                    //if there is an intersection
                                    
                                    //get distance between triangle and ray
                                    
                                    U4DPoint3n triangleCenter=faceTriangle.getCentroid();
                                    
                                    float tempDistanceRayTriangle=(triangleCenter-uRay.origin).magnitude();
                                    
                                    //get normal of triangle
                                    U4DVector3n triangleNormal=faceTriangle.getTriangleNormal();
                                    
                                    //normalize ray direction
                                    uRay.direction.normalize();
                                    
                                    if(tempDistanceRayTriangle<=closestDistance && uRay.direction.dot(triangleNormal)<=0){
                                        
                                        closestDistance=tempDistanceRayTriangle;
                                        
                                        uTriangle=faceTriangle;
                                        
                                        intersectionFound=true;
                                        
                                    }
                                    
                                    
                                }
                                
                            }
                            
                        }
                        
                    }else{
                        //else is a parent then do ray vs AABB intersection
                        
                        //do ray vs AABB intersection
                        if(!uRay.intersectAABB(aabb, intersectionPoint, intersectionParameter)){
                            
                            //if there is no intersection, then go on to sibling
                            child=child->lastDescendant;
                            
                        }
                        
                    }
                    
                }
                
                child=child->next;
                
                
            }
            
        }
        
        return intersectionFound;
        
    }
    
}
