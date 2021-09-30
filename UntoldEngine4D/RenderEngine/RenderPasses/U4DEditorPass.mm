//
//  U4DEditorPass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/29/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DEditorPass.h"
#include "U4DDirector.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DShaderProtocols.h"
#include "U4DEntity.h"
#include "U4DProfilerManager.h"
#include "U4DDebugger.h"
#include "U4DCamera.h"
#include "U4DDirectionalLight.h"
#include "U4DLogger.h"
#include "U4DScriptBindManager.h"
#include "U4DRenderEntity.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DModelPipeline.h"
#include "U4DResourceLoader.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DSceneStateManager.h"
#include "U4DSceneEditingState.h"
#include "U4DEntityFactory.h"

#include "U4DWorld.h"
#include "U4DModel.h"

#include "U4DSerializer.h"
#include "U4DVisibilityDictionary.h"
#include "U4DKineticDictionary.h"

#include "U4DRay.h"
#include "U4DAABB.h"

//this is temp header
#include "U4DScriptBindModel.h"

#import <TargetConditionals.h> 
#if TARGET_OS_MAC && !TARGET_OS_IPHONE
#include "imgui.h"
#include "imgui_impl_metal.h"
#include "ImGuiFileDialog.h"
#include "ImGuizmo.h"
#include "imgui_impl_osx.h"


#endif

namespace U4DEngine{

U4DEditorPass::U4DEditorPass(std::string uPipelineName):U4DRenderPass(uPipelineName){
    
}

U4DEditorPass::~U4DEditorPass(){
    
}

void U4DEditorPass::executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass){
    
    static bool ScrollToBottom=true;
    static U4DEntity *activeChild=nullptr;
    static std::string assetSelectedName;
    static std::string assetSelectedTypeName;
    static std::string scriptFilePathName;
    static std::string scriptFilePath;
    
    static bool savingScriptFile=false;
    static bool newScriptFile=false;
    
    static bool assetIsSelected=false;
    static bool scriptFilesFound=false;
    static bool scriptLoadedSuccessfully=false;
    static bool lookingForScriptFile=false;
    static bool serialiazeFlag=false;
    static bool deserializeFlag=false;
    
    static std::string shaderFilePathName;
    static std::string shaderFilePath;
    static std::string sceneFilePath;
    static std::string sceneFilePathName;
    
    static bool shaderFilesFound=false;
    static bool lookingForShaderFile=false;
    
    NSString *pathToGameScripts=@"/GameplayScripts/";
    static bool scriptOkToRender=false;
   
    U4DDirector *director=U4DDirector::sharedInstance();
    U4DLogger *logger=U4DLogger::sharedInstance();
    U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
    
    ImGuiFileDialog gravityFileDialog;
    ImGuiFileDialog hotReloadFileDialog;
    ImGuiFileDialog serializeFileDialog;
    
    static ImGuizmo::OPERATION mCurrentGizmoOperation(ImGuizmo::TRANSLATE);
    
    U4DVector3n childPosition;
    U4DVector3n childOrientation;

    static float entityPosition[3];
    static float entityOrientation[3];
    
    
    float fps=director->getFPS();
    std::string profilerData=sceneManager->profilerData;
    
    MTLRenderPassDescriptor *mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
           mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
           mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
           mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    
    
    id <MTLRenderCommandEncoder> editorRenderEncoder =
    [uCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];

    if(editorRenderEncoder!=nil){

        [editorRenderEncoder pushDebugGroup:@"Editor Comp Pass"];
        editorRenderEncoder.label = @"Editor Comp Render Pass";

        // Start the Dear ImGui frame
        ImGui_ImplMetal_NewFrame(mtlRenderPassDescriptor);
         
         ImGui_ImplOSX_NewFrame(director->getMTLView());
         
         ImGui::NewFrame();
        
        {
        U4DScene *scene=sceneManager->getCurrentScene();
        CONTROLLERMESSAGE controllerMessage=scene->getGameWorld()->controllerInputMessage;
        static bool rightMouseActive=false;
        
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
            U4DEntity *child=scene->getGameWorld()->next;

            while (child!=nullptr) {

                if (child->getEntityType()==U4DEngine::MODEL) {

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
        
        {
           ImGui::Begin("Output");
           ImGui::TextUnformatted(logger->logBuffer.begin());
           if (ScrollToBottom)
            ImGui::SetScrollHereY(1.0f);
           //ScrollToBottom = false;
           ImGui::End();

        }
        
        {
            
            ImGui::Begin("Save Entities");
            
            if (ImGui::Button("Save")) {
                
                serialiazeFlag=true;
                serializeFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".u4d", ".");
                
            }
            
            if (ImGui::Button("Load")) {
                
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
        
        
        {
            
            U4DScene *scene=sceneManager->getCurrentScene();
            U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
            ImGui::Begin("Engine Mode");
            if (ImGui::Button("clear")) {
                
                //reset the active child
                activeChild=nullptr;
                logger->log("Scene was cleared");
                
                //change scene state to edit mode
                scene->getSceneStateManager()->changeState(U4DSceneEditingState::sharedInstance());
            
            }
            ImGui::SameLine();
            if (ImGui::Button("Pause") && sceneStateManager->getCurrentState()==U4DSceneEditingState::sharedInstance()) {
                
                //change scene state to pause
                scene->setPauseScene(true);
                logger->log("Game was paused");
                
            }
            
            ImGui::SameLine();
            if (ImGui::Button("Play")&& sceneStateManager->getCurrentState()==U4DSceneEditingState::sharedInstance()) {
                
                    //reset the active child
                    activeChild=nullptr;
                    
                    scene->setPauseScene(false);
                    logger->log("Game is playing");
                    
//                    //Change the state of the scene to play mode. This will remove all children from the
//                    //scenegraph and start anew.
//                    scene->getSceneStateManager()->changeState(U4DScenePlayState::sharedInstance());
//
                    //call the init gravity function-- THIS IS FOR NOW ONLY
                    
                    
            }
            
            ImGui::End();
        }
        
        {
            ImGui::Begin("Script Editor",nullptr, ImGuiWindowFlags_HorizontalScrollbar | ImGuiWindowFlags_MenuBar);
            
            U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
            
            //set the menu
            if (ImGui::BeginMenuBar())
                    {
                        if (ImGui::BeginMenu("File"))
                        {
                            if(ImGui::MenuItem("New")){
                                
                                
                                
                                newScriptFile=true;
                            }
                            
                            if(ImGui::MenuItem("Open")){
                                
                                lookingForScriptFile=true;
                                
                                //create new file
                                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
                                NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
                                NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:pathToGameScripts];
                                
                                std::string dataPathString = std::string([dataPath UTF8String]);
                               
                                gravityFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".gravity", dataPathString,"");
                                
                            }
                            if (ImGui::MenuItem("Save"))
                            {
                                //save the script
                                
                                savingScriptFile=true;
                                
                                //create new file
                                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
                                NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
                                NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:pathToGameScripts];
                                
                                std::string dataPathString = std::string([dataPath UTF8String]);
                               
                                gravityFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".gravity", dataPathString,"");
                                
                            }
                            if (ImGui::MenuItem("Quit", "Alt-F4")){}
                                //break;
                            ImGui::EndMenu();
                        }
                        if (ImGui::BeginMenu("Edit"))
                        {
                            bool ro = renderManager->imguiScriptEditor.IsReadOnly();

                            if (ImGui::MenuItem("Undo", "Command-Z", nullptr, !ro && renderManager->imguiScriptEditor.CanUndo()))
                                renderManager->imguiScriptEditor.Undo();
                            if (ImGui::MenuItem("Redo", "Command-Y", nullptr, !ro && renderManager->imguiScriptEditor.CanRedo()))
                                renderManager->imguiScriptEditor.Redo();

                            ImGui::Separator();

                            if (ImGui::MenuItem("Copy", "Ctrl-C", nullptr, renderManager->imguiScriptEditor.HasSelection()))
                                renderManager->imguiScriptEditor.Copy();
                            if (ImGui::MenuItem("Cut", "Ctrl-X", nullptr, !ro && renderManager->imguiScriptEditor.HasSelection()))
                                renderManager->imguiScriptEditor.Cut();

                            if (ImGui::MenuItem("Paste", "Ctrl-V", nullptr, !ro && ImGui::GetClipboardText() != nullptr))
                                renderManager->imguiScriptEditor.Paste();

                            ImGui::Separator();

                            if (ImGui::MenuItem("Select all", nullptr, nullptr))
                                renderManager->imguiScriptEditor.SetSelection(TextEditor::Coordinates(), TextEditor::Coordinates(renderManager->imguiScriptEditor.GetTotalLines(), 0));

                            ImGui::EndMenu();
                        }
                        
                        if (ImGui::BeginMenu("Run"))
                        {
                            if(ImGui::MenuItem("Build & Run", nullptr,nullptr)){
                                
                                U4DEngine::U4DScriptBindManager *bindManager=U4DEngine::U4DScriptBindManager::sharedInstance();
                                
                                  if(bindManager->loadScript(scriptFilePathName)){
            
                                      logger->log("Script was loaded.");
            
                                      //call the init function in the script
                                      bindManager->initGravityFunction();
            
                                      scriptLoadedSuccessfully=true;
                                  }else{
                                      scriptLoadedSuccessfully=false;
                                  }
                            }
                            ImGui::EndMenu();
                        }

                        ImGui::EndMenuBar();
                    }
                
            if(lookingForScriptFile){
                // display
                if (gravityFileDialog.Instance()->Display("ChooseFileDlgKey"))
                {
                    if (gravityFileDialog.Instance()->IsOk())
                    {
                      
                      scriptFilePathName = gravityFileDialog.Instance()->GetFilePathName();
                      scriptFilePath = gravityFileDialog.Instance()->GetCurrentPath();
                        
                        const char* fileToEdit = scriptFilePathName.c_str();
                        
                        std::ifstream t(fileToEdit);
                        if (t.good())
                        {
                            std::string str((std::istreambuf_iterator<char>(t)), std::istreambuf_iterator<char>());
                            renderManager->imguiScriptEditor.SetText(str);
                            scriptOkToRender=true;
                            
                        }
                        
                        
                    }else{
                      //scriptOkToRender=false;
                    }
                    
                    // close
                    gravityFileDialog.Instance()->Close();
                    lookingForScriptFile=false;
                  
                  }
                
            }
            
            if(savingScriptFile){
                
                // display
                if (gravityFileDialog.Instance()->Display("ChooseFileDlgKey"))
                {
                  // action if OK
                  if (gravityFileDialog.Instance()->IsOk())
                  {
                    
                      
                    
                    auto textToSave = renderManager->imguiScriptEditor.GetText();
                    std::ofstream outFile;
                    scriptFilePathName = gravityFileDialog.Instance()->GetFilePathName();
                    scriptFilePath = gravityFileDialog.Instance()->GetCurrentPath();
                      
                      outFile.open(scriptFilePathName.c_str());
                      
                      /// save text....
                      outFile<<textToSave<<std::endl;
                      
                      //close the file
                      outFile.close();
                      
                      
                  }
                  
                  // close
                  gravityFileDialog.Instance()->Close();
                  savingScriptFile=false;
                }
                
                
            }
            
            if(newScriptFile){
                
                //create new file
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
                NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:pathToGameScripts];
                
                std::string dataPathString = std::string([dataPath UTF8String]);
                
                scriptFilePathName=dataPathString+"/untitled.gravity";
                
                std::ofstream newFile(scriptFilePathName);
                
                const char* fileToEdit = scriptFilePathName.c_str();
                
                std::ifstream t(fileToEdit);
                if (t.good())
                {
                    std::string str((std::istreambuf_iterator<char>(t)), std::istreambuf_iterator<char>());
                    renderManager->imguiScriptEditor.SetText(str);
                    scriptOkToRender=true;
                    scriptFilePathName="untitled.gravity";
                }
                
                newScriptFile=false;
            }
              
            if(scriptOkToRender){
                //ImGui::Text("Current File: %s",scriptFilePathName.c_str());
                ImGui::Separator();
                renderManager->imguiScriptEditor.Render("Script Editor");
            }
            
            ImGui::End();
            
        }
        
        {
            
        ImGui::Begin("Properties");                          // Create a window called "Hello, world!" and append into it.

        ImGui::Text("FPS: %f",fps);               // Display some text (you can use a format strings too)
        ImGui::Text("Profiler:\n %s",profilerData.c_str());
        ImGui::Separator();
        //ImGui::End();
        
            
         //ImGui::Begin("World Properties");
         ImGui::Text("Camera");
         U4DCamera *camera=U4DCamera::sharedInstance();

         U4DVector3n cameraPos=camera->getAbsolutePosition();
         U4DVector3n cameraOrient=camera->getAbsoluteOrientation();

         float pos[3] = {cameraPos.x,cameraPos.y,cameraPos.z};
         float orient[3]={cameraOrient.x,cameraOrient.y,cameraOrient.z};

         ImGui::SliderFloat3("Pos", (float*)&pos,-50.0,50.0);
         ImGui::SliderFloat3("Orient", (float*)&orient,-90.0,90.0);

         camera->translateTo(pos[0], pos[1], pos[2]);
         camera->rotateTo(orient[0], orient[1], orient[2]);

         ImGui::Separator();
         ImGui::Text("Light");
         U4DDirectionalLight *dirLight=U4DDirectionalLight::sharedInstance();

         U4DVector3n lightPos=dirLight->getAbsolutePosition();
         U4DVector3n lightOrient=dirLight->getAbsoluteOrientation();
         U4DVector3n diffuseColor=dirLight->getDiffuseColor();

         float lightpos[3] = {lightPos.x,lightPos.y,lightPos.z};
         float lightorient[3]={lightOrient.x,lightOrient.y,lightOrient.z};
         float color[3] = {diffuseColor.x,diffuseColor.y,diffuseColor.z};

         ImGui::SliderFloat3("Light Pos", (float*)&lightpos,-30.0,30.0);
         ImGui::SliderFloat3("Light Orient", (float*)&lightorient,-90.0,90.0);
         ImGui::SliderFloat3("Color", (float*)&color,0.0,1.0);

         diffuseColor=U4DVector3n(color[0],color[1],color[2]);

         dirLight->translateTo(lightpos[0], lightpos[1], lightpos[2]);
         dirLight->rotateTo(lightorient[0], lightorient[1], lightorient[2]);
         dirLight->setDiffuseColor(diffuseColor);

         ImGui::End();
            
        }

        {
            
         ImGui::Begin("Scene Property");
         if (ImGui::TreeNode("Scenegraph"))
         {
             U4DScene *scene=sceneManager->getCurrentScene();
             U4DEntity *child=scene->getGameWorld()->next;
             
             while (child!=nullptr) {

                 if (child->getEntityType()==U4DEngine::MODEL) {

                     char buf[32];

                     sprintf(buf, "%s", child->getName().c_str());

                     if (ImGui::Selectable(buf,activeChild==child)) {
                         
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
            
            {
                ImGui::Begin("Entity Properties");

                if (activeChild!=nullptr) {

                    U4DScene *scene=sceneManager->getCurrentScene();
                    
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
                        }
                         
                    }
                    
                    ImGui::Separator();

                    ImGui::Text("Render Entity");
                    U4DRenderEntity *renderEntity=activeChild->getRenderEntity();
                    U4DRenderPipelineInterface *pipeline=renderEntity->getPipeline(U4DEngine::finalPass);
                    ImGui::Text("Final-Pass Pipeline Name %s",pipeline->getName().c_str());
                    ImGui::Text("Vertex Name %s",pipeline->getVertexShaderName().c_str());
                    ImGui::Text("Fragment Name %s",pipeline->getFragmentShaderName().c_str());

                    ImGui::Separator();
                    
                    if (scene->getPauseScene()) {
                        
                        ImGui::Text("Hot-Reload Shader");

                        // open Dialog Simple
                        if (ImGui::Button("Open Shader")){
                            lookingForShaderFile=true;
                            hotReloadFileDialog.Instance()->OpenDialog("ChooseFileDlgKey", "Choose File", ".metal", ".");
                        }
                            
                        if (lookingForShaderFile) {
                            
                            // display
                            if (hotReloadFileDialog.Instance()->Display("ChooseFileDlgKey"))
                            {
                              // action if OK
                              if (hotReloadFileDialog.Instance()->IsOk())
                              {
                                shaderFilePathName = hotReloadFileDialog.Instance()->GetFilePathName();
                                shaderFilePath = hotReloadFileDialog.Instance()->GetCurrentPath();
                                // action
                                shaderFilesFound=true;
                              }else{
                                shaderFilesFound=false;
                              }

                              // close
                              
                               hotReloadFileDialog.Instance()->Close();
                            }

                          if (shaderFilesFound) {

                              ImGui::Text("Shader %s", shaderFilePathName.c_str());
                              
                              if(ImGui::Button("Hot-Reload")){
                                  
                                  pipeline->hotReloadShaders(shaderFilePathName.c_str(), pipeline->getVertexShaderName().c_str(), pipeline->getFragmentShaderName().c_str());
                                  lookingForShaderFile=false;
                              }

                          }
                        
                        }
                        
                    }
                    
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
                        
                        U4DVisibilityDictionary *visibilityDictionary=U4DVisibilityDictionary::sharedInstance();
                        U4DKineticDictionary *kineticDictionary=U4DKineticDictionary::sharedInstance();
                        std::string previousModelName=activeChild->getName();
                        activeChild->setName(modelNameBuffer);
                        
                        visibilityDictionary->updateVisibilityDictionary(previousModelName, modelNameBuffer);
                        kineticDictionary->updateKineticBehaviorDictionary(previousModelName, modelNameBuffer);
                        
                        //clear the char array
                        memset(modelNameBuffer, 0, sizeof(modelNameBuffer));
                        
                    }
                }

                ImGui::End();

            }

         ImGui::End();

        }
                
        
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
                    
                    std::vector<std::string> items=entityFactory->getRegisteredClasses();
                    
                    static int item_current_idx = (int)items.size()-1; // Here we store our selection data as an index.
                    
                    const char* combo_label = items.at(item_current_idx).c_str();
                    
                    assetSelectedTypeName=items.at(item_current_idx).c_str();
                    
                    static ImGuiComboFlags flags = 0;
                    
                    if (ImGui::BeginCombo("Classes", combo_label, flags))
                    {
                        for (int n = 0; n < items.size(); n++)
                        {
                            const bool is_selected = (item_current_idx == n);
                            if (ImGui::Selectable(items.at(n).c_str(), is_selected)){
                                item_current_idx = n;
                                assetSelectedTypeName=items.at(n);
                            }
                            // Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
                            if (is_selected)
                                ImGui::SetItemDefaultFocus();
                        }
                        ImGui::EndCombo();
                    }
                    
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
                            
                            entityFactory->createModelInstance(assetSelectedName,modelNameBuffer, assetSelectedTypeName);
                            
                        }
                        
                    }
                    
                }
                
                ImGui::End();
            }
            
            
        }
        
        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, uCommandBuffer, editorRenderEncoder);

        [editorRenderEncoder popDebugGroup];
        //end encoding
        [editorRenderEncoder endEncoding];

    }
    
}


}
