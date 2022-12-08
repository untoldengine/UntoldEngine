//
//  U4DEditor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/26/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DEditor.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DSceneStateManager.h"
#include "U4DSceneEditingState.h"
#include "U4DScenePlayState.h"
#include "U4DCamera.h"
#include "U4DWorld.h"
#include "U4DModel.h"
#include "U4DResourceLoader.h"
#include "U4DEntityFactory.h"
#include "U4DRenderManager.h"

#include "U4DSerializer.h"
#include "U4DRay.h"
#include "U4DAABB.h"

#include "U4DDefaultEditor.h"
#include "U4DFormationManager.h"
#include "U4DShaderEntity.h"
#include "U4DScriptManager.h"
#include "U4DGameConfigs.h"

namespace U4DEngine {

U4DEditor* U4DEditor::instance=nullptr;


U4DEditor* U4DEditor::sharedInstance(){
    
    if (instance==nullptr) {
        instance=new U4DEditor();
    }

    return instance;
}

U4DEditor::U4DEditor():activeChild(nullptr),scalePlane(false),zonesCreated(0){
    stateManager=new U4DEditorStateManager(this);
    
    stateManager->changeState(U4DDefaultEditor::sharedInstance());
}

U4DEditor::~U4DEditor(){
    
}

void U4DEditor::showEditor(){
    stateManager->showEditor();
}

void U4DEditor::changeState(U4DEditorStateInterface* uState){
    stateManager->changeState(uState);
}

void U4DEditor::showProperties(){
    
    U4DDirector *director=U4DDirector::sharedInstance();
    //U4DLogger *logger=U4DLogger::sharedInstance();
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    
    float fps=director->getFPS();
    std::string profilerData=sceneManager->profilerData;
    
    //properties
    {
        
        ImGui::Begin("Properties");
        
        ImGui::Text("FPS: %f",fps);               // Display some text (you can use a format strings too)
        ImGui::Text("Profiler:\n %s",profilerData.c_str());
        ImGui::End();
    }
}

void U4DEditor::showOutputLog(){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    //output log
    {
       ImGui::Begin("Output");
       ImGui::TextUnformatted(logger->logBuffer.begin());
       if (ScrollToBottom)
        ImGui::SetScrollHereY(1.0f);
       //ScrollToBottom = false;
       ImGui::End();

    }
}

void U4DEditor::showControls(){
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    //control
    {
        
    ImGui::Begin("Control");
    
    ImGui::SameLine();
        
    if (ImGui::Button("Edit")) {
        
        //reset the active child
        activeChild=nullptr;
        
        if(sceneStateManager->getCurrentState()==U4DScenePlayState::sharedInstance()){
            
            scene->getSceneStateManager()->changeState(U4DSceneEditingState::sharedInstance());
        }
        
    }
        
    ImGui::SameLine();
    if (ImGui::Button("Play")) {
        
        //reset the active child
        activeChild=nullptr;
            
        if(sceneStateManager->getCurrentState()==U4DSceneEditingState::sharedInstance()){
            //change scene state to edit mode
            scene->getSceneStateManager()->changeState(U4DScenePlayState::sharedInstance());
        }else if(sceneStateManager->getCurrentState()==U4DScenePlayState::sharedInstance()){
            scene->setPauseScene(false);
            logger->log("Game was resumed");
        }
        
            
            
    }
    
    ImGui::SameLine();
    if (ImGui::Button("Pause") && sceneStateManager->getCurrentState()==U4DScenePlayState::sharedInstance()) {
        
        //change scene state to pause
        scene->setPauseScene(true);
        logger->log("Game was paused");
        
    }
    
        ImGui::End();
    }
}

void U4DEditor::cameraControls(){
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
    U4DDirector *director=U4DDirector::sharedInstance();
    
    if (sceneStateManager->getCurrentState()==U4DSceneEditingState::sharedInstance()) {

        //view front- Press key 1
        U4DCamera *camera=U4DCamera::sharedInstance();

//        if(ImGui::IsKeyReleased(83) && activeChild!=nullptr){
//            scalePlane=true;
//        }
//
//        if(scalePlane==true && ImGui::IsMouseDragging(ImGuiMouseButton_Left)){
//
//            U4DPlaneMesh *planeMesh=dynamic_cast<U4DPlaneMesh*>(activeChild);
//            planeMesh->updateComputePlane(ImGui::GetMouseDragDelta().x, 0.0, ImGui::GetMouseDragDelta().y);
//
//        }else if(ImGui::IsMouseReleased(ImGuiMouseButton_Left)){
//            scalePlane=false;
//        }
        
        
        if(ImGui::GetIO().KeyCtrl==true && ImGui::IsKeyReleased(49)){
            
            U4DVector3n upVector(0.0,1.0,0.0);
            U4DVector3n pos(0.0,0.0,camera->getLargestDistanceFromSceneOrigin());
            camera->rotateTo(180.0,upVector);
            camera->translateTo(pos);
            
        }else if (ImGui::IsKeyReleased(49)){
            
            U4DVector3n upVector(0.0,1.0,0.0);
            U4DVector3n pos(0.0,0.0,-camera->getLargestDistanceFromSceneOrigin());
            camera->rotateTo(0.0,upVector);
            camera->translateTo(pos);
        }
        
        //view right- Press key 3
        if(ImGui::GetIO().KeyCtrl==true && ImGui::IsKeyReleased(51)){
            
            U4DVector3n upVector(0.0,1.0,0.0);
            U4DVector3n pos(camera->getLargestDistanceFromSceneOrigin(),0.0,0.0);
            camera->rotateTo(-90.0,upVector);
            camera->translateTo(pos);
            
        }else if (ImGui::IsKeyReleased(51)){
            U4DVector3n upVector(0.0,1.0,0.0);
            U4DVector3n pos(-camera->getLargestDistanceFromSceneOrigin(),0.0,0.0);
            camera->rotateTo(90.0,upVector);
            camera->translateTo(pos);
        }
        
        //view top-Press key 7
        if(ImGui::GetIO().KeyCtrl==true && ImGui::IsKeyReleased(55)){
            
            U4DVector3n upVector(1.0,0.0,0.0);
            U4DVector3n pos(0.0,-camera->getLargestDistanceFromSceneOrigin(),0.0);
            camera->rotateTo(-90.0,upVector);
            camera->translateTo(pos);
            
        }else if (ImGui::IsKeyReleased(55)){
            U4DVector3n upVector(1.0,0.0,0.0);
            U4DVector3n pos(0.0,camera->getLargestDistanceFromSceneOrigin(),0.0);
            camera->rotateTo(90.0,upVector);
            camera->translateTo(pos);
        }
        
        if(ImGui::IsKeyReleased(53)){
            bool projectionSpace=director->getPerspectiveProjectionEnabled();
            projectionSpace=!projectionSpace;
            
            director->setPerspectiveProjectionEnabled(projectionSpace);
            
        }
        //panning, zooming and rotation of editor camera
        {
            U4DCamera *camera=U4DCamera::sharedInstance();
            float mouseWheelH=ImGui::GetIO().MouseWheelH;
            float mouseWheelV=ImGui::GetIO().MouseWheel;
            
            
            if(mouseWheelH!=0.0 || mouseWheelV!=0.0){
                
                //pan camera - Shift Key + scroll wheel
                if(ImGui::GetIO().KeyShift==true){
                    
                    //camera->translateBy(mouseWheelH, mouseWheelV, 0.0);
                    U4DVector3n dir(mouseWheelH,mouseWheelV,0.0);
                    U4DMatrix3n m=camera->getAbsoluteMatrixOrientation();
                    
                    dir=m*dir;
                    
                    camera->translateBy(dir);
                    
                    //zoom camera - Control Key + scroll wheel
                }else if(ImGui::GetIO().KeyCtrl==true && mouseWheelH==0.0){
                    
                    if (director->getPerspectiveProjectionEnabled()==false) {
                        float orthographicScale=director->getOrthographicScale();
                        
                        orthographicScale+=mouseWheelV;
                        
                        director->setOrthographicScale(orthographicScale);
                        
                    }else{
                        
                        U4DVector3n upVector(0.0,1.0,0.0);
                        U4DVector3n zDir(0.0,0.0,1.0);
                        
                        U4DMatrix3n m=camera->getAbsoluteMatrixOrientation();
                        
                        zDir=m*zDir;
                        
                        U4DVector3n cameraView=camera->getViewInDirection();
                        cameraView.normalize();
                        
                        U4DVector3n xDir=cameraView.cross(upVector);
                        
                        float angle=zDir.angle(cameraView);
                        
                        if (zDir.dot(xDir)<0.0) {
                            angle*=-1.0;
                        }
                        
                        U4DVector3n n=zDir.rotateVectorAboutAngleAndAxis(angle, upVector);
                        
                        if (mouseWheelV<0.0) {
                            n=n*-1.0;
                        }
                        
                        camera->translateBy(n);
                        
                    }
                    
                    
                    //rotate camera
                }else{
                    
                    if (director->getPerspectiveProjectionEnabled()) {
                        
                        //rotate camera
                        //Get the delta movement of the mouse
                        U4DEngine::U4DVector2n delta(mouseWheelH,mouseWheelV);
                        
                        //the y delta should be flipped
                        delta.y*=-1.0;
                        
                        //The following snippet will determine which way to rotate the model depending on the motion of the mouse
                        float deltaMagnitude=delta.magnitude();
                        
                        delta.normalize();
                        
                        U4DEngine::U4DVector3n axis;
                        U4DEngine::U4DVector3n mouseDirection(delta.x,delta.y,0.0);
                        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
                        U4DEngine::U4DVector3n xVector(1.0,0.0,0.0);
                        
                        //get the dot product
                        float upDot, xDot;
                        upDot=mouseDirection.dot(upVector);
                        xDot=mouseDirection.dot(xVector);
                        
                        U4DEngine::U4DVector3n v=camera->getViewInDirection();
                        v.normalize();
                        
                        if(mouseDirection.magnitude()>0){
                            //if direction is closest to upvector
                            if(std::abs(upDot)>=std::abs(xDot)){
                                //rotate about x axis
                                if(upDot>0.0){
                                    axis=v.cross(upVector);
                                    
                                }else{
                                    axis=v.cross(upVector)*-1.0;
                                    
                                }
                            }else{
                                //rotate about y axis
                                if(xDot>0.0){
                                    axis=upVector;
                                }else{
                                    axis=upVector*-1.0;
                                }
                            }
                            
                            //Once we know the angle and axis of rotation, we can rotate the camera using interpolation as shown below
                            
                            float angle=deltaMagnitude;
                            
                            camera->rotateBy(angle,axis);
                            
                        }
                        
                    }
                    
                    
                }
                
                
                
            }
            
        }
            
    }
}

void U4DEditor::guizmoControls(){
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DWorld *world=scene->getGameWorld();
    
    
    //mouse ray casting to enable the Guizmo
    {
    
    CONTROLLERMESSAGE controllerMessage=scene->getGameWorld()->controllerInputMessage;
    
    
    if (controllerMessage.inputElementAction==U4DEngine::mouseRightButtonPressed) {
        rightMouseActive=true;
    }else if(controllerMessage.inputElementAction==U4DEngine::mouseRightButtonReleased && rightMouseActive){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        //1. Normalize device coordinates range [-1:1,-1:1,-1:1]
        U4DVector3n ray_nds(controllerMessage.inputPosition.x,controllerMessage.inputPosition.y,1.0);
        
        //2. 4D homogeneous clip coordinates range [-1:1,-1:1,-1:1,-1:1]
        U4DVector4n ray_clip(ray_nds.x,ray_nds.y,-1.0,1.0);

        //3. 4D Eye (camera) coordinates range [-x:x,-y:y,-z:z,-w:w]
        U4DMatrix4n perspectiveProjection=director->getPerspectiveSpace();
        
        U4DVector4n ray_eye=perspectiveProjection.inverse()*ray_clip;
        
        ray_eye.z=1.0;
        ray_eye.w=0.0;

        //4. 4D world coordinates range[-x:x,-y:y,-z:z,-w:w]
        U4DCamera *camera=U4DCamera::sharedInstance();
        
        U4DEngine::U4DMatrix4n viewSpace=camera->getLocalSpace().transformDualQuaternionToMatrix4n();
        
        U4DVector4n ray_wor=viewSpace*ray_eye;
        
        U4DPoint3n rayOrigin=camera->getAbsolutePosition().toPoint();
        U4DVector3n rayDirection(ray_wor.x,ray_wor.y,ray_wor.z);
        rayDirection.normalize();

        U4DRay ray(rayOrigin,rayDirection);
        
        U4DPoint3n intPoint;
        float intTime;
        float closestTime=FLT_MAX;

        //traverse the scenegraph
       
        U4DEntity *child=world->next;

        while (child!=nullptr) {

            if (child->getEntityType()==U4DEngine::MODEL && child->parent==world) {

                U4DModel *model=dynamic_cast<U4DModel*>(child);
                //create the aabb for entity in the scenegraph
                U4DVector3n dimensions=model->getModelDimensions()/2.0;
                U4DPoint3n position=model->getAbsolutePosition().toPoint();

                U4DMatrix3n m=model->getAbsoluteMatrixOrientation();

                dimensions=m*dimensions;
                
                U4DPoint3n maxPoint(position.x+dimensions.x,position.y+dimensions.y,position.z+dimensions.z);
                U4DPoint3n minPoint(position.x-dimensions.x,position.y-dimensions.y,position.z-dimensions.z);
                
                U4DAABB aabb(maxPoint,minPoint);
                

                if (ray.intersectAABB(aabb, intPoint, intTime)) {
                    
                    if (intTime<closestTime) {
                        
                        closestTime=intTime;
                        
                        activeChild=model;
                        
                    }

                }

            }

            child=child->next;

        }
        
        if (activeChild!=nullptr) {

            mCurrentGizmoOperation = ImGuizmo::TRANSLATE;

            childPosition=activeChild->getAbsolutePosition();
            childOrientation=activeChild->getAbsoluteOrientation();

            entityPosition[0] = childPosition.x;
            entityPosition[1] = childPosition.y;
            entityPosition[2] = childPosition.z;

            entityOrientation[0]=childOrientation.x;
            entityOrientation[1]=childOrientation.y;
            entityOrientation[2]=childOrientation.z;

        }
        
        
        rightMouseActive=false;
    }
        
    }
}

void U4DEditor::showAssets(){
    
    {
        ImGui::Begin("Assets");
    if (ImGui::TreeNode("Models"))
    {

        U4DResourceLoader *resourceLoader=U4DResourceLoader::sharedInstance();
        
        
        for (const auto &n : resourceLoader->getModelContainer()) {
            
            
            char buf[32];
            sprintf(buf, "%s", n.name.c_str());
                
            if (ImGui::Selectable(buf,n.name.compare(assetSelectedName)==0)) {
                assetSelectedName=n.name;
                assetIsSelected=true;
             }
                
        }
        
        
        
        ImGui::TreePop();

    }

    ImGui::End();

   }
    
    {
        if (assetIsSelected) {
            
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            U4DEntityFactory *entityFactory=U4DEntityFactory::sharedInstance();
            U4DScene *scene=sceneManager->getCurrentScene();
            
            ImGui::Begin("Load Assets");
            
            if (scene->getPauseScene()) {
                
                ImGui::Text("Asset Name: %s", assetSelectedName.c_str());
                
//                    static char modelNameBuffer[64] = "";
//                    ImGui::InputText("Model Name", modelNameBuffer, 64);
//
                ImGui::Text("Select Asset Type");
                
                std::vector<std::string> registeredClassesItems=entityFactory->getRegisteredClasses();
                
                static int registeredClassesCurrentIndex = (int)registeredClassesItems.size()-1; // Here we store our selection data as an index.
                
                const char* classesComboLabel = registeredClassesItems.at(registeredClassesCurrentIndex).c_str();
                
                assetSelectedTypeName=registeredClassesItems.at(registeredClassesCurrentIndex).c_str();
                
                static ImGuiComboFlags classesComboFlags = 0;
                
                if (ImGui::BeginCombo("Classes", classesComboLabel, classesComboFlags))
                {
                    for (int n = 0; n < registeredClassesItems.size(); n++)
                    {
                        const bool is_selected = (registeredClassesCurrentIndex == n);
                        if (ImGui::Selectable(registeredClassesItems.at(n).c_str(), is_selected)){
                            registeredClassesCurrentIndex = n;
                            assetSelectedTypeName=registeredClassesItems.at(n);
                        }
                        // Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
                        if (is_selected)
                            ImGui::SetItemDefaultFocus();
                    }
                    ImGui::EndCombo();
                }
                
                ImGui::Separator();
                
                
                //add combo for pipelines
                
                ImGui::Text("Select Asset Pipeline");
                
                U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
                
                std::vector<std::string> registeredPipelineItems=renderManager->getRenderingPipelineList();
                
                static int registeredPipelineCurrentIndex = 0; // Here we store our selection data as an index.
                
                const char* pipelineComboLabel = registeredPipelineItems.at(registeredPipelineCurrentIndex).c_str();
                
                assetSelectedPipelineName=registeredPipelineItems.at(registeredPipelineCurrentIndex).c_str();
                
                static ImGuiComboFlags pipelineComboFlags = 0;
                
                if (ImGui::BeginCombo("Pipeline", pipelineComboLabel, pipelineComboFlags))
                {
                    for (int n = 0; n < registeredPipelineItems.size(); n++)
                    {
                        const bool is_selected = (registeredPipelineCurrentIndex == n);
                        if (ImGui::Selectable(registeredPipelineItems.at(n).c_str(), is_selected)){
                            registeredPipelineCurrentIndex = n;
                            assetSelectedPipelineName=registeredPipelineItems.at(n);
                        }
                        // Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
                        if (is_selected)
                            ImGui::SetItemDefaultFocus();
                    }
                    ImGui::EndCombo();
                }
                
                ImGui::Separator();
                
                if(ImGui::Button("load Assset")){
                
                    if (scene!=nullptr) {
                        
                        //search the scenegraph for current names
                        
                        U4DEntity *child=scene->getGameWorld()->next;
                        
                        int count=0;
                        
                        while (child!=nullptr) {
                            
                            //strip all characters up to the period
                            if(child->getEntityType()==U4DEngine::MODEL){
                                
                                std::string s=child->getName();
                                int n=(int)s.length();
                                int m=(int)assetSelectedName.length();
                                int stringLengthDifference=std::abs(n-m);

                                if(n<=stringLengthDifference) stringLengthDifference=n;
                                //trunk down the name
                                
                                s.erase(s.end()-stringLengthDifference, s.end());

                                if (s.compare(assetSelectedName)==0) {

                                    count++;

                                }
                            }
                            
                            child=child->next;
                            
                        }
                        
                        std::string modelNameBuffer=assetSelectedName+"."+std::to_string(count);
                        
                        entityFactory->createModelInstance(assetSelectedName,modelNameBuffer, assetSelectedTypeName,assetSelectedPipelineName);
                        
                    }
                    
                }
                
            }
            
            ImGui::End();
        }
    }
}

void U4DEditor::showScenegraph(){
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DWorld *world=scene->getGameWorld();
    
    {
        
        ImGui::Begin("Scene Property");
        if (ImGui::TreeNode("Scenegraph"))
        {
            
            U4DEntity *child=world->next;
            
            while (child!=nullptr) {
                
                if (child->getEntityType()==U4DEngine::MODEL || child->getEntityType()==U4DEngine::PRIMITIVE) {
                    
                    char buf[32];
                    
                    sprintf(buf, "%s", child->getName().c_str());
                    
                    if (ImGui::Selectable(buf,activeChild==child) && child->parent==world) {
                        
                        mCurrentGizmoOperation = ImGuizmo::TRANSLATE;
    
                         activeChild=child;
    
                         childPosition=activeChild->getAbsolutePosition();
                         childOrientation=activeChild->getAbsoluteOrientation();
    
                         entityPosition[0] = childPosition.x;
                         entityPosition[1] = childPosition.y;
                         entityPosition[2] = childPosition.z;
    
                         entityOrientation[0]=childOrientation.x;
                         entityOrientation[1]=childOrientation.y;
                         entityOrientation[2]=childOrientation.z;
    
                         break;
                    }
                    
                }
                
                child=child->next;
                
            }
            
            ImGui::TreePop();
            
        }
        
        ImGui::End();
   }
}

void U4DEditor::showAttribMenu(){
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    {
         ImGui::Begin("Attibutes Menu");
        
        if (ImGui::Button("Save Attrib")) {

            serialiazeAttributeFlag=true;
            serializeFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".u4d", ".");

        }
        ImGui::SameLine();
       
        if (ImGui::Button("Open Attr")) {

            deserializeAttributeFlag=true;
            serializeFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".u4d", ".");

        }
        
        if (serialiazeAttributeFlag || deserializeAttributeFlag) {

            if (serializeFileDialog.Instance()->Display("ChooseFileDlgKey"))
               {
                   // action if OK
                   if (serializeFileDialog.Instance()->IsOk())
                   {

                   sceneFilePathName = serializeFileDialog.Instance()->GetFilePathName();
                       logger->log("%s",sceneFilePathName.c_str());


                       if (serialiazeAttributeFlag) {
                           //serialize
                           U4DSerializer *serializer=U4DSerializer::sharedInstance();

                           serializer->serializeAttributes(sceneFilePathName);

                       }else if(deserializeAttributeFlag){
                           //deserialize
                           U4DSerializer *serializer=U4DSerializer::sharedInstance();

                           serializer->deserializeAttributes(sceneFilePathName);
                       }

                   }else{

                   }

                   serialiazeAttributeFlag=false;
                   deserializeAttributeFlag=false;

                   // close
                   serializeFileDialog.Instance()->Close();

               }

            }
        
        ImGui::Checkbox("Show Attributes", &showAttributesFlag);
        
        if(showAttributesFlag){
            showAttributes();
        }
             ImGui::End();
     }
}

void U4DEditor::showMenu(){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    {
         ImGui::Begin("Menu");

         if (ImGui::Button("Save")) {

             serialiazeFlag=true;
             serializeFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".u4d", ".");

         }
         ImGui::SameLine();
        
         if (ImGui::Button("Open")) {

             deserializeFlag=true;
             serializeFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".u4d", ".");

         }

         if (serialiazeFlag || deserializeFlag) {

             if (serializeFileDialog.Instance()->Display("ChooseFileDlgKey"))
                {
                    // action if OK
                    if (serializeFileDialog.Instance()->IsOk())
                    {

                    sceneFilePathName = serializeFileDialog.Instance()->GetFilePathName();
                        logger->log("%s",sceneFilePathName.c_str());


                        if (serialiazeFlag) {
                            //serialize
                            U4DSerializer *serializer=U4DSerializer::sharedInstance();

                            serializer->serialize(sceneFilePathName);

                        }else if(deserializeFlag){
                            //deserialize
                            U4DSerializer *serializer=U4DSerializer::sharedInstance();

                            serializer->deserialize(sceneFilePathName);
                        }

                    }else{

                    }

                    serialiazeFlag=false;
                    deserializeFlag=false;

                    // close
                    serializeFileDialog.Instance()->Close();

                }

             }
        
             ImGui::End();
         }
}

void U4DEditor::showEntityProperty(){
    
    {
        ImGui::Begin("Entity Properties");

        if (activeChild!=nullptr && activeChild->getEntityType()==U4DEngine::MODEL) {

            ImGui::Text("Entity Name: %s",activeChild->getName().c_str());

            ImGui::Text("Transform");
            ImGui::SliderFloat3("Position", (float*)&entityPosition,-20.0,20.0);
            ImGui::SliderFloat3("Orientation", (float*)&entityOrientation,-180.0,180.0);

            activeChild->translateTo(entityPosition[0], entityPosition[1], entityPosition[2]);
            activeChild->rotateTo(entityOrientation[0], entityOrientation[1], entityOrientation[2]);

            //Guizmo
            {
                
                if (ImGui::IsKeyPressed(84)) // t is pressed=translate
                   mCurrentGizmoOperation = ImGuizmo::TRANSLATE;
                if (ImGui::IsKeyPressed(82)) //r is pressed= rotate
                   mCurrentGizmoOperation = ImGuizmo::ROTATE;
        
                 static ImGuizmo::MODE mCurrentGizmoMode(ImGuizmo::WORLD);
                     
                 U4DDirector *director=U4DDirector::sharedInstance();
                 U4DCamera *camera=U4DCamera::sharedInstance();
                  
                  ImGuizmo::SetRect(0.0, 0.0, director->getDisplayWidth(),director->getDisplayHeight());
                  
                  ImGuizmo::BeginFrame();
                
                  U4DMatrix4n cameraSpace=camera->getAbsoluteSpace().transformDualQuaternionToMatrix4n();
                  cameraSpace.invert();
                
                  U4DMatrix4n perspectiveProjection=director->getPerspectiveSpace();
                  
                  U4DMatrix4n activeChildSpace=activeChild->getAbsoluteSpace().transformDualQuaternionToMatrix4n();
                  
                  ImGuizmo::Manipulate(cameraSpace.matrixData, perspectiveProjection.matrixData, mCurrentGizmoOperation, mCurrentGizmoMode, activeChildSpace.matrixData, NULL, NULL);
                  
                  
                  float matrixTranslation[3], matrixRotation[3], matrixScale[3];
                  ImGuizmo::DecomposeMatrixToComponents(activeChildSpace.matrixData, matrixTranslation, matrixRotation, matrixScale);
                
                  
                if (ImGuizmo::IsUsing()) {
                    
                    entityPosition[0] = matrixTranslation[0];
                    entityPosition[1] = matrixTranslation[1];
                    entityPosition[2] = matrixTranslation[2];

                    entityOrientation[0]=matrixRotation[0];
                    entityOrientation[1]=matrixRotation[1];
                    entityOrientation[2]=matrixRotation[2];

                    activeChild->rotateTo(matrixRotation[0], matrixRotation[1], matrixRotation[2]);
                    activeChild->translateTo(matrixTranslation[0], matrixTranslation[1], matrixTranslation[2]);
                    
//                                if(activeChild->getEntityType()==U4DEngine::PRIMITIVE){
//
//                                    U4DPlaneMesh *planeMesh=dynamic_cast<U4DPlaneMesh*>(activeChild);
//                                    planeMesh->updateComputePlane(matrixScale[0], matrixScale[1], matrixScale[2]);
//
//                                }
                }
                 
            }
            
            ImGui::Separator();

//            ImGui::Text("Render Entity");
//            U4DRenderEntity *renderEntity=activeChild->getRenderEntity();
//            U4DRenderPipelineInterface *pipeline=renderEntity->getPipeline(U4DEngine::finalPass);
//            ImGui::Text("Final-Pass Pipeline Name %s",pipeline->getName().c_str());
//            ImGui::Text("Vertex Name %s",pipeline->getVertexShaderName().c_str());
//            ImGui::Text("Fragment Name %s",pipeline->getFragmentShaderName().c_str());
//
//            ImGui::Separator();
//
//            if (scene->getPauseScene()) {
//
//                ImGui::Text("Hot-Reload Shader");
//
//                // open Dialog Simple
//                if (ImGui::Button("Open Shader")){
//                    lookingForShaderFile=true;
//                    hotReloadFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".metal", ".");
//                }
//
//                if (lookingForShaderFile) {
//
//                    // display
//                    if (hotReloadFileDialog.Instance()->Display("ChooseFileDlgKey"))
//                    {
//                      // action if OK
//                      if (hotReloadFileDialog.Instance()->IsOk())
//                      {
//                        shaderFilePathName = hotReloadFileDialog.Instance()->GetFilePathName();
//                        shaderFilePath = hotReloadFileDialog.Instance()->GetCurrentPath();
//                        // action
//                        shaderFilesFound=true;
//                      }else{
//                        shaderFilesFound=false;
//                      }
//
//                      // close
//
//                       hotReloadFileDialog.Instance()->Close();
//                    }
//
//                  if (shaderFilesFound) {
//
//                      ImGui::Text("Shader %s", shaderFilePathName.c_str());
//
//                      if(ImGui::Button("Hot-Reload")){
//
//                          pipeline->hotReloadShaders(shaderFilePathName.c_str(), pipeline->getVertexShaderName().c_str(), pipeline->getFragmentShaderName().c_str());
//                          lookingForShaderFile=false;
//                      }
//
//                  }
//
//                }
//
//            }
            
            ImGui::Separator();
            
            if(ImGui::Button("Remove Entity")){
                
                U4DEntity *parent=activeChild->getParent();
                
                //leaving it here until the issue #359 is fixed.
                //activeChild->removeAndDeleteAllChildren();
                
                parent->removeChild(activeChild);
                
                U4DModel *model=dynamic_cast<U4DModel*>(activeChild);
                
                delete model;
                
                activeChild=nullptr;
                
            }
            
            ImGui::Separator();
            
            static char modelNameBuffer[64] = "";
            //std::strcpy(modelNameBuffer, &activeChild->getName()[0]);
            ImGui::InputText("New Model Name", modelNameBuffer, 64);
            
            if(ImGui::Button("Rename Model")){
                
                std::string previousModelName=activeChild->getName();
                activeChild->setName(modelNameBuffer);
                
                //clear the char array
                memset(modelNameBuffer, 0, sizeof(modelNameBuffer));
                
            }
        }

        ImGui::End();

    }

}

void U4DEditor::createFieldPlane(){
    
}

void U4DEditor::destroyFieldPlane(){
    
}

void U4DEditor::divideZones(){
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
    U4DWorld *world=scene->getGameWorld();
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
    
    float hWidth=gameConfigs->getParameterForKey("fieldHalfWidth");
    float hLength=gameConfigs->getParameterForKey("fieldHalfLength");
    
    //zone division
    {
        ImGui::Begin("Divide zones");
        ImGui::Text("Field Attributes");
        
//        if(ImGui::Button("Generate") && fieldPlane==nullptr){
//
//            fieldPlane=new U4DEngine::U4DPlaneMesh();
//            U4DPoint3n center(0.0,0.0,0.0);
//            fieldPlane->computePlane(hWidth,0.0,hLength,center);
//            fieldPlane->setName(world->searchScenegraphForNextName("plane"));
//            world->addChild(fieldPlane);
//        }
        
        ImGui::PushItemWidth(50.0f);
        ImGui::InputFloat("Field Width", &hWidth,0.0,0.0,"%.1f");
        ImGui::InputFloat("Field Length", &hLength,0.0,0.0,"%.1f");
                
        if(ImGui::Button("Divide Zones") && fieldPlane!=nullptr){
            
            U4DFormationManager formationManager;
            
            float width=fieldPlane->maxPoint.x;
            float length=fieldPlane->maxPoint.z;

            gameConfigs->setParameterForKey("fieldHalfWidth", width);
            gameConfigs->setParameterForKey("fieldHalfLength", length);
            
            std::vector<U4DVector4n> zones=formationManager.divideFieldIntoZones(width, length);
            for(const auto &n:zones){
                
                U4DPoint3n c(0.0,0.0,0.0);
                U4DPlaneMesh *p=new U4DPlaneMesh();
                p->computePlane(n.z,0.0,n.w,c);
                
                p->setName(world->searchScenegraphForNextName("zone"));
                world->addChild(p);
                U4DVector3n c0(n.x,0.0,n.y);
                p->translateTo(c0);
                zonesCreated++;
            }
            
        }
        
        ImGui::End();
    }
    
    //S-key
    if(ImGui::IsKeyReleased(83) && fieldPlane!=nullptr && sceneStateManager->getCurrentState()==U4DSceneEditingState::sharedInstance()){
        scalePlane=true;
        for(int i=0;i<zonesCreated;i++){
            std::string zoneName="zone.";
            zoneName+=std::to_string(i);
            U4DEntity *zone=world->searchChild(zoneName);
            
            world->removeChild(zone);
            delete zone;
        }
        
        zonesCreated=0;
    }
    
    if(scalePlane==true && ImGui::IsMouseDragging(ImGuiMouseButton_Left)){
        
        fieldPlane->updateComputePlane(ImGui::GetMouseDragDelta().x, 0.0, ImGui::GetMouseDragDelta().y);
        
        gameConfigs->setParameterForKey("fieldHalfWidth", ImGui::GetMouseDragDelta().x);
        gameConfigs->setParameterForKey("fieldHalfLength", ImGui::GetMouseDragDelta().y);
        
    }else if(ImGui::IsMouseReleased(ImGuiMouseButton_Left)){
        scalePlane=false;
    }
     
    
}

void U4DEditor::showGameConfigsScript(){
    
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    {
        ImGui::Begin("Game Configs");
        
        //COMMENT OUT FOR NOW-SCRIPT FINE_TUNE SECTION
        if (ImGui::Button("Script")){
            lookingForScriptFile=true;

            gravityFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".gravity", ".");
        }

        if(lookingForScriptFile){
            // display
            if (gravityFileDialog.Instance()->Display("ChooseFileDlgKey"))
            {
              // action if OK
              if (gravityFileDialog.Instance()->IsOk())
              {
                scriptFilePathName = gravityFileDialog.Instance()->GetFilePathName();
                scriptFilePath = gravityFileDialog.Instance()->GetCurrentPath();
                // action
                scriptFilesFound=true;
              }else{
                //scriptFilesFound=false;
              }

              // close
              gravityFileDialog.Instance()->Close();

            }

          if (scriptFilesFound) {

              ImGui::Text("Script %s", scriptFilePathName.c_str());

              U4DScriptManager *scriptManager=U4DScriptManager::sharedInstance();

              if(ImGui::Button("Load Script")){

                  if(scriptManager->loadScript(scriptFilePathName)){

                      logger->log("Script was loaded.");

                      //call the init function in the script
                      //scriptManager->loadGameConfigs();
                      scriptManager->initClosure();
                      scriptManager->loadGameConfigs();
                      scriptLoadedSuccessfully=true;
                  }else{
                      scriptLoadedSuccessfully=false;
                  }

                  //lookingForScriptFile=false;
              }

          }
        }
    //END SCRIPT FINE_TUNE
        
    ImGui::End();
}
    
}

void U4DEditor::showAttributes(){
    
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
    
    {
        ImGui::Begin("Attributes");
        ImGui::Text("Game Attributes");
        std::map<std::string,float>::iterator it;
        ImGui::PushItemWidth(50.0f);
        for(auto &n:gameConfigs->configsMap){
            float *p=&n.second;
            ImGui::InputFloat(n.first.c_str(), p);
            gameConfigs->setParameterForKey(n.first, *p);
        }
        ImGui::End();
    }
}

void U4DEditor::removeFieldZones(){
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DWorld *world=scene->getGameWorld();
    
    if(fieldPlane!=nullptr){
        
        world->removeChild(fieldPlane);
        delete fieldPlane;
        fieldPlane=nullptr;
        
        for(int i=0;i<zonesCreated;i++){
            std::string zoneName="zone.";
            zoneName+=std::to_string(i);
            U4DEntity *zone=world->searchChild(zoneName);
            
            world->removeChild(zone);
            delete zone;
        }
        
        zonesCreated=0;
        
    }
    
    
}

void U4DEditor::showFieldPlane(){
    
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    U4DScene *scene=sceneManager->getCurrentScene();
    U4DWorld *world=scene->getGameWorld();
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
    
    float hWidth=gameConfigs->getParameterForKey("fieldHalfWidth");
    float hLength=gameConfigs->getParameterForKey("fieldHalfLength");
    
    fieldPlane=new U4DEngine::U4DPlaneMesh();
    U4DPoint3n center(0.0,0.0,0.0);
    fieldPlane->computePlane(hWidth,0.0,hLength,center);
    fieldPlane->setName(world->searchScenegraphForNextName("plane"));
    world->addChild(fieldPlane);
    
    U4DFormationManager formationManager;
    
    std::vector<U4DVector4n> zones=formationManager.divideFieldIntoZones(hWidth, hLength);
    for(const auto &n:zones){
        
        U4DPoint3n c(0.0,0.0,0.0);
        U4DPlaneMesh *p=new U4DPlaneMesh();
        p->computePlane(n.z,0.0,n.w,c);
        
        p->setName(world->searchScenegraphForNextName("zone"));
        world->addChild(p);
        U4DVector3n c0(n.x,0.0,n.y);
        p->translateTo(c0);
        zonesCreated++;
    }
    
}

}
