//
//  U4DSceneConfig.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/27/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSceneConfig_hpp
#define U4DSceneConfig_hpp

#include <stdio.h>
#include <string>
#include "tinyxml2.h"
#include "U4DVector3n.h"

namespace U4DEngine {

    class U4DSceneConfig {
        
    private:
        
        static U4DSceneConfig *instance;
        
        
        
    protected:
     
        U4DSceneConfig();
        
        ~U4DSceneConfig();
        
    public:
        
        //tinyxml2::XMLDocument xmlDoc;
        tinyxml2::XMLElement* root;
        
        static U4DSceneConfig* sharedInstance();
        
        void applyPropertyToAllEntities();
        
        void removePropertyFromAllEntities();
        
        tinyxml2::XMLElement *getEntityElement(std::string uName, std::string uSystem, std::string uComponent);
        
        void addNewEntity(std::string uName, std::string uRefName);
        
        void setEntityBehavior(std::string uName, std::string uSystem, bool uValue);
        void setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, bool uValue);
        void setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, std::vector<float> uData);
        void setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData,int uSize);
        void setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, char *uData, int uSize);
        void setEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, float uValue);
        
        
        bool getEntityBehavior(std::string uName, std::string uSystem);
        
        bool getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, std::vector<float> *uData);
        bool getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData);
        bool getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, bool &uValue);
        bool getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, char *uData, int uSize);
        
        bool getEntityBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData,int uSize);
       
        
        tinyxml2::XMLElement *getSceneProps(std::string uName, std::string uSystem, std::string uComponent);
        
        void setScenePropsBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData,int uSize);
        
        bool getScenePropsBehavior(std::string uName, std::string uSystem, std::string uComponent, float *uData,int uSize);
        
        int getEntitiesCount();
        
        void stringToFloat(std::string uStringData,std::vector<float> *uFloatData);
        void stringToFloat(std::string uStringData,float *uFloatData, int uSize);
        void stringToInt(std::string uStringData,std::vector<int> *uIntData);
    };

}



#endif /* U4DConfigFactory_hpp */
