//
//  U4DNetworkManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNetworkManager_hpp
#define U4DNetworkManager_hpp

#include <stdio.h>
#include "CommonProtocols.h"
#include "U4DPlayer.h"
#include "../Enet/include/enet/enet.h"

namespace U4DEngine {
    
class U4DNetworkManager {
    
private:
    
    static U4DNetworkManager* instance;
    
    ENetHost *client;
    ENetAddress address;
    ENetPeer *peer; //peer here is the server we are connecting to
    
protected:
    
    U4DNetworkManager();
    
    ~U4DNetworkManager();
    
public:
    
    static U4DNetworkManager* sharedInstance();
    
    bool initializeNetwork();
    
    bool connect(const char *uIPAdress, int uPort);

    void receiveMsg();

    void sendPacket(U4DPlayer *uPlayer);
    
    void receivePacket(ENetEvent uEvent);
    
};

}

#endif /* U4DNetworkManager_hpp */
