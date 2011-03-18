
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

//
// THIS CLASS HAS BEEN REMOVED. Due to legal issues with Lyricwiki, it is now  (next to) impossible to access their lyrics programatically.
// A big loss for program developers and users everywhere. :(
// http://www.theregister.co.uk/2009/08/26/lyrics_sites_sued/
//

/*
#import "TBLyricwiki.h"
#import "NSString+ExscapeEdits.h"

@implementation TBLyricwiki

-(TBLyricwiki *) init {
	if (self = [super init])
	{
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Public

-(NSMutableArray *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist {
	SendNote(@"Trying Lyricwiki...\n");
	
	// This never fails (since it just "calculates" the URL, without any net connectivity)
	NSString *trackURL = [self getLyricURLForTrack:title byArtist:artist];
	
	NSString *lyrics = [self extractLyricsFromURL:trackURL forTrack:title];
	if (lyrics == nil)
		return nil;
	else {
		//lyrics = [lyrics stringByAppendingString:@"\n\nLyrics from Lyricwiki.org"];
		return [NSMutableArray arrayWithObjects:trackURL, lyrics, nil];
	}
}

#pragma mark -
#pragma mark Internal/private stuff

-(NSString *)getLyricURLForTrack:(NSString *)theTitle byArtist:(NSString *)theArtist {
	if (theArtist == nil || theTitle == nil)
		return nil;
	
	// Site URLs look like "http://lyricwiki.org/Special:Export/Dark_Tranquillity:Nothing_To_No_One"
	
	NSString *artist = [[theArtist titleCaseString] stringByReplacingOccurrencesOfString:@" " withString:@"_"];
	NSString *title = [[theTitle titleCaseString] stringByReplacingOccurrencesOfString:@" " withString:@"_"];
	artist = [artist stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	title = [title stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

//	return [NSString stringWithFormat:@"http://lyricwiki.org/%@:%@", artist, title];
	return [NSString stringWithFormat:@"http://lyricwiki.org/Special:Export/%@:%@", artist, title];
}

-(NSString *)extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName {
	if (url == nil)
		return nil;
	
	SendNote(@"\tFetching lyrics...\n");
	
	NSError *err;
	NSXMLDocument *xmlDocument;
		xmlDocument = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL URLWithString:url] options:NSXMLDocumentTidyXML error:&err];
		if (err != nil) {
			return nil;
		}
	
	NSString *lyric;
	@try {
		lyric = [[[xmlDocument nodesForXPath:@"//text" error:&err] objectAtIndex:0] description];
	}
	@catch (NSException *e) {
		return nil; // No lyrics found - most likely objectAtIndex failed. Hey, it's easier this way...
	}
	
	if (!lyric || err != nil)
		return nil;
	
	NSString *outStr = nil;
	RKRegex *regex = [RKRegex regexWithRegexString:@"&lt;lyrics>(.*?)&lt;/lyrics>" options:(RKCompileDotAll+RKCompileCaseless+RKCompileMultiline)];

	 SendNote(@"\tParsing lyrics...\n");
	 if (![lyric getCapturesWithRegexAndReferences:regex, @"$1", &outStr, nil])
		 return nil;
	 
	return [outStr substringWithRange:NSMakeRange(1, [outStr length]-2)];
}

@end
*/