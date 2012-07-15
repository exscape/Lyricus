//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "NSString+ExscapeEdits.h"
#import "RegexKitLite.h"

@implementation NSString (ExscapeEdits)

-(NSString *)titleCaseString {
	//
	// I have no idea if self CAN be nil here... Please mail me (serenity@exscape.org) if you know. ;)
	//
	if (self == nil)
		return nil;
	
	NSArray *words = [self componentsSeparatedByString:@" "];
	NSMutableString *outString = [[NSMutableString alloc] init];
	
	for (NSString *word in words) {
		if (![word isMatchedByRegex:@"^\\w"]) { // could probably use isalpha() or something instead, but the speed hardly matters here
			[outString appendFormat:@"%@ ", word];
			continue;
		}
		[outString appendFormat:@"%@%@ ", 
		 [[word substringWithRange:NSMakeRange(0,1)] uppercaseString], 
		 [[word substringFromIndex:1] lowercaseString]];
	}
	
	return [outString stringByTrimmingWhitespace];
}

-(BOOL) containsString:(NSString *)needle {
	// Convenience function for the one below
	return [self containsString:needle ignoringCaseAndDiacritics:NO];
}

-(BOOL) containsString:(NSString *)needle ignoringCaseAndDiacritics:(BOOL) ignoreCase {
	if (self == nil || needle == nil)
		return NO;

	NSStringCompareOptions options;
	if (ignoreCase == YES)
		options = (NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch);
	else
		options = 0;
		
	NSRange foundRange = [self rangeOfString:needle options:options];
	return (foundRange.location != NSNotFound);
}

-(NSString *)stringByTrimmingWhitespace {
    NSString *outString = [self stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n\t "]];
    return outString;
}

-(NSString *)stringByStrippingNonCharacters {
	// Remove all noncharacters (usually all except a-z 0-9 _)
	NSString *str = [NSString stringWithString:self];
    str = [str stringByReplacingOccurrencesOfRegex:@"\\W" withString:@""];
	return [str stringByReplacingOccurrencesOfRegex:@"[\\t ]" withString:@""];;
}

-(BOOL)isEqualToCharactersInString:(NSString *)otherString ignoringCase:(BOOL)ignoreCase {
	//
	// Use the above function to compare strings
	//
	
	NSString *s1 = [self stringByStrippingNonCharacters];
	NSString *s2 = [otherString stringByStrippingNonCharacters];
	NSStringCompareOptions searchOpt = ( ignoreCase ? NSCaseInsensitiveSearch : 0 );
	
	return ( [s1 compare: s2 options:searchOpt] == NSOrderedSame );
}

@end
