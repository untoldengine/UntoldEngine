//
//  main.m
//  Untold4D macOS
//
//  Created by Harold Serrano on 2/6/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//void gltSetWorkingDirectory(const char *szArgv);

int main(int argc, const char * argv[]) {
    
    //gltSetWorkingDirectory(*argv);
    
    return NSApplicationMain(argc, argv);
}

//THIS CODE SNIPPET IS NO LONGER VALID IN XCODE 12.3 with Big Sur
//void gltSetWorkingDirectory(const char *szArgv)
//{
//#ifdef __APPLE__
//    static char szParentDirectory[255];
//
//    ///////////////////////////////////////////////////////////////////////////
//    // Get the directory where the .exe resides
//    char *c;
//    strncpy( szParentDirectory, szArgv, sizeof(szParentDirectory) );
//    szParentDirectory[254] = '\0'; // Make sure we are NULL terminated
//
//    c = (char*) szParentDirectory;
//
//    while (*c != '\0')     // go to end
//        c++;
//
//    while (*c != '/')      // back up to parent
//        c--;
//
//    *c++ = '\0';           // cut off last part (binary name)
//
//    ///////////////////////////////////////////////////////////////////////////
//    // Change to Resources directory. Any data files need to be placed there
//    chdir(szParentDirectory);
//#ifndef METAL
//    chdir("../Resources");
//#endif
//#endif
//}
