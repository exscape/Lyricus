//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
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
