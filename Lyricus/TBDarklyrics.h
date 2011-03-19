
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
-(NSString *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist error:(NSError **)error;
-(NSString *) getURLForArtist:(NSString *) artist;
-(NSString *) getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)artistURL error:(NSError **)error;
-(NSString *) extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName error:(NSError **)error;

@end
