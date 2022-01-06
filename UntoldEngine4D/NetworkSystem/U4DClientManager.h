//
//  U4DClientManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DClientManager_hpp
#define U4DClientManager_hpp

#include <stdio.h>
#include "CommonProtocols.h"
#include "U4DPlayer.h"
#include "../Enet/include/enet/enet.h"
#include "U4DOutMemoryStream.h"
#include "U4DInMemoryStream.h"
#include "U4DLinkingContext.h"

namespace U4DEngine {
    
class U4DClientManager {
    
private:
    
    static U4DClientManager* instance;
    
    u_int32_t networkId;
    
    U4DLinkingContext linkingContext;
    
protected:
    
    U4DClientManager();
    
    ~U4DClientManager();
    
public:
    
    ENetHost *client;
    ENetAddress address;
    ENetPeer *peer; //peer here is the server we are connecting to
    const char *ipAddress;
    int port;
    bool isConnected;
    
    static U4DClientManager* sharedInstance();
    
    void update(double dt);
    
    void changeState(int uState);
    
    void joinGameAtServer(const char *uIPAddress, int uPort);
    
    void messageLoop();

    void sendPacket(U4DOutMemoryStream &uOutStream);
    
    void processPacket(U4DInMemoryStream &uInStream);
    
    bool isConnectedToServer();
    
    void connectToServer();
    
    void attemptToJoinGame();
    
    void processJoinedPacket(U4DInMemoryStream &uInStream);
    
};

}

#endif /* U4DClientManager_hpp */
