
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iTunesHelper : NSObject {
	iTunesApplication *iTunes;	
}

-(BOOL) initiTunes;
-(NSArray *)getAllPlaylists;
-(NSArray *)getSelectedTracks;
-(NSArray *)getAllTracksForTitle:(NSString *)theTitle byArtist:(NSString *)theArtist;
-(NSArray *)getTracksForPlaylist:(NSString *)thePlaylist;
-(NSArray *)getTracksForLibraryPlaylist;
-(iTunesTrack *)getCurrentTrack;
-(BOOL)currentTrackIsStream;
-(NSString *)getLyricsForTrack:(iTunesTrack *)theTrack;
-(BOOL)setLyrics:(NSString *)theLyrics ForTrack:(iTunesTrack *)theTrack;

-(BOOL)isiTunesRunning;
-(iTunesTrack *)getTrackForTitle:(NSString *)theTitle byArtist:(NSString *)theArtist;

-(NSString *)currentStreamTitle;
	
-(iTunesApplication *)iTunesReference; // Use sparingly!

+(iTunesHelper *)sharediTunesHelper;

@end
