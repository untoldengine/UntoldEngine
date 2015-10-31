//
//  U4DEntity.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DEntity__
#define __UntoldEngine__U4DEntity__

#include <iostream>
#include <vector>
#include "U4DDualQuaternion.h"
#include "U4DVector3n.h"
#include "U4DVector2n.h"
#include "U4DVector4n.h"
#include "U4DIndex.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
class U4DQuaternion;
class U4DTransformation;

}

namespace U4DEngine {
/**
 *  Super Object for all other objects in the library
 */
class U4DEntity{
  
private:
    
    std::string name;    //name of object
    
    ENTITYTYPE entityType;
    

    
protected:
    
    U4DVector3n localOrientation;
    
    U4DVector3n localPosition;
    
    U4DVector3n absoluteOrientation;
    
    U4DVector3n absolutePosition;
    
public:
    
    //Pure Quaternion represent translation
    //Real Quaternion represent orientation
    U4DDualQuaternion localSpace;
    
    U4DDualQuaternion absoluteSpace;
    
    U4DTransformation *transformation;
    
    U4DVector3n viewDirection;
    
    U4DEntity *parent;
    
    U4DEntity *prevSibling;
    
    
    U4DEntity *next;
    
    
    U4DEntity *lastDescendant;
    
    
    U4DEntity();
    
    ~U4DEntity();
    
    
    U4DEntity(const U4DEntity& value);
    
    
    U4DEntity& operator=(const U4DEntity& value);
    
    void setName(std::string uName);
    
    std::string getName();
    
    void setEntityType(ENTITYTYPE uType);
    
    ENTITYTYPE getEntityType();
    
    void setLocalSpace(U4DDualQuaternion &uLocalSpace);
    
    void setLocalSpace(U4DMatrix4n &uMatrix);
    
    void setViewDirection(U4DVector3n &uViewDirection);
    
    void updateViewDirection(U4DQuaternion &uViewDirectionSpace);
    
    U4DDualQuaternion getLocalSpace();
    
    U4DDualQuaternion getAbsoluteSpace();
    
    U4DQuaternion getLocalSpaceOrientation();
    
    U4DQuaternion getLocalSpaceTranslation();
    
    U4DQuaternion getAbsoluteSpaceOrientation();
    
    U4DQuaternion getAbsoluteSpaceTranslation();
    
    void setLocalSpaceOrientation(U4DQuaternion &uOrientation);
    
    void setLocalSpacePosition(U4DQuaternion &uPosition);
    
    U4DVector3n getLocalOrientation();
    
    U4DVector3n getLocalPosition();
    
    U4DVector3n getAbsoluteOrientation();
    
    U4DVector3n getAbsolutePosition();
    
    U4DVector3n getViewDirection();
    
    U4DMatrix3n getAbsoluteMatrixOrientation();
    
    U4DMatrix3n getLocalMatrixOrientation();
    
    //Transformation helper functions
    
    void translateTo(U4DVector3n& translation);
    
    void translateTo(float x,float y, float z);
    
    void rotateTo(U4DQuaternion& rotation);
    
    void rotateBy(U4DQuaternion& rotation);
    
    void rotateTo(float angle, U4DVector3n& axis);
    
    void rotateBy(float angle, U4DVector3n& axis);

    void rotateTo(float angleX, float angleY, float angleZ);
    
    void rotateBy(float angleX, float angleY, float angleZ);
    
    void translateTo(U4DVector2n &translation);
    
    void translateBy(float x,float y, float z);
    
    void rotateAboutAxis(float angle, U4DVector3n& axisOrientation, U4DVector3n& axisPosition);
    
    void rotateAboutAxis(U4DQuaternion& uOrientation, U4DVector3n& axisPosition);
    
    virtual void viewInDirection(U4DVector3n& uDestinationPoint);
    
    //scenegraph
    
    void addChild(U4DEntity *uChild);
    
    void removeChild(U4DEntity *uChild);
    
    void changeLastDescendant(U4DEntity *uNewLastDescendant);
    
    U4DEntity *getFirstChild();
    
    
    U4DEntity *getLastChild();
    
    
    U4DEntity *getNextSibling();
    
    
    U4DEntity *getPrevSibling();
    
    
    U4DEntity *prevInPreOrderTraversal();
    
    
    U4DEntity *nextInPreOrderTraversal();
    
    bool isLeaf();
    
    bool isRoot();
     
    
    virtual void draw(){};
    
    virtual void drawDepthOnFrameBuffer(){};
    
    virtual void startShadowMapPass(){};
    
    virtual void endShadowMapPass(){};
    
    virtual void getShadows(){};
    
    virtual void update(double dt){};
    
    virtual void loadRenderingInformation(){};
    
};

}

#endif /* defined(__UntoldEngine__U4DEntity__) */
