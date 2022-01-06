//
//  U4DLinkingContext.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/29/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DLinkingContext_hpp
#define U4DLinkingContext_hpp

#include <stdio.h>
#include "U4DModel.h"
#include "Constants.h"
#include <unordered_map>

namespace U4DEngine {

typedef struct{
    int modelId;
    char *classType;
    bool found=false;
}ClientModelData;

class U4DLinkingContext {
    
    private:
        
        std::unordered_map<u_int32_t, ClientModelData> networkIdToClientModelDataMap;
        std::unordered_map<int, u_int32_t> modelIdToNetworkIdMap;
    
    protected:
        
        
    
    public:
    
        U4DLinkingContext();
        ~U4DLinkingContext();
    
        ClientModelData getClientModelDataFromNetworkId(u_int32_t uNetworkId);
    
        void linkClientModelDataToNetworkId(int uModelId, char *uClassType, u_int32_t uNetworkId);
        void unlinkClientModelDataFromNetworkId(ClientModelData &uClientModelData);
        
};

}

#endif /* U4DLinkingContext_hpp */
