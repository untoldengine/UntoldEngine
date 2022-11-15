//
//  SandboxLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "SandboxLogic.h"
#include "U4DVoronoiManager.h"
#import <TargetConditionals.h>
#include "U4DDirector.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "SandboxWorld.h"
#include "U4DGameConfigs.h"
#include "U4DScriptManager.h"
#include "U4DCamera.h"

#include "U4DAnimationManager.h"


#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DSceneStateManager.h"
#include "U4DSceneEditingState.h"
#include "U4DScenePlayState.h"



#include "U4DClientManager.h"
#include "U4DLayerManager.h"
#include "U4DLayer.h"
#include "U4DDebugger.h"
#include "U4DCameraInterface.h"
#include "U4DCameraBasicFollow.h"

#include "U4DScriptManager.h"

#include "U4DPlayerStateIdle.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateShooting.h"
#include "U4DPlayerStatePass.h"
#include "U4DPlayerStateJump.h"
#include "U4DPlayerStateHalt.h"

#include "U4DBall.h"

#include "U4DGameConfigs.h"
#include "U4DMatchManager.h"
#include "U4DTeamStateReady.h"

#include "U4DField.h"
#include "U4DGoalPost.h"



SandboxLogic::SandboxLogic():pPlayer(nullptr),teamA(nullptr),dribblingDirection(0.0,0.0,-1.0),startGame(false),aKeyFlag(false),sKeyFlag(false),wKeyFlag(false),dKeyFlag(false),playerMotionAccumulator(0.0,0.0,0.0){
    
}

SandboxLogic::~SandboxLogic(){
    
}

void SandboxLogic::update(double dt){
    U4DEngine::U4DMatchManager *matchManager=U4DEngine::U4DMatchManager::sharedInstance();
    if(pPlayer!=nullptr && startGame==true){
//        teamA->update(dt);
//        teamB->update(dt);
//        matchManager->update(dt);
//
        pPlayer=matchManager->teamA->getActivePlayer();
//
//        //field->shadeField(pPlayer);
//
//        U4DEngine::U4DVoronoiManager *voronoi=U4DEngine::U4DVoronoiManager::sharedInstance();
//
//        voronoi->computeFortuneAlgorithm();
//
//        std::vector<U4DEngine::U4DSegment> segments=voronoi->getVoronoiSegments();
//
//        voronoiPlane->shade(segments);
        
        
    }
    
}

void SandboxLogic::init(){
    
    //1. Get a pointer to the LevelOneWorld object
    SandboxWorld* pEarth=dynamic_cast<SandboxWorld*>(getGameWorld());
    U4DEngine::U4DMatchManager *matchManager=U4DEngine::U4DMatchManager::sharedInstance();
    
    voronoiPlane=new U4DEngine::U4DVoronoiPlane();
    
    U4DEngine::U4DPlayer* pPlayer0=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("player0.0"));
    U4DEngine::U4DPlayer* pPlayer1=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("player0.1"));
    U4DEngine::U4DPlayer* pPlayer2=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("player0.2"));
//    U4DEngine::U4DPlayer* pPlayer3=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("player0.3"));
//    U4DEngine::U4DPlayer* pPlayer4=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("player0.4"));
//
//    U4DEngine::U4DPlayer* pEPlayer0=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("oppositeplayer0.0"));
//    U4DEngine::U4DPlayer* pEPlayer1=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("oppositeplayer0.1"));
//    U4DEngine::U4DPlayer* pEPlayer2=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("oppositeplayer0.2"));
//    U4DEngine::U4DPlayer* pEPlayer3=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("oppositeplayer0.3"));
//    U4DEngine::U4DPlayer* pEPlayer4=dynamic_cast<U4DEngine::U4DPlayer*>(pEarth->searchChild("oppositeplayer0.4"));
    
    
//    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
//
//    float fieldHalfWidth=gameConfigs->getParameterForKey("fieldHalfWidth");
//    float fieldHalfLength=gameConfigs->getParameterForKey("fieldHalfLength");
//
//    //Update player position
//    U4DVector3n pos=pPlayer0->getAbsolutePosition();
//
//    pos.x/=fieldHalfWidth;
//    pos.z/=fieldHalfLength;
//
//
//
    
    
//    field=dynamic_cast<U4DEngine::U4DField*>(pEarth->searchChild("field.0"));
//    U4DEngine::U4DGoalPost* goalPostB=dynamic_cast<U4DEngine::U4DGoalPost*>(pEarth->searchChild("fieldgoal.0"));
//    U4DEngine::U4DGoalPost* goalPostA=dynamic_cast<U4DEngine::U4DGoalPost*>(pEarth->searchChild("fieldgoal.1"));
//
    U4DEngine::U4DBall *ball=U4DEngine::U4DBall::sharedInstance();
     if (ball->init("ball")) {
         pEarth->addChild(ball);
          
     }
        
//    U4DEngine::U4DText *scoreA=new U4DEngine::U4DText("dribblyFont");
//    U4DEngine::U4DText *scoreB=new U4DEngine::U4DText("dribblyFont");
//    U4DEngine::U4DText *gameClock=new U4DEngine::U4DText("dribblyFont");
//    U4DEngine::U4DText *broadCastMessage=new U4DEngine::U4DText("uiFont");
//
//    scoreA->translateBy(-0.3,0.8,0.0);
//    scoreB->translateBy(0.35,0.8,0.0);
//    gameClock->translateBy(-0.1,0.8,0.0);
//    broadCastMessage->translateBy(0.0, 0.7, 0.0);
//
//    pEarth->addChild(scoreA,-20);
//    pEarth->addChild(scoreB,-20);
//    pEarth->addChild(gameClock,-20);
//    pEarth->addChild(broadCastMessage,-20);
//
//    {
        
        matchManager->teamA->addPlayer(pPlayer0);
        matchManager->teamA->addPlayer(pPlayer1);
        matchManager->teamA->addPlayer(pPlayer2);
//        matchManager->teamA->addPlayer(pPlayer3);
//        matchManager->teamA->addPlayer(pPlayer4);
//
//        matchManager->teamB->addPlayer(pEPlayer0);
//        matchManager->teamB->addPlayer(pEPlayer1);
//        matchManager->teamB->addPlayer(pEPlayer2);
//        matchManager->teamB->addPlayer(pEPlayer3);
//        matchManager->teamB->addPlayer(pEPlayer4);
        
        pPlayer=pPlayer0;
        
        matchManager->teamA->setActivePlayer(pPlayer);
//        matchManager->teamB->aiTeam=true;
//
//        matchManager->initMatchElements(goalPostA,goalPostB,field);
        
//        teamA=new U4DEngine::U4DTeam("teamA");
//        teamB=new U4DEngine::U4DTeam("teamB");
//
//        teamA->setOppositeTeam(teamB);
//        teamB->setOppositeTeam(teamA);
//
//        teamA->addPlayer(pPlayer);
//        //teamA->addPlayer(pPlayer1);
//
//        teamB->addPlayer(pPlayer1);
//        teamB->addPlayer(pPlayer2);
//        teamB->addPlayer(pPlayer3);
//        teamB->addPlayer(pPlayer4);
//        teamB->addPlayer(pPlayer5);
//
//        teamA->setActivePlayer(pPlayer);
//        teamA->loadPlayersFormations();
//        teamA->initAnalyzerSchedulers();
//
//        teamB->loadPlayersFormations();
//        teamB->initAnalyzerSchedulers();
//
//        teamB->aiTeam=true;
//        teamA->changeState(U4DEngine::U4DTeamStateReady::sharedInstance());
//        teamB->changeState(U4DEngine::U4DTeamStateReady::sharedInstance());
        
//        matchManager->initTextElements(scoreA, scoreB, gameClock,broadCastMessage);
//        matchManager->initMatchTimer(60.0,1.0);
//
//        U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
//        U4DEngine::U4DCameraBasicFollow *cameraBasicFollow=U4DEngine::U4DCameraBasicFollow::sharedInstance();
//        U4DEngine::U4DPoint3n minBox(-2.0,-2.0,-2.0);
//        U4DEngine::U4DPoint3n maxBox(2.0,2.0,2.0);
//        cameraBasicFollow->setParameters(pPlayer, 0.0, 20.0, -40.0);
//
//        camera->setCameraBehavior(cameraBasicFollow);
//
//        U4DEngine::U4DVoronoiManager *voronoi=U4DEngine::U4DVoronoiManager::sharedInstance();
//
//        voronoi->computeFortuneAlgorithm();
//        voronoi->computeAreas();
//        std::vector<U4DEngine::U4DSegment> segments=voronoi->getVoronoiSegments();
//
//
//        if (voronoiPlane->init("voronoiplane")) {
//
//            pEarth->addChild(voronoiPlane);
//            voronoiPlane->shade(segments);
//
//        }
        
        startGame=true;
}



void SandboxLogic::receiveUserInputUpdate(void *uData){
    
    U4DEngine::U4DMatchManager *matchManager=U4DEngine::U4DMatchManager::sharedInstance();
    
    
    if (pPlayer!=nullptr && startGame==true ) {
        
        if(isKeyPressed(U4DEngine::macKeyA, uData)){
            
            dribblingDirection=U4DEngine::U4DVector3n(-1.0,0.0,0.0);

            aKeyFlag=true;

            if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                pPlayer->setEnableDribbling(true);
                //pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
            }
            
        }else if(isKeyReleased(U4DEngine::macKeyA, uData)){
            
            aKeyFlag=false;

            if((aKeyFlag || wKeyFlag || sKeyFlag || dKeyFlag)==0 && (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance()&& pPlayer->getCurrentState()==U4DEngine::U4DPlayerStateDribbling::sharedInstance())){
                //pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                pPlayer->setEnableHalt(true);
            }
            
        }
        
        if(isKeyActive(U4DEngine::macKeyA, uData)){
            dribblingDirection+=U4DEngine::U4DVector3n(-1.0,0.0,0.0);
            dribblingDirection.normalize();
        }
        
        //S key pressed
        if(isKeyPressed(U4DEngine::macKeyS, uData)){
            
            dribblingDirection=U4DEngine::U4DVector3n(0.0,0.0,-1.0);

            sKeyFlag=true;

            if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                pPlayer->setEnableDribbling(true);
                //pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
            }
            
        }else if(isKeyReleased(U4DEngine::macKeyS, uData)){
            
            sKeyFlag=false;

            if((aKeyFlag || wKeyFlag || sKeyFlag || dKeyFlag)==0 && (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance()&& pPlayer->getCurrentState()==U4DEngine::U4DPlayerStateDribbling::sharedInstance())){
                //pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                pPlayer->setEnableHalt(true);
            }
        }
        
        if(isKeyActive(U4DEngine::macKeyS, uData)){
            dribblingDirection+=U4DEngine::U4DVector3n(0.0,0.0,-1.0);
            dribblingDirection.normalize();
        }
        
        //w key pressed
        if(isKeyPressed(U4DEngine::macKeyW, uData)){
            
            dribblingDirection=U4DEngine::U4DVector3n(0.0,0.0,1.0);

            wKeyFlag=true;

            if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                pPlayer->setEnableDribbling(true);
                //pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
            
            }
            
        }else if(isKeyReleased(U4DEngine::macKeyW, uData)){
            
            wKeyFlag=false;

            if((aKeyFlag || wKeyFlag || sKeyFlag || dKeyFlag)==0 && (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance()&& pPlayer->getCurrentState()==U4DEngine::U4DPlayerStateDribbling::sharedInstance())){
                //pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                pPlayer->setEnableHalt(true);
            }
            
        }
        
        if(isKeyActive(U4DEngine::macKeyW, uData)){
           
            dribblingDirection+=U4DEngine::U4DVector3n(0.0,0.0,1.0);
            dribblingDirection.normalize();
        }
        
        //D key pressed
        if(isKeyPressed(U4DEngine::macKeyD, uData)){
            
            dribblingDirection=U4DEngine::U4DVector3n(1.0,0.0,0.0);

            dKeyFlag=true;

            if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                //pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
                pPlayer->setEnableDribbling(true);
            }
            
        }else if(isKeyReleased(U4DEngine::macKeyD, uData)){
            
            dKeyFlag=false;

            if((aKeyFlag || wKeyFlag || sKeyFlag || dKeyFlag)==0 && (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance()&& pPlayer->getCurrentState()==U4DEngine::U4DPlayerStateDribbling::sharedInstance())){
                //pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                pPlayer->setEnableHalt(true);
            }

        }
        
        if(isKeyActive(U4DEngine::macKeyD, uData)){
            dribblingDirection+=U4DEngine::U4DVector3n(1.0,0.0,0.0);
            dribblingDirection.normalize();
        }
        
        if(isKeyReleased(U4DEngine::macKeyJ, uData)){
            pPlayer->setEnableShooting(true);
        }
        
        if(isKeyReleased(U4DEngine::macKeyK, uData)){
            pPlayer->setEnablePassing(true);
        }
        
        pPlayer->setDribblingDirection(dribblingDirection);
    }
    
    /*
    U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;
    U4DEngine::U4DMatchManager *matchManager=U4DEngine::U4DMatchManager::sharedInstance();
    
    if (pPlayer!=nullptr && startGame==true && matchManager->getState()==U4DEngine::playing) {

            switch (controllerInputMessage.inputElementType) {

                case U4DEngine::uiButton:

                    if(controllerInputMessage.inputElementAction==U4DEngine::uiButtonPressed){


                        if (controllerInputMessage.elementUIName.compare("buttonA")==0) {

                            //std::cout<<"Button A pressed"<<std::endl;


                        }

                    }else if (controllerInputMessage.inputElementAction==U4DEngine::uiButtonReleased){

                        if (controllerInputMessage.elementUIName.compare("buttonA")==0) {

                            //std::cout<<"Button A released"<<std::endl;
                            pPlayer->setEnableShooting(true);

                        }

                    }

                    break;

                case U4DEngine::uiSlider:

                    if(controllerInputMessage.inputElementAction==U4DEngine::uiSliderMoved){


                        if (controllerInputMessage.elementUIName.compare("sliderA")==0) {



                        }else if(controllerInputMessage.elementUIName.compare("sliderB")==0){



                        }

                    }

                    break;

                case U4DEngine::uiJoystick:

                if(controllerInputMessage.inputElementAction==U4DEngine::uiJoystickMoved){


                    if (controllerInputMessage.elementUIName.compare("joystick")==0) {

                        //Get the direction of the joystick
                        U4DEngine::U4DVector2n digitalJoystickDirection=controllerInputMessage.joystickDirection;

                        U4DEngine::U4DVector3n joystickDirection3d(digitalJoystickDirection.x,0.0,digitalJoystickDirection.y);

                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                            pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
                        }

                        pPlayer->setDribblingDirection(joystickDirection3d);

                    }

                }else if (controllerInputMessage.inputElementAction==U4DEngine::uiJoystickReleased){

                    if (controllerInputMessage.elementUIName.compare("joystick")==0) {

                        //std::cout<<"joystick released"<<std::endl;
                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                            pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                        }

                    }

                }

                break;

                case U4DEngine::uiCheckbox:

                    if(controllerInputMessage.inputElementAction==U4DEngine::uiCheckboxPressed){


                        if (controllerInputMessage.elementUIName.compare("checkboxA")==0) {



                        }else if(controllerInputMessage.elementUIName.compare("checkboxB")==0){


                        }

                    }

                    break;

                case U4DEngine::mouseLeftButton:
                {
                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::mouseLeftButtonPressed) {

                        //std::cout<<"left clicked"<<std::endl;

                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseLeftButtonReleased){

                        
                    }
                }

                    break;

                case U4DEngine::mouseRightButton:
                {
                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::mouseRightButtonPressed) {

                        //std::cout<<"left clicked"<<std::endl;

                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseRightButtonReleased){

                        

                    }
                }

                    break;

                case U4DEngine::macArrowKey:

                {

                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macArrowKeyActive) {

                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                            pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
                        }

                        U4DEngine::U4DVector2n arrowkeyDirection=controllerInputMessage.arrowKeyDirection;
                        U4DEngine::U4DVector3n dribblingDirection(arrowkeyDirection.x,0.0,arrowkeyDirection.y);

                        pPlayer->setDribblingDirection(dribblingDirection);

                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macArrowKeyReleased){

                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                            pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                        }
                    }
                }

                    break;

                    //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
                case U4DEngine::macKeyA:
                {

                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {

                        dribblingDirection=U4DEngine::U4DVector3n(-1.0,0.0,0.0);

                        aKeyFlag=true;

                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                            pPlayer->setEnableDribbling(true);
                            //pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
                        }


                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){

                        aKeyFlag=false;

                        if((aKeyFlag || wKeyFlag || sKeyFlag || dKeyFlag)==0 && (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance()&& pPlayer->getCurrentState()==U4DEngine::U4DPlayerStateDribbling::sharedInstance())){
                            //pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                            pPlayer->setEnableHalt(true);
                        }

                    }
                    
                    if(controllerInputMessage.inputElementAction==U4DEngine::macKeyActive){
                        dribblingDirection+=U4DEngine::U4DVector3n(-1.0,0.0,0.0);
                        dribblingDirection.normalize();
                    }
                }

                    break;

                    //6. Did Button B on a mobile or game controller receive an action from the user. (Key D on Mac)
                case U4DEngine::macKeyD:
                {
                    //7. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {

                        dribblingDirection=U4DEngine::U4DVector3n(1.0,0.0,0.0);

                        dKeyFlag=true;

                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                            //pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
                            pPlayer->setEnableDribbling(true);
                        }


                        //8. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){

                        dKeyFlag=false;

                        if((aKeyFlag || wKeyFlag || sKeyFlag || dKeyFlag)==0 && (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance()&& pPlayer->getCurrentState()==U4DEngine::U4DPlayerStateDribbling::sharedInstance())){
                            //pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                            pPlayer->setEnableHalt(true);
                        }

                    }
                    
                    if(controllerInputMessage.inputElementAction==U4DEngine::macKeyActive){
                        dribblingDirection+=U4DEngine::U4DVector3n(1.0,0.0,0.0);
                        dribblingDirection.normalize();
                    }

                }

                    break;

                case U4DEngine::macKeyW:
                {
                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {

                        dribblingDirection=U4DEngine::U4DVector3n(0.0,0.0,1.0);

                        wKeyFlag=true;

                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                            pPlayer->setEnableDribbling(true);
                            //pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
                        
                        }


                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){

                        wKeyFlag=false;

                        if((aKeyFlag || wKeyFlag || sKeyFlag || dKeyFlag)==0 && (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance()&& pPlayer->getCurrentState()==U4DEngine::U4DPlayerStateDribbling::sharedInstance())){
                            //pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                            pPlayer->setEnableHalt(true);
                        }

                    }
                    
                    if(controllerInputMessage.inputElementAction==U4DEngine::macKeyActive){
                        dribblingDirection+=U4DEngine::U4DVector3n(0.0,0.0,1.0);
                        dribblingDirection.normalize();
                    }

                }
                    break;

                case U4DEngine::macKeyS:
                {
                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {

                        dribblingDirection=U4DEngine::U4DVector3n(0.0,0.0,-1.0);

                        sKeyFlag=true;

                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
                            pPlayer->setEnableDribbling(true);
                            //pPlayer->changeState(U4DEngine::U4DPlayerStateDribbling::sharedInstance());
                        }


                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){

                        sKeyFlag=false;

                        if((aKeyFlag || wKeyFlag || sKeyFlag || dKeyFlag)==0 && (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance()&& pPlayer->getCurrentState()==U4DEngine::U4DPlayerStateDribbling::sharedInstance())){
                            //pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
                            pPlayer->setEnableHalt(true);
                        }

                    }
                    
                    if(controllerInputMessage.inputElementAction==U4DEngine::macKeyActive){
                        dribblingDirection+=U4DEngine::U4DVector3n(0.0,0.0,-1.0);
                        dribblingDirection.normalize();
                    }

                }
                    break;

    #if TARGET_OS_MAC && !TARGET_OS_IPHONE
                //both keys P and U are used to set the scene into a Play or Pause status, respectively. They are only used for testing
                case U4DEngine::macKeyP:
                {

                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {



                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){

                        U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();

                        U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
                        U4DEngine::U4DScene *scene=sceneManager->getCurrentScene();
                        U4DEngine::U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();

                        if(sceneStateManager->getCurrentState()==U4DEngine::U4DSceneEditingState::sharedInstance()){
                            //change scene state to edit mode
                            scene->getSceneStateManager()->changeState(U4DEngine::U4DScenePlayState::sharedInstance());

                        }else if(sceneStateManager->getCurrentState()==U4DEngine::U4DScenePlayState::sharedInstance()){

                            scene->setPauseScene(false);

                        }

                        scene->setAnchorMouse(true);

                        [NSCursor hide];

                        logger->log("Game was resumed");

                    }

                }
                    break;

                case U4DEngine::macKeyU:
                {

                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {



                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){

                        U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();

                        U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
                        U4DEngine::U4DScene *scene=sceneManager->getCurrentScene();

                        U4DEngine::U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();

                        if (sceneStateManager->getCurrentState()==U4DEngine::U4DScenePlayState::sharedInstance()) {

                            //change scene state to pause
                            scene->setPauseScene(true);

                            logger->log("Game was paused");

                            scene->setAnchorMouse(false);

                            [NSCursor unhide];

                        }

                    }

                }
                    break;
    #endif

                case U4DEngine::macShiftKey:
                {
                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {


                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){

                        //pPlayer->setEnablePassing(true);

                    }

                }
                    break;

                case U4DEngine::macSpaceKey:
                {


                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {

//                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateJump::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateFalling::sharedInstance()){
//                            pPlayer->changeState(U4DEngine::U4DPlayerStateJump::sharedInstance());
//                        }



                    }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){

//                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateFalling::sharedInstance()){
//                            pPlayer->changeState(U4DEngine::U4DPlayerStateFalling::sharedInstance());
//                        }

                        pPlayer->setEnableShooting(true);
                    }

                }
                    break;

                case U4DEngine::padButtonA:

                    if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {



                    }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){

                    }

                    break;

                case U4DEngine::padButtonB:

                    if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {



                    }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){

                    }

                    break;

                case U4DEngine::padRightTrigger:

                    if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {



                    }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){

                    }

                    break;

                case U4DEngine::padLeftTrigger:

                    if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {



                    }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){


                    }

                break;

                case U4DEngine::padLeftThumbstick:

                    if(controllerInputMessage.inputElementAction==U4DEngine::padThumbstickMoved){

                       //Get joystick direction
                       U4DEngine::U4DVector3n joystickDirection(controllerInputMessage.joystickDirection.x,0.0,controllerInputMessage.joystickDirection.y);




                   }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){




                   }

                break;

                case U4DEngine::mouse:
                {

                    if(controllerInputMessage.inputElementAction==U4DEngine::mouseActiveDelta){

//                        //Get the delta movement of the mouse
//                        U4DEngine::U4DVector2n delta=controllerInputMessage.mouseDeltaPosition;
//                        //the y delta should be flipped
//                        delta.y*=-1.0;
//
//                        //The following snippet will determine which way to rotate the model depending on the motion of the mouse
//
//                        delta.normalize();
//
//                        U4DEngine::U4DVector3n axis;
//
//                        U4DEngine::U4DVector3n mousedirection(delta.x,0.0,delta.y);
//                        float biasPlayerMotionAccumulator=0.85;
//
//                        playerMotionAccumulator=playerMotionAccumulator*biasPlayerMotionAccumulator+mousedirection*(1.0-biasPlayerMotionAccumulator);
//
//                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateHalt::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStatePass::sharedInstance() && pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateDribbling::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateIntercept::sharedInstance()&& pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateFree::sharedInstance()){
//
//                             pPlayer->setMoveDirection(playerMotionAccumulator);
//                         }
//
//                        if (pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStatePass::sharedInstance()) {
//                            pPlayer->setEnableDribbling(true);
//
//                            pPlayer->setDribblingDirection(playerMotionAccumulator);
//                        }


                    }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseInactive){

//                        if(pPlayer->getCurrentState()!=U4DEngine::U4DPlayerStateShooting::sharedInstance()){
//                            pPlayer->changeState(U4DEngine::U4DPlayerStateIdle::sharedInstance());
//                        }
                    }

                }

                    break;

                default:
                    break;
            }

        pPlayer->setDribblingDirection(dribblingDirection);

        }
    */
}
