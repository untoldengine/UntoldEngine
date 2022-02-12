//
//  U4DEntityFactory.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/1/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DEntityFactory_hpp
#define U4DEntityFactory_hpp

#include <stdio.h>
#include "U4DModel.h"
#include "U4DVector3n.h"

namespace U4DEngine{

class U4DEntityFactory {
        
protected:
    
    U4DEntityFactory();
    
    ~U4DEntityFactory();
    
public:
    
    static U4DEntityFactory* sharedInstance();
    
    typedef U4DModel* (U4DEntityFactory::* pCreateAction)();

    template <typename T>
    void registerClass(const std::string& name) {

        createActionMap[name] = &U4DEntityFactory::createAction<T>;
        
    }

    U4DModel* createAction(const std::string& name) {
        std::map<std::string, pCreateAction>::iterator it = createActionMap.find(name);
        if (it == createActionMap.end()) return NULL;
        return ((*this).*it->second)();
    }
    
    std::vector<std::string> getRegisteredClasses();
    
    void createModelInstance(std::string uAssetName, std::string uModelName, std::string uType);
    
    void createModelInstance(std::string uAssetName, std::string uModelName, std::string uType, U4DVector3n uPosition, U4DVector3n uOrientation);
    
private:
    
    static U4DEntityFactory *instance;
    
    template <typename T>
    U4DModel* createAction() { return new T; }

    std::map<std::string, pCreateAction> createActionMap;
    
};
}
#endif /* U4DEntityFactory_hpp */
