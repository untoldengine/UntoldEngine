//
//  U4DLinkingContext.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/29/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DLinkingContext.h"

namespace U4DEngine {

    U4DLinkingContext::U4DLinkingContext(){
        
    }

    U4DLinkingContext::~U4DLinkingContext(){
        
    }

    ClientModelData U4DLinkingContext::getClientModelDataFromNetworkId(u_int32_t uNetworkId){
        
        auto it=networkIdToClientModelDataMap.find(uNetworkId);
        
        if(it!=networkIdToClientModelDataMap.end()){
            it->second.found=true;
            return it->second;
            
        }else{
            
            ClientModelData nullModelData;
            nullModelData.found=false;
            
            return nullModelData;
        }
        
    }

    void U4DLinkingContext::linkClientModelDataToNetworkId(int uModelId, char *uClassType, u_int32_t uNetworkId){
        
        ClientModelData clientModelData;
        clientModelData.modelId=uModelId;
        clientModelData.classType=uClassType;
        
        networkIdToClientModelDataMap[uNetworkId]=clientModelData;
        modelIdToNetworkIdMap[clientModelData.modelId]=uNetworkId;
        
    }
        
    void U4DLinkingContext::unlinkClientModelDataFromNetworkId(ClientModelData &uClientModelData){
        
        u_int32_t networkId=modelIdToNetworkIdMap[uClientModelData.modelId];
        
        modelIdToNetworkIdMap.erase(uClientModelData.modelId);
        networkIdToClientModelDataMap.erase(networkId);
        
    }


}
