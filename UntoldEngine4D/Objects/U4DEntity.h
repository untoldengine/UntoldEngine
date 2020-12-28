//
//  U4DEntity.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
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
#include "U4DPadAxis.h"
#include "CommonProtocols.h"
#include <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    class U4DQuaternion;
    class U4DTransformation;
    class U4DEntityManager;
}

namespace U4DEngine {

/**
 @ingroup gameobjects
 @brief The U4DEntity class is a Super-Class for all the entities in a game, such as 3D models, buttons, fonts, etc.
 */
class U4DEntity{
  
private:

    /**
     @brief Name of the entity
     */
    std::string name;
    
    /**
     @brief Type of the entity
     */
    ENTITYTYPE entityType;
    
    /**
     @brief z-depth used for rendering ordering
     */
    int zDepth;
    
protected:
    
    /**
     @brief Entity local orientation
     */
    U4DVector3n localOrientation;
    
    /**
     @brief Entity local position
     */
    U4DVector3n localPosition;
    
    /**
     @brief Entity absolute orientation
     */
    U4DVector3n absoluteOrientation;
    
    /**
     @brief Entity absolute position
     */
    U4DVector3n absolutePosition;
    
public:
    
    //Pure Quaternion represent translation
    //Real Quaternion represent orientation
    
    /**
     @brief Local Space of the entity
     */
    U4DDualQuaternion localSpace;
    
    /**
     @brief Absolute Space of the entity
     */
    U4DDualQuaternion absoluteSpace;
    
    /**
     @brief U4DTransformation object pointer in charge of translating/rotating the entity
     */
    U4DTransformation *transformation;
    
    /**
     @brief Forward vector of the entity. This is used to compute the view-direction vector
     */
    U4DVector3n entityForwardVector;
    
    /**
     @brief Entity parent pointer
     */
    U4DEntity *parent;
    
    /**
     @brief Entity previous sibling pointer
     */
    U4DEntity *prevSibling;

    /**
     @brief Entity Next pointer
     */
    U4DEntity *next;
    
    /**
     @brief Entity last descendant pointer
     */
    U4DEntity *lastDescendant;
    
    /**
     @brief Entity Constructor. It creates the entity with the local orientation set to zero and local position set to the origin. The forwad vector is set to (0.0,0.0,-1.0). Parent and Next pointer set to null
     */
    U4DEntity();
    
    /**
     @brief Entity Destructor
     */
    ~U4DEntity();
    
    /**
     @brief Entity Copy Constructor
     */
    U4DEntity(const U4DEntity& value);
    
    /**
     @brief Entity Copy Constructor
     
     @param value Entity to copy to
     
     @return Returns a copy of the Entity object
     */
    U4DEntity& operator=(const U4DEntity& value);
    
    /**
     @brief Method which sets the name of the Entity
     
     @param uName Name for the Entity
     */
    void setName(std::string uName);
    
    /**
     @brief Method which returns the name of the Entity
     
     @return Returns the name of the Entity
     */
    std::string getName();
    
    /**
     @brief Method which sets the type of the Entity
     
     @param uType Type of the Entity
     */
    void setEntityType(ENTITYTYPE uType);
    
    /**
     @brief Method which returns the type of the Entity
     
     @return Returns the type of the Entity
     */
    ENTITYTYPE getEntityType();
    
    /**
     @brief Method which sets the local space of the Entity
     
     @param uLocalSpace Local space of the Entity in Dual-Quaternion form
     */
    void setLocalSpace(U4DDualQuaternion &uLocalSpace);
    
    /**
     @brief Method which sets the local space of the Entity
     
     @param uMatrix Local space of the Entity in 4x4 Matrix form
     */
    void setLocalSpace(U4DMatrix4n &uMatrix);
    
    U4DDualQuaternion getLocalSpace();
    
    /**
     @brief Method which returns the absolute space of the Entity
     
     @return Returns the absolute space of the Entity
     */
    U4DDualQuaternion getAbsoluteSpace();
    
    /**
     @brief Method which returns the local orientation space of the Entity
     
     @return Returns the local space orientation of the Entity
     */
    U4DQuaternion getLocalSpaceOrientation();
    
    /**
     @brief Method which returns the local position space of the Entity
     
     @return Returns the local space position of the Entity
     */
    U4DQuaternion getLocalSpacePosition();
    
    /**
     @brief Method which returns the absolute orientation space of the Entity
     
     @return Returns the absolute space orientation of the Entity
     */
    U4DQuaternion getAbsoluteSpaceOrientation();
    
    /**
     @brief Method which returns the absolute position space of the Entity
     
     @return Returns the absolute space position of the Entity
     */
    U4DQuaternion getAbsoluteSpacePosition();
    
    /**
     @brief Method which sets the local space orientation of the Entity
     
     @param uOrientation Local space orientation for the Entity
     */
    void setLocalSpaceOrientation(U4DQuaternion &uOrientation);
    
    /**
     @brief Method which sets the local space position of the Entity
     
     @param uPosition Local space position for the Entity
     */
    void setLocalSpacePosition(U4DQuaternion &uPosition);
    
    /**
     @brief Method which returns the Local orientation of the Entity
     
     @return Local orientation in 3D vector representation
     */
    U4DVector3n getLocalOrientation();
    
    /**
     @brief Method which returns the local position of the Entity
     
     @return Local position in 3D vector representation
     */
    U4DVector3n getLocalPosition();
    
    /**
     @brief Method which returns the absolute orientation of the Entity
     
     @return Absolute orientation in 3D vector representation
     */
    U4DVector3n getAbsoluteOrientation();
    
    /**
     @brief Method which returns the absolute position of the Entity
     
     @return Absolute position in 3D vector representation
     */
    U4DVector3n getAbsolutePosition();
    
    /**
     @brief Method which returns the forwad vector of the Entity
     
     @return Forward vector of the Entity
     */
    U4DVector3n getEntityForwardVector();
    
    /**
     @brief Method which sets the forward vectof of the Entity. The default value is (0.0,0.0,-1.0)
     
     @param uForwardVector Forward vector for entity
     */
    void setEntityForwardVector(U4DVector3n &uForwardVector);
    
    /**
     @brief Method which returns the absolute orientation of the Entity
     
     @return Returns the absolute orientation of the Entity in 3x3 matrix format
     */
    U4DMatrix3n getAbsoluteMatrixOrientation();
    
    /**
     @brief Method which returns the local orientation of the Entity
     
     @return Returns the local orientation of the Entity in 3x3 matrix format
     */
    U4DMatrix3n getLocalMatrixOrientation();
    
    //Transformation helper functions
    
    /**
     @brief Method which translates entity to a new position
     
     @param translation 3D vector translation
     */
    void translateTo(U4DVector3n& translation);
    
    /**
     @brief Method which translates entity to a new position
     
     @param x Translation along x-coordinate
     @param y Translation along y-coordinate
     @param z Tranalation along z-coordinate
     */
    void translateTo(float x,float y, float z);
    
    /**
     @brief Method which translates entity to a new position
     
     @param Translation 2D vector translation
     */
    void translateTo(U4DVector2n &translation);
    
    /**
     @brief Method which translates entity by certain amount
     
     @param x Translaiion along x-coordinate
     @param y Translation along y-coordinate
     @param z Translation along z-coordinate
     */
    void translateBy(float x,float y, float z);
    
    /**
     @brief Method which translates entity by a certain amount
     
     @param translation 3D vector offset translation
     */
    void translateBy(U4DVector3n& translation);
    
    /**
     @brief Method which rotates entity to a new orientation
     
     @param rotation Quaternion representing orientation
     */
    void rotateTo(U4DQuaternion& rotation);
    
    /**
     @brief Method which rotates entity by a certain amount
     
     @param rotation Quaternion representing orientation
     */
    void rotateBy(U4DQuaternion& rotation);
    
    /**
     @brief Method which rotates entity to a new orientation
     
     @param angle Angle of rotation
     @param axis  Asis of rotation
     */
    void rotateTo(float angle, U4DVector3n& axis);
    
    /**
     @brief Method which rotates entity by certain amount
     
     @param angle Angle of rotation
     @param axis  Axis of rotation
     */
    void rotateBy(float angle, U4DVector3n& axis);

    /**
     @brief Method which rotates entity to a new orientation
     
     @param angleX Angle of rotation along the x-axis
     @param angleY Angle of rotation along the y-axis
     @param angleZ Angle of rotation along the z-axis
     */
    void rotateTo(float angleX, float angleY, float angleZ);
    
    /**
     @brief Method which rotates entity by a certain amount
     
     @param angleX Angle of rotation along x-axis
     @param angleY Angle of rotation along y-axis
     @param angleZ Angle of rotation along z-axis
     */
    void rotateBy(float angleX, float angleY, float angleZ);
    
    /**
     @brief Method which rotates entity about an axis
     
     @param angle           Angle representing rotation
     @param axisOrientation Axis of rotation
     @param axisPosition    Position of rotation axis
     */
    void rotateAboutAxis(float angle, U4DVector3n& axisOrientation, U4DVector3n& axisPosition);
    
    /**
     @brief Method which rotates entity about an axis
     
     @param uOrientation Orientation to rotate
     @param axisPosition Position of axis
     */
    void rotateAboutAxis(U4DQuaternion& uOrientation, U4DVector3n& axisPosition);
    
    /**
     @brief Method which sets the view direction of the entity
     
     @param uDestinationPoint View direction of entity
     */
    virtual void viewInDirection(U4DVector3n& uDestinationPoint){};
    
    /**
     @brief Method which rotates the view direction of the entiy
     
     @return Returns a 3D vector representing the view direction of the entity
     */
    virtual U4DVector3n getViewInDirection(){};
    
    //scenegraph
    /**
     @brief Method which adds a child entity to a scenegraph
     
     @param uChild Child entity to add to scenegraph
     */
    void addChild(U4DEntity *uChild);
    
    /**
     @brief Method which adds a child entity to a scenegraph at a particular location
     
     @param uChild Child entity to add to scenegraph
     @param uNext location to insert child
     */
    void addChild(U4DEntity *uChild, U4DEntity *uNext);
    
    /**
     @brief Method which adds a child entity to a scenegraph at a particular location
     
     @param uChild Child entity to add to scenegraph
     @param uZDepth location to insert child
     */
    void addChild(U4DEntity *uChild, int uZDepth);
    
    /**
     @brief Method which removes a child entity from the scenegraph
     
     @param uChild Child entity to remove from the scenegraph
     */
    void removeChild(U4DEntity *uChild);
    
    /**
     @brief Method which changes the entity's last descendant in the scenegraph
     
     @param uNewLastDescendant Last descendant of the entity
     */
    void changeLastDescendant(U4DEntity *uNewLastDescendant);
    
    /**
     @brief Method which returns the entity's first child in the scenegraph
     
     @return Returns the entity's first child
     */
    U4DEntity *getFirstChild();
    
    /**
     @brief Method which returns the entity's last child in the scenegraph
     
     @return Returns the entity's last child
     */
    U4DEntity *getLastChild();
    
    /**
     @brief Method which returns the entity's next sibling in the scenegraph
     
     @return Returns the entity's next sibling
     */
    U4DEntity *getNextSibling();
    
    /**
     @brief Method which returns the entity's previous sibling in the scenegraph
     
     @return Returns the entity's previous sibling
     */
    U4DEntity *getPrevSibling();
    
    /**
     @brief Method which returns the entity's previous sibling in pre-order traversal order
     
     @return Returns the entity's previous sibling in pre-order traversal order
     */
    U4DEntity *prevInPreOrderTraversal();
    
    /**
     @brief Method which returns the entity's next pointer in pre-order traversal order
     
     @return Returns the entity's next pointer in pre-order traversal order
     */
    U4DEntity *nextInPreOrderTraversal();
    
    /**
     @brief Method which returns true if the entity represents a leaf node in the scenegraph
     
     @return Returns true if the entity represents a leaf node in the scenegraph
     */
    bool isLeaf();
    
    /**
     @brief Method which returns true if the entity represents a root node in the scenegraph
     
     @return Returns true if the entity represents a root node in the scenegraph
     */
    bool isRoot();
    
    /**
     * @brief Renders the current entity
     * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
     *
     * @param uRenderEncoder Metal encoder object for the current entity
     */
    virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder){};
    
    /**
     * @brief Renders the shadow for a 3D entity
     * @details Updates the shadow space matrix, any rendering flags. It also sends the attributes and space uniforms to the GPU
     *
     * @param uRenderShadowEncoder Metal encoder object for the current entity
     * @param uShadowTexture Texture shadow for the current entity
     */
    virtual void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){};
    
    /*
     @todo document this
     */
    virtual void renderOffscreen(id <MTLRenderCommandEncoder> uRenderOffscreenEncoder, id<MTLTexture> uOffscreenTexture){};
    
    /**
     @brief Updates the state of each entity
     
     @param dt time-step value
     */
    virtual void update(double dt){};
    
    /**
     @todo document this
     */
    virtual void updateAllUniforms(){};
    
    /**
     @brief Loads all rendering information for the entiy
     */
    virtual void loadRenderingInformation(){};
    
    /**
     @brief Gets the parent to the entity

     @return pointer to the entity parent
     */
    U4DEntity* getParent();
    
    
    /**
     @brief Gets the root parent (top parent in the scenegraph) of the entity

     @return pointer to the root parent
     */
    U4DEntity* getRootParent();
    
    
    /**
     @brief Searches for an entity

     @param uName name of the entity
     @return pointer to the entity
     */
    U4DEntity *searchChild(std::string uName);
    
    
    /**
     @brief Sets the z-depth value used for rendering ordering

     @param uZDepth z-depth value. Default is 100
     */
    void setZDepth(int uZDepth);
    
    
    /**
     @brief Gets the z-depth value used for rendering ordering

     @return z-depth value
     */
    int getZDepth();
    
    /**
     @brief Self load 3D model into the collision engine
     
     @param uEntityManager pointer to the entity manager
     */
    virtual void loadIntoCollisionEngine(U4DEntityManager *uEntityManager){};
    
    /**
     @brief Self load 3D model into the physics engine
     
     @param uEntityManager pointer to the entity manager
     @param dt time step
     */
    virtual void loadIntoPhysicsEngine(U4DEntityManager *uEntityManager, float dt){};
    
    /**
     @brief self load 3d model into the visibility manager
     
     @param uEntityManager pointer to the entity manager
     */
    virtual void loadIntoVisibilityManager(U4DEntityManager *uEntityManager){};
    
    /**
     @brief clear collision information, resets time of impact, resets equilibrium, clears collision list
     */
    virtual void cleanUp(){};
    
    /**
     @brief Method which returns if the model can detect collisions
     
     @return Returns true if the model can detect collisions
     */
    virtual bool isCollisionBehaviorEnabled(){};
    
    /**
     @brief Method which returns if kinetics behavior are allowed to act on the 3D model
     
     @return Returns true if kinetics behavior are allowed to act on the 3D model
     */
    virtual bool isKineticsBehaviorEnabled(){};
    
    virtual bool changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition){};
    
};

}

#endif /* defined(__UntoldEngine__U4DEntity__) */
