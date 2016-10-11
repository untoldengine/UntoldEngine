//
//  Earth.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "Earth.h"

#include "CommonProtocols.h"

#include <stdio.h>

#include "U4DDirector.h"

#include "MyCharacter.h"
#include "U4DMatrix3n.h"
#include "U4DButton.h"
#include "U4DSkyBox.h"
#include "U4DTouches.h"
#include "U4DCamera.h"
#include "U4DControllerInterface.h"

#include "GameController.h"
#include "U4DSprite.h"
#include "U4DLights.h"
#include "U4DLogger.h"
#include "Floor.h"
#include "Fountain.h"
#include "Castle.h"
#include "Tree.h"
#include "Bench.h"
#include "Steps.h"

using namespace U4DEngine;

void Earth::init(){
    
    U4DCamera *camera=U4DCamera::sharedInstance();
    camera->translateBy(0.0, 2.0, 10.0);
    //camera->rotateTo(0.0,-20.0,0.0);
   
    //create character
    ninja=new MyCharacter();
    ninja->init("ninja", "blenderscript.u4d");
    
    //create the floor
    floor=new Floor();
    floor->init("platform1","blenderscript.u4d");
    
    floor2=new Floor();
    floor2->init("platform2","blenderscript.u4d");
  
    floor3=new Floor();
    floor3->init("platform3","blenderscript.u4d");

    //create the trees
    tree1=new Tree();
    tree1->init("tree1", "blenderscript.u4d");
   
    tree2=new Tree();
    tree2->init("tree2", "blenderscript.u4d");
    
    tree3=new Tree();
    tree3->init("tree3", "blenderscript.u4d");
    
    tree4=new Tree();
    tree4->init("tree4", "blenderscript.u4d");

    tree5=new Tree();
    tree5->init("tree5", "blenderscript.u4d");
    
    tree6=new Tree();
    tree6->init("tree6", "blenderscript.u4d");
    
    tree7=new Tree();
    tree7->init("tree7", "blenderscript.u4d");
    
    //create the castle
    castle=new Castle();
    castle->init("castle", "blenderscript.u4d");
    
    
    //create the fountain
    fountain=new Fountain();
    fountain->init("fountain", "blenderscript.u4d");
    
    //create the benches
    bench1=new Bench();
    bench1->init("bench1","blenderscript.u4d");

    bench2=new Bench();
    bench2->init("bench2","blenderscript.u4d");
    
    bench3=new Bench();
    bench3->init("bench3","blenderscript.u4d");
    
    bench4=new Bench();
    bench4->init("bench4","blenderscript.u4d");
    
    bench5=new Bench();
    bench5->init("bench5","blenderscript.u4d");
    
    bench6=new Bench();
    bench6->init("bench6","blenderscript.u4d");
    
    //create the steps
    steps1=new Steps();
    steps1->init("step1", "blenderscript.u4d");

    steps2=new Steps();
    steps2->init("step2", "blenderscript.u4d");
    
    steps3=new Steps();
    steps3->init("step3", "blenderscript.u4d");
    
    steps4=new Steps();
    steps4->init("step4", "blenderscript.u4d");
    
    steps5=new Steps();
    steps5->init("step5", "blenderscript.u4d");
    
    steps6=new Steps();
    steps6->init("step6", "blenderscript.u4d");
    
    steps7=new Steps();
    steps7->init("step7", "blenderscript.u4d");
    
    steps8=new Steps();
    steps8->init("step8", "blenderscript.u4d");
    
    steps9=new Steps();
    steps9->init("step9", "blenderscript.u4d");
    
    U4DVector3n origin(0,0,0);
    
    camera->viewInDirection(origin);

    U4DLights *light=U4DLights::sharedInstance();
    light->translateTo(5.0,5.0,5.0);
    light->viewInDirection(origin);
    
    addChild(ninja);
    
    addChild(floor);
    addChild(floor2);
    addChild(floor3);
    
    addChild(tree1);
    addChild(tree2);
    addChild(tree3);
    addChild(tree4);
    addChild(tree5);
    addChild(tree6);
    addChild(tree7);
    
    addChild(castle);
    addChild(fountain);
    
    addChild(steps1);
    addChild(steps2);
    addChild(steps3);
    addChild(steps4);
    addChild(steps5);
    addChild(steps6);
    addChild(steps7);
    addChild(steps8);
    addChild(steps9);

    addChild(bench1);
    addChild(bench2);
    addChild(bench3);
    addChild(bench4);
    addChild(bench5);
    addChild(bench6);
    
    initLoadingModels();
    
    
}

void Earth::update(double dt){
    
    //U4DCamera *camera=U4DCamera::sharedInstance();
    //camera->followModel(rocket, 0.0, 2.0, 6.0);
    

}

void Earth::action(){
    
    setEntityControlledByController(this);
    
}




