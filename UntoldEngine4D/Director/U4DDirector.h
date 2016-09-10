//
//  U4DDirector.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MVCTemplate__U4DDirector__
#define __MVCTemplate__U4DDirector__


#include <iostream>
#include <vector>
#include <iterator>
#include "U4DShaderManager.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
class U4DEntity;
class U4DShaderManager;
class U4DScene;
class U4DWorld;
class U4DCharacterManager;
class U4DData;
class U4DTouches;
class U4DGameModelInterface;
class U4DVector2n;
class U4DControllerInterface;
class U4DTouches;
}

namespace U4DEngine {
    
/**
 @brief  The U4DDirector class controls the updates and rendering of every game entity. It informs the engine of any touch event. It loads every shader used in the engine.
 */

class U4DDirector{
  
private:
    
    
    /**
     @brief Pointer representing the scene of the game
     */
    U4DScene *scene;
    
    /**
     @brief The shader manager is in charge of loading and compiling the shaders
     */
    U4DShaderManager shaderManager;
    
    /**
     @brief ios device display width
     */
    float displayWidth;
    
    /**
     @brief ios device display height
     */
    float displayHeight;
    
    /**
     @brief Container for all shader programs
     */
    std::vector<GLuint> shaderProgram;
    
    /**
     @brief Time step accumulator
     */
    float accumulator;
    
protected:
    
    /**
     @brief Director Constructor
     */
    U4DDirector();
    
    /**
     @brief Director Destructor
     */
    ~U4DDirector();
    
    /**
     @brief Copy constructor
     */
    U4DDirector(const U4DDirector& value);

    /**
     @brief Copy constructor
     */
    U4DDirector& operator=(const U4DDirector& value);
    
public:
    
    /**
     @brief Instance for U4DDirector Singleton
     */
    static U4DDirector* instance;
    
    /**
     @brief Method which returns an instance of the U4DDirector singleton
     
     @return instance of the U4DDirector singleton
     */
    static U4DDirector* sharedInstance();
    
    /**
     @brief Method in charge of starting the rendering process.
     */
    void draw();
    
    /**
     @brief Method in charge of updating the states of each entity
     
     @param dt time value
     */
    void update(double dt);
    
    /**
     @brief  Init
     @todo  This method is empty
     */
    void init();
    
    /**
     @brief Method which loads all OpenGL Shaders 
     */
    void loadShaders();
    
    /**
     @brief Method which sets the active scene for the game
     
     @param uScene Pointer to the scene to make active
     */
    void setScene(U4DScene *uScene);
    
    /**
     @brief Method which adds a shader into the shader vector-container
     
     @param uShaderValue shader to add into the vector-container
     */
    void addShaderProgram(GLuint uShaderValue);

    /**
     @brief Method which returns the current index position of the shader in the shader vector-container
     
     @param uShader Name of shader
     
     @return Index position of the shader in the vector-container
     */
    GLuint getShaderProgram(std::string uShader);

    
    /**
     @brief Method which sets the dimension of the display screen
     
     @param uWidth  display width
     @param uHeight display height
     */
    void setDisplayWidthHeight(float uWidth,float uHeight);
   
    /**
     @brief Method which returns the height of the display screen
     
     @return Returns the height of the display screen
     */
    float getDisplayHeight();
    
    /**
     @brief Method which returns the width of the display screen
     
     @return Returns the width of the display screen
     */
    float getDisplayWidth();
    
    /**
     @brief Method which converts a screen point coordinate into an opengl point coordinate
     
     @param xPoint x-coordinate in screen space
     @param yPoint y-coordinate in screen space
     
     @return Returns a 2D vector of the point in opengl coordinate space
     */
    U4DVector2n pointToOpenGL(float xPoint,float yPoint);
    
    /**
     @brief Method which informs the engine that a touch event has started
     
     @param touches touch event
     */
    void touchBegan(const U4DTouches &touches);
    
    /**
     @brief Method which informs the engine that a touch event has ended
     
     @param touches touch event
     */
    void touchEnded(const U4DTouches &touches);
    
    /**
     @brief Method which informs the engine that a touch event is moving
     
     @param touches touch event
     */
    void touchMoved(const U4DTouches &touches);
    
};

}

#endif /* defined(__MVCTemplate__U4DDirector__) */
