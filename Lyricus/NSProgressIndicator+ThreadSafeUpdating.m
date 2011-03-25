//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "NSProgressIndicator+ThreadSafeUpdating.h"


@implementation NSProgressIndicator (ThreadSafeUpdating)

//
// NOTE: These methods are NOT thread-safe on their own.
// They are, however, needed to to performSelectorOnMainThread, since doubles aren't objects, and thus
// cannot be passed using that method.
//

-(void) thrSetMaxValue:(NSNumber *)max {
	[self setMaxValue:[max doubleValue]];
}
-(void) thrSetMinValue:(NSNumber *)min {
	[self setMinValue:[min doubleValue]];
}

-(void) thrSetCurrentValue:(NSNumber *)current {
	[self setDoubleValue:[current doubleValue]];
}

-(void) thrIncrementBy:(NSNumber *)delta {
	[self incrementBy:[delta doubleValue]];
}

@end