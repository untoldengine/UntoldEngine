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
    
    void setBoundingVolume(U4DConvexPolygon* uConvexPolygon);
 
};
    
}


#endif /* defined(__UntoldEngine__U4DModel__) */
