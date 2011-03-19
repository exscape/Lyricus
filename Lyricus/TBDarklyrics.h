
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TBDarklyrics : NSObject {
	NSMutableDictionary *albumCache;
}

//
// Sorted by calling order
//
-(NSMutableArray *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist;
-(NSString *) getURLForArtist:(NSString *) artist;
-(NSString *) getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)artistURL;
-(NSString *) extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName;

@end
