//
//  TeamSettings.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef TeamSettings_hpp
#define TeamSettings_hpp

#include <stdio.h>
#include <vector>
#include "U4DVector4n.h"

class TeamSettings {
    
private:
    
    static TeamSettings* instance;
    
    std::vector<U4DEngine::U4DVector4n> teamAKitContainer;
    
    std::vector<U4DEngine::U4DVector4n> teamBKitContainer;
    
protected:
    
    //constructor
    TeamSettings();
    //destructor
    
    ~TeamSettings();
    
public:
    
    static TeamSettings* sharedInstance();
    
    void setTeamAKit(std::vector<U4DEngine::U4DVector4n> &uKitContainer);
    
    void setTeamBKit(std::vector<U4DEngine::U4DVector4n> &uKitContainer);
    
    std::vector<U4DEngine::U4DVector4n> &getTeamAKit();
    
    std::vector<U4DEngine::U4DVector4n> &getTeamBKit();

};
#endif /* TeamSettings_hpp */
