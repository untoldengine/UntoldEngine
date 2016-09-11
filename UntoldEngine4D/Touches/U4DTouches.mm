//
//  Touches.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DTouches.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DTouches::U4DTouches(float uXTouch,float uYTouch):xTouch(uXTouch),yTouch(uYTouch){}
    
    U4DTouches::~U4DTouches(){}
    
    void U4DTouches::setPoint(float uXTouch,float uYTouch){
        xTouch=uXTouch;
        yTouch=uYTouch;
    }
    
    U4DVector2n U4DTouches::getPoint(){
        U4DVector2n touch;
        
        touch.x=this->xTouch;
        touch.y=this->yTouch;
        
        return touch;
    }
    
/*
void U4DTouches::update(float xPos,float yPos,TouchState touchState){
    
    //convert the recieved point to openGL
    U4DDirector *director=U4DDirector::sharedInstance();
    U4DVector2n point=director->pointToOpenGL(xPos, yPos);
    
    xTouch=point.x;
    yTouch=point.y;
    
   
    for (int i=0; i<buttonArray.size(); i++) {
        
        U4DButton *button=buttonArray.at(i);
        
        //get the coordinates of the box
        U4DVector3n centerPosition=button->getPosition();
        
        
        float left=centerPosition.x-button->buttonWidth;
        float right=centerPosition.x+button->buttonWidth;
        
        float top=centerPosition.y+button->buttonHeight;
        float bottom=centerPosition.y-button->buttonHeight;
        
        if (xTouch>left && xTouch<right) {
            
            if (yTouch>bottom && yTouch<top) {
                
                cout<<"im hit"<<endl;
            }
        }
        
        
    }
 
}
*/
}