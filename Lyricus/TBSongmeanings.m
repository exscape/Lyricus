//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "TBSongmeanings.h"
#import "NSString+ExscapeEdits.h"

@implementation TBSongmeanings

-(TBSongmeanings *) init {
    self = [super init];
    if (self) {
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Public

-(NSString *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist withBatch:(BOOL)batch error:(NSError **)error {
	//
	// The only method called from the outside.
	//

	if (!batch) [self sendStatusUpdate:@"Trying songmeanings..." ofType:LyricusNoteHeader];
	
	if (!batch) [self sendStatusUpdate:@"Searching for artist page..." ofType:LyricusNoteStartedWorking];
	
	NSString *artistURL = [self getURLForArtist:artist error:error];
	if (artistURL == nil) {
		if (!batch) [self sendStatusUpdate:@"Searching for artist page..." ofType:LyricusNoteFailure];
		return nil;
	}
	else
		if (!batch) [self sendStatusUpdate:@"Searching for artist page..." ofType:LyricusNoteSuccess];
	
	if (!batch) [self sendStatusUpdate:@"Searching for lyric page..." ofType:LyricusNoteStartedWorking];
	NSString *trackURL = [self getLyricURLForTrack:title fromArtistURL:artistURL error:error];
	if (trackURL == nil) {
		if (!batch) [self sendStatusUpdate:@"Searching for lyric page..." ofType:LyricusNoteFailure];
		return nil;
	}
	else
		if (!batch) [self sendStatusUpdate:@"Searching for lyric page..." ofType:LyricusNoteSuccess];
	
	if (!batch) [self sendStatusUpdate:@"Downloading lyrics..." ofType:LyricusNoteStartedWorking];
	NSString *lyrics = [self extractLyricsFromURL:trackURL error:error];
	if (lyrics == nil) {
		if (!batch) [self sendStatusUpdate:@"Downloading lyrics..." ofType:LyricusNoteFailure];
		return nil;
	}
	else {
		if (!batch) [self sendStatusUpdate:@"Downloading lyrics..." ofType:LyricusNoteSuccess];
		return lyrics;
	}
}

#pragma mark -
#pragma mark Private/internal

-(NSString *)getURLForArtist:(NSString *) inArtist error:(NSError **)error {
	//
	// Does a search for the artist name, and tries to return the URL to the artist's page,
	// which in turn contains a link to all the artist's songs.
	//
	
	if (inArtist == nil | [inArtist length] < 1)
		return nil;
	
	NSString *artist = [inArtist stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	artist = [artist stringByAddingPercentEscapesUsingEncoding:NSISOLatin1StringEncoding];
    NSURL *url = [NSURL URLWithString: [NSString stringWithFormat:@"http://www.songmeanings.net/query/?q=%@&type=artists&page=1&start=0&mm=1&pp=20&b=Search", artist]];

	// Do the search and fetch results
    NSError *err = nil;
	NSString *html = [TBUtil getHTMLFromURL:url error:&err];

		if (html == nil) {
        if (err != nil) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Unable to download lyrics. This could be a problem with your internet connection or the site(s) used." forKey:NSLocalizedDescriptionKey];
            if (error != nil) {
                *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusHTMLFetchError userInfo:errorDetail];
            }
        }
        return nil;
	}

	if ([html containsString:@"There are <strong>no results</strong>"])
		return nil;
	// else continue...


    NSString *regex = 
    @"<div class=\"row-left\">\\s*<a href=\"http://www.songmeanings.net/artist/view/songs/(\\d+)/\"><strong>(.*?)</strong></a>\\s*</div>";
 	
    NSArray *matchArray = [html arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"id", 1, @"artist", 2, nil];

    for (NSDictionary *match in matchArray) {
		if ([inArtist isEqualToCharactersInString:[match objectForKey:@"artist"] ignoringCase:YES])
			return [NSString stringWithFormat:@"http://www.songmeanings.net/artist/view/songs/%@/", [match objectForKey:@"id"]];
	}

	return nil;
}

-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)artistURL error:(NSError **)error {
	//
	// Given an artist URL and a track, this tries to return the URL to the actual lyric.
	//
	
    NSError *err = nil;
	NSString *html = [TBUtil getHTMLFromURL:[NSURL URLWithString:artistURL] error:&err];

	if (html == nil) {
        if (err != nil) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Unable to download lyrics. This could be a problem with your internet connection or the site(s) used." forKey:NSLocalizedDescriptionKey];
            if (error != nil) {
                *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusHTMLFetchError userInfo:errorDetail];
            }
        }
        return nil;
    }
	
    NSString *regex = 
      @"<tr class='row[01]'><td><a href=\"/songs/view/(\\d+)/\">(.*?)</a></td>";
    
	NSArray *matchArray = [html arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"id", 1, @"title",2, nil];
    for (NSDictionary *match in matchArray) {
		
		if ([TBUtil string:title isEqualToString:[match objectForKey:@"title"]])
			return [NSString stringWithFormat:@"http://www.songmeanings.net/songs/view/%@/", [match objectForKey:@"id"]];
	}
	return nil;
}

-(NSString *)extractLyricsFromURL:(NSString *)url error:(NSError **)error {
	//
	// Given an URL and the track's name, tries to extract the lyrics.
	//
	if (url == nil)
		return nil;
    
    NSError *err = nil;
	NSString *html = [TBUtil getHTMLFromURL:[NSURL URLWithString:url] error:&err];

	if (html == nil) {
        if (err != nil) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Unable to download lyrics. This could be a problem with your internet connection or the site(s) used." forKey:NSLocalizedDescriptionKey];
            if (error != nil) {
                *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusHTMLFetchError userInfo:errorDetail];
            }
        }
        return nil;
    }
	
	// Check for "We are not authorized to display these lyrics"... Ugh.
	// I honestly can't see who gets hurt by allowing people to read song lyrics, but hey... I don't make 
	// these decisions.
	
	if ([html containsString:@"are not authorized to display these lyrics."])
		return nil;
    
	NSString *regex = 
	//	@"<!-- end ringtones -->([\\s\\S]*?)<!--ringtones and media links -->";
	//@"<div id=\"songText2\" style=\"font-size: 11px;\"class=\"protected\">\\s*\r\n(?:<script type=\"text/javascript\">[\\s\\S]+?</script>)?([\\s\\S]*?)(?:<br/>---<br/>\"[\\s\\S]+\" as written|\\s*<!--ringtones and media links -->)";
	@"<div id=\"songText2\" style=\"font-size: 11px;\"class=\"protected\">\\s*([\\s\\S]*?)(?:<br/>---<br/>\"[\\s\\S]+\" as written|\\s*<!--ringtones and media links -->)";
	
	NSMutableString *lyrics = [[html stringByMatching:regex capture:1L] mutableCopy];

    if (lyrics == nil) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:@"Unable to parse lyrics from songmeanings. Please report this to the developer at serenity@exscape.org!" forKey:NSLocalizedDescriptionKey];
        if (error != nil) {
            *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusLyricParseError userInfo:errorDetail];
        }
        return nil;
    }
	
	// Due to a bug(?) in RegexKitLite (?: doesn't appear to work properly, as it still matches...? It works as I intend in RegexBuddy), I couldn't get the JavaScript stub that shows up for SOME lyrics to not match properly, so we need to remove it here...
	
	[lyrics replaceOccurrencesOfRegex:@"<script[\\s\\S]+</script>" withString:@""];

	// Clean up HTML tags, especially <br />
    [lyrics replaceOccurrencesOfRegex:@"<[^>]*>" withString:@""];
    return [lyrics stringByTrimmingWhitespace];
}

@end
