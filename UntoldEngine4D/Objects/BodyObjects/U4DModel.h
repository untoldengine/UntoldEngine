//
//  U4DModel.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DModel__
#define __UntoldEngine__U4DModel__

#include <iostream>
#include "U4DVisibleEntity.h"
#include "U4DMatrix3n.h"
#include "U4DOpenGL3DModel.h" 
#include "U4DVertexData.h"
#include "U4DMaterialData.h"
#include "U4DTextureData.h"
#include "U4DArmatureData.h"
#include "U4DAnimation.h"
#include "CommonProtocols.h"
//#include "U4DBoundingVolume.h"
//#include "U4DOBB.h"
#include "U4DConvexPolygon.h"

namespace U4DEngine {
    
class U4DModel:public U4DVisibleEntity{
    
private:
    
protected:
    
    bool affectedByPhysics;
    
    bool affectedByCollision;
    
public:
    
    bool hasMaterial;
    bool hasTextures;
    bool hasAnimation;
    
    U4DVertexData bodyCoordinates;
    
    U4DMaterialData materialInformation;
    
    U4DTextureData textureInformation;
    
    U4DArmatureData *armatureManager;
    
    std::vector<U4DMatrix4n> armatureBoneMatrix;
    
    //U4DOBB *obbBoundingVolume;
    U4DConvexPolygon *narrowPhaseBoundingVolume;
    
    
    U4DModel(){
        
        hasMaterial=false;
        hasTextures=false;
        hasAnimation=false;
        
        openGlManager=new U4DOpenGL3DModel(this);
        armatureManager=new U4DArmatureData(this);
        
        openGlManager->setShader("modelShader");
        
        setEntityType(MODEL);
        
        affectedByPhysics=false;
        affectedByCollision=false;
        
        //create the narrow phase bounding volume
        
        //compute the vertices
        float width=1.0;
        float height=1.0;
        float depth=1.0;
        
        
        U4DVector3n v1(width,height,depth);
        U4DVector3n v2(width,height,-depth);
        U4DVector3n v3(-width,height,-depth);
        U4DVector3n v4(-width,height,depth);
        
        U4DVector3n v5(width,-height,depth);
        U4DVector3n v6(width,-height,-depth);
        U4DVector3n v7(-width,-height,-depth);
        U4DVector3n v8(-width,-height,depth);
        
        
        std::vector<U4DVector3n> vertices{v1,v2,v3,v4,v5,v6,v7,v8};
        
        narrowPhaseBoundingVolume=new U4DConvexPolygon();
        narrowPhaseBoundingVolume->setVerticesInConvexPolygon(vertices);
        
    };
    

    ~U4DModel(){
    
        delete openGlManager;
        delete armatureManager;
    };
    

    U4DModel(const U4DModel& value){};

    U4DModel& operator=(const U4DModel& value){return *this;};
    
    virtual void update(double dt){};
    
    void draw() final;
    
    void drawDepthOnFrameBuffer();

    void setShader(std::string uShader);
    
    void receiveShadows();
    
    void applyPhysics(bool uValue);
    
    void applyCollision(bool uValue);
    
    bool isPhysicsApplied();
    
    bool isCollisionApplied();
    
    virtual void setAwake(bool uValue){};
    
    virtual bool getAwake(){};
 
};
    
}


#endif /* defined(__UntoldEngine__U4DModel__) */
