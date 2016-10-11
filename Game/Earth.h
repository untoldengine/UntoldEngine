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
class Tree;
class Fountain;
class Castle;
class Bench;
class Steps;

class Earth:public U4DEngine::U4DWorld{

private:
    
    MyCharacter *ninja;
    
    Floor *floor;
    Floor *floor2;
    Floor *floor3;
    Fountain *fountain;
    Castle *castle;
    Tree *tree1;
    Tree *tree2;
    Tree *tree3;
    Tree *tree4;
    Tree *tree5;
    Tree *tree6;
    Tree *tree7;
    Bench *bench1;
    Bench *bench2;
    Bench *bench3;
    Bench *bench4;
    Bench *bench5;
    Bench *bench6;
    
    Steps *steps1;
    Steps *steps2;
    Steps *steps3;
    Steps *steps4;
    Steps *steps5;
    Steps *steps6;
    Steps *steps7;
    Steps *steps8;
    Steps *steps9;
    
public:
   
    Earth(){
        
    };
    
    void init();
    void action();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */
