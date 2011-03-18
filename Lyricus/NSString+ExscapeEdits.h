
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/NSString.h>

//
// Adds some convenience methods to NSString
// These are NOT really written with speed in mind, so if you copy them,
// make sure to benchmark where speed matters!
//
@interface NSString (ExscapeEdits)

// "my good old string" -> "My Good Old String"
-(NSString *)titleCaseString;

-(BOOL) containsString:(NSString *)needle;
// Plain old strstr() or stristr()
// with ignoreCase == YES, "my üâ string" should be equal to "My UA stRing" (what do you mean, contrived example?)
-(BOOL) containsString:(NSString *)needle ignoringCaseAndDiacritics:(BOOL) ignoreCase;

// Removes whitespace at the start and/or end of the string
-(NSString *)stringByTrimmingWhitespace;

// Removes ALL non-characters (all chars that match the \W regex, usually everything except a-z, 0-9 and underscores)
-(NSString *)stringByStrippingNonCharacters;

// Compares strings using the above function.
// "  My String, '" is equal to "My String" (since the comparison actually done is "MyString" == "MyString")
-(BOOL)isEqualToCharactersInString:(NSString *)otherString ignoringCase:(BOOL)ignoreCase;

@end
