//
//  Earth.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__Earth__
#define __UntoldEngine__Earth__

#include <iostream>
#include "U4DWorld.h"
#include "U4DVector3n.h"

class MyCharacter;

class GameController;
class Rocket;
class Floor;
class Mountain;
class Planet;
class Meteor;
class Tree;
class Cloud;

class Earth:public U4DEngine::U4DWorld{

private:
    Rocket *rocket;
    Floor *floor;
    Floor *floor2;
    Mountain *mountain;
    Mountain *mountain2;
    Mountain *mountain3;
    Mountain *mountain4;
    Planet *planet;
    Meteor *meteor1;
    Meteor *meteor2;
    Meteor *meteor3;
    Meteor *meteor4;
    Meteor *meteor5;
    Tree *tree1;
    Tree *tree2;
    Tree *tree3;
    Tree *tree4;
    Cloud *cloud1;
    Cloud *cloud2;
    Cloud *cloud3;
    Cloud *cloud4;
    Cloud *cloud5;
    
public:
   
    Earth(){
        
    };
    
    void init();
    void action();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */
