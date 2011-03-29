//
//  RootLevelObject.h
//  NSOutlineView
//
//  Created by Thomas Backman on 3/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iTunes.h"

@interface PlaylistObject : NSObject {
@private
	iTunesPlaylist *playlist;
	NSMutableArray *children;
	NSString *name;
	BOOL smart;
	iTunesESpK specialKind;
    
}
- (id)initWithPlaylist:(iTunesPlaylist *)pl;
-(void) addChild:(PlaylistObject *)pl;

@property (retain, readonly) iTunesPlaylist *playlist;
@property (retain, readonly) NSMutableArray *children;
@property (retain, readonly) NSString *name;
@property (readonly) BOOL smart;
@property (readonly) iTunesESpK specialKind;


@end
