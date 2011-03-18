
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSProgressIndicator (ThreadSafeUpdating)
-(void) thrSetMaxValue:(NSNumber *)max;
-(void) thrSetMinValue:(NSNumber *)min;
-(void) thrSetCurrentValue:(NSNumber *)current;
-(void) thrIncrementBy:(NSNumber *)delta;
@end