/*
 Day.m
 AppSalesMobile
 
 * Copyright (c) 2008, omz:software
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY omz:software ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <copyright holder> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "Day.h"
#import "App.h"
#import "Country.h"
#import "Entry.h"
#import "CurrencyManager.h"
#import "AppIconManager.h"
#import "ReportManager.h"
#import "AppManager.h"

static BOOL containsOnlyWhiteSpace(NSArray* array) {
	NSCharacterSet *charSet = [NSCharacterSet whitespaceCharacterSet];
	for (NSString *string in array) {
		for (int i = string.length - 1; i >= 0; i--) {
			if (! [charSet characterIsMember:[string characterAtIndex:i]]) {
				return NO;
			}
		}
	}
	return YES;
}

static BOOL parseDateString(NSString *dateString, int *year, int *month, int *day) {
	if ([dateString rangeOfString:@"/"].location == NSNotFound) {
		if (dateString.length == 8) { // old date format
			*year = [[dateString substringWithRange:NSMakeRange(0,4)] intValue];
			*month = [[dateString substringWithRange:NSMakeRange(4,2)] intValue];
			*day = [[dateString substringWithRange:NSMakeRange(6,2)] intValue];
			return YES; // parsed ok
		}
	} else if (dateString.length == 10) { // new date format
		*year = [[dateString substringWithRange:NSMakeRange(6,4)] intValue];
		*month = [[dateString substringWithRange:NSMakeRange(0,2)] intValue];
		*day = [[dateString substringWithRange:NSMakeRange(3,2)] intValue];
		return YES;
	}
	return NO; // unrecognized string
}


@implementation Day

@synthesize date, countries, isWeek, wasLoadedFromDisk, summary, isFault;

//+ (NSString*) fileNameForString:(NSString*)name extension:(NSString*)fileExtension isWeek:(BOOL)isWeek {
//	return [NSString stringWithFormat:@"%@_%@.%@",  (isWeek ? @"week" : @"day"), 
//			[name stringByReplacingOccurrencesOfString:@"/" withString:@"_"], 
//			fileExtension];
//}

- (id)initWithCSV:(NSString *)csv
{
	[super init];
	
	wasLoadedFromDisk = NO;	
	countries = [[NSMutableDictionary alloc] init];
	
	NSMutableArray *lines = [[[csv componentsSeparatedByString:@"\n"] mutableCopy] autorelease];
	if ([lines count] > 0)
		[lines removeObjectAtIndex:0];
	if ([lines count] == 0) {
		[self release];
		return nil; // sanity check
	}
//	lines = [lines subarrayWithRange:NSMakeRange(1, lines.count-1)];
	
	for (NSString *line in lines) {
		NSArray *columns = [line componentsSeparatedByString:@"\t"];
		if (containsOnlyWhiteSpace(columns)) {
			continue;
		}
		if ([columns count] >= 19) {
			NSString *productName = [columns objectAtIndex:6];
			NSString *transactionType = [columns objectAtIndex:8];
			NSString *units = [columns objectAtIndex:9];
			NSString *royalties = [columns objectAtIndex:10];
			NSString *dateColumn = [columns objectAtIndex:11];
			NSString *toDateColumn = [columns objectAtIndex:12];
			NSString *appId = [columns objectAtIndex:19];
			NSString *parentID;
			if ([columns count] >=26) {
				 parentID = [columns objectAtIndex:26];
			}
			[[AppIconManager sharedManager] downloadIconForAppID:appId];
			if (!self.date) {
				NSDate *fromDate = [self reportDateFromString:dateColumn];
				NSDate *toDate = [self reportDateFromString:toDateColumn];
				if (!fromDate) {
					NSLog(@"Date is invalid: %@", dateColumn);
					[self release];
					return nil;
				} else {
					date = [fromDate retain];
					if (![fromDate isEqualToDate:toDate]) {
						isWeek = YES;
					}
				}
			}
			NSString *countryString = [columns objectAtIndex:14];
			if ([countryString length] != 2) {
				NSLog(@"Country code is invalid");
				[self release];
				return nil; //sanity check, country code has to have two characters
			}
			NSString *royaltyCurrency = [columns objectAtIndex:15];
			
			//Treat in-app purchases as regular purchases for our purposes.
			//IA1: In-App Purchase
			//IA7: In-App Free Upgrade / Repurchase (?)
			//IA9: In-App Subscription
			if ([transactionType isEqualToString:@"IA1"]) transactionType = @"2";
			else
				if([transactionType isEqualToString:@"IA9"]) transactionType = @"9";
			else
				if ([transactionType isEqualToString:@"IA7"]) transactionType = @"7";
			
			Country *country = [self countryNamed:countryString]; //will be created on-the-fly if needed.
			Entry *entry = [[[Entry alloc] initWithProductIdentifier:appId
																name:productName 
													 transactionType:[transactionType intValue] 
															   units:[units intValue] 
														   royalties:[royalties floatValue] 
															currency:royaltyCurrency
															 country:country] autorelease]; //gets added to the countries entry list automatically
			entry.inAppPurchase = ![parentID isEqualToString:@" "];
		}
	}

	// local version
	//
//		if (columns.count < 19) {
//			NSLog(@"unknown column format: %@", columns.description); // instead should stop parsing and return nil?
//			continue;
//		}
//		NSString *productName = [columns objectAtIndex:6];
//		NSString *transactionType = [columns objectAtIndex:8];
//		NSString *units = [columns objectAtIndex:9];
//		NSString *royalties = [columns objectAtIndex:10];
//		NSString *dateStartColumn = [columns objectAtIndex:11];
//		NSString *dateEndColumn = [columns objectAtIndex:12];
//		NSString *appId = [columns objectAtIndex:19];
//		[[AppIconManager sharedManager] downloadIconForAppID:appId];
//		isWeek = ![dateStartColumn isEqualToString:dateEndColumn];
//		
//		int startYear, startMonth, startDay;
//		if (! parseDateString(dateStartColumn, &startYear, &startMonth, &startDay)) {
//			NSLog(@"invalid startDate: %@", dateStartColumn);
//			[self release];
//			return nil;
//		}
//		
//		int endYear, endMonth, endDay;
//		if (! parseDateString(dateEndColumn, &endYear, &endMonth, &endDay)) {
//			NSLog(@"invalid endDate: %@", dateEndColumn);
//			[self release];
//			return nil;
//		}
//		
//		NSCalendar *calendar = [NSCalendar currentCalendar];
//		NSDateComponents *components = [[NSDateComponents new] autorelease];
//		[components setYear:startYear];
//		[components setMonth:startMonth];
//		[components setDay:startDay];
//		date = [[calendar dateFromComponents:components] retain];
//		name = [[NSString alloc] initWithFormat:@"%02d/%02d/%d", startMonth, startDay, startYear];
//		weekEndDateString = [[NSString alloc] initWithFormat:@"%02d/%02d/%d", endMonth, endDay, endYear];
//
//		NSString *countryString = [columns objectAtIndex:14];
//		if (countryString.length != 2) { // country code has two characters
//			[NSException raise:@"invalid country code" format:countryString];
//		}
//		NSString *royaltyCurrency = [columns objectAtIndex:15];
//		
//		/* Treat in-app purchases as regular purchases for our purposes.
//		 * IA1: In-App Purchase
//		 * Presumably, IA7: In-App Free Upgrade / Repurchase.
//		 */
//		if ([transactionType isEqualToString:@"IA1"]) {
//			transactionType = @"1";
//		}
//
//		Country *country = [self countryNamed:countryString]; // will be created on-the-fly if needed.
//		[[[Entry alloc] initWithProductIdentifier:appId
//											 name:productName 
//								  transactionType:[transactionType intValue] 
//											units:[units intValue] 
//										royalties:[royalties floatValue] 
//										 currency:royaltyCurrency
//										  country:country] release]; // gets added to the countries entry list automatically
//	}
//	if (name == nil || date == nil) {
//		NSLog(@"coulnd't parse CSV: %@", csv);
//		[self release];
//		return nil;
//	}


	[self generateSummary];
	return self;
}

- (void)generateSummary
{
	NSMutableDictionary *revenueByCurrency = [NSMutableDictionary dictionary];
	NSMutableDictionary *salesByApp = [NSMutableDictionary dictionary];
	for (Country *country in [self.countries allValues]) {
		for (Entry *entry in country.entries) {
			if (entry.purchase ) {
				NSNumber *newCount = [NSNumber numberWithInt:[[salesByApp objectForKey:entry.productName] intValue] + entry.units];
				[salesByApp setObject:newCount forKey:entry.productName];
				NSNumber *oldRevenue = [revenueByCurrency objectForKey:entry.currency];
				NSNumber *newRevenue = [NSNumber numberWithFloat:(oldRevenue ? [oldRevenue floatValue] : 0.0) + entry.royalties * entry.units];
				[revenueByCurrency setObject:newRevenue forKey:entry.currency];
			}
		}
	}
	[summary release];
	summary = [[NSDictionary alloc] initWithObjectsAndKeys: 
									self.date, kSummaryDate,
									revenueByCurrency, kSummaryRevenue,
									salesByApp, kSummarySales,
									[NSNumber numberWithBool:self.isWeek], kSummaryIsWeek,
									nil];
}


- (id) initWithSummary:(NSDictionary*)summaryToUse date:(NSDate*)dateToUse isWeek:(BOOL)week isFault:(BOOL)fault
{
	self = [super init];
	if (self) {
		summary = [summaryToUse retain];
		date = [dateToUse retain];
		isWeek = week;
		isFault = fault;
		wasLoadedFromDisk = YES;
	}
	return self;
}

+ (Day *)dayWithSummary:(NSDictionary *)reportSummary
{
	return [[[Day alloc] initWithSummary:reportSummary date:[reportSummary objectForKey:kSummaryDate]
								  isWeek:[[reportSummary objectForKey:kSummaryIsWeek] boolValue] isFault:YES] autorelease];
}


- (id)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	if (self) {
		date = [[coder decodeObjectForKey:@"date"] retain];
		countries = [[coder decodeObjectForKey:@"countries"] retain];
		isWeek = [coder decodeBoolForKey:@"isWeek"];
		wasLoadedFromDisk = YES;
	}
	return self;
}


- (void)setDate:(NSDate *)inDate
{
	if (inDate != date) {
		[date release];

		/* All dates should be set to midnight. If set otherwise, they were created in a different time zone.
		 * We want the date corresponding to that midnight; using NSCalendar directly would give us the date in 
		 * our local time zone.
		 */
		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSDateComponents *components = [calendar components:NSHourCalendarUnit
												   fromDate:inDate];
		NSInteger hour = components.hour;
		if (hour) {
			NSCalendar *otherCal = [NSCalendar currentCalendar];
			otherCal.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:[NSTimeZone defaultTimeZone].secondsFromGMT + hour*60*60];

			/* Get the day/month/year as seen in the original time zone */
			components = [otherCal components:(NSDayCalendarUnit | NSMonthCalendarUnit| NSYearCalendarUnit)
									 fromDate:inDate];
			
			/* Now set to the date with that day/month/year in our own time zone */
			date = [[calendar dateFromComponents:components] retain];			
		} else {
			date = [inDate retain];
		}
	}
	
}
- (NSMutableDictionary *)countries
{	
	if (isFault) {
		NSString *filename = [self proposedFilename];
		NSString *fullPath = [getDocPath() stringByAppendingPathComponent:filename];
		Day *fulfilledFault = [NSKeyedUnarchiver unarchiveObjectWithFile:fullPath];
		countries = [fulfilledFault.countries retain];
		isFault = NO;
	}
	return countries;
}

+ (Day *)dayFromCSVFile:(NSString *)filename atPath:(NSString *)docPath;
{
	NSString *fullPath = [docPath stringByAppendingPathComponent:filename];
	Day *loadedDay = [[Day alloc] initWithCSV:[NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:nil]];	
	return [loadedDay autorelease];
}

- (BOOL) archiveToDocumentPathIfNeeded:(NSString*)docPath {
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *fullPath = [docPath stringByAppendingPathComponent:self.proposedFilename];
	BOOL isDirectory = false;
	if ([manager fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
		if (isDirectory) {
			[NSException raise:NSGenericException format:@"found unexpected directory at Day path: %@", fullPath];
		}
		return FALSE;
	}
	// hasn't been arhived yet, write it out now
	if (! [NSKeyedArchiver archiveRootObject:self toFile:fullPath]) {
		NSLog(@"could not archive out %@", self);
		return FALSE;
	}
	return TRUE;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.countries forKey:@"countries"];
	[coder encodeObject:self.date forKey:@"date"];
	[coder encodeBool:self.isWeek forKey:@"isWeek"];
}

- (Country *)countryNamed:(NSString *)countryName
{
	Country *country = [self.countries objectForKey:countryName];
	if (!country) {
		country = [[Country alloc] initWithName:countryName day:self];
		[self.countries setObject:country forKey:countryName];
		[country release];
	}
	return country;
}

- (NSDate *)reportDateFromString:(NSString *)dateString
{
	if ((([dateString rangeOfString:@"/"].location != NSNotFound) && ([dateString length] == 10))
		|| (([dateString rangeOfString:@"/"].location == NSNotFound) && ([dateString length] == 8))) {
		int year, month, day;
		if ([dateString rangeOfString:@"/"].location == NSNotFound) { //old date format
			year = [[dateString substringWithRange:NSMakeRange(0,4)] intValue];
			month = [[dateString substringWithRange:NSMakeRange(4,2)] intValue];
			day = [[dateString substringWithRange:NSMakeRange(6,2)] intValue];
		}
		else { //new date format
			year = [[dateString substringWithRange:NSMakeRange(6,4)] intValue];
			month = [[dateString substringWithRange:NSMakeRange(0,2)] intValue];
			day = [[dateString substringWithRange:NSMakeRange(3,2)] intValue];
		}
		
		NSCalendar *calendar = [NSCalendar currentCalendar];
		NSDateComponents *components = [[NSDateComponents new] autorelease];
		[components setYear:year];
		[components setMonth:month];
		[components setDay:day];
		
		return [calendar dateFromComponents:components];
	}
	return nil;
}


- (NSString *)description
{
	NSDictionary *salesByProduct = nil;
	if (!self.summary) {
		NSMutableDictionary *temp = [NSMutableDictionary dictionary];
		for (Country *c in [self.countries allValues]) {
			for (Entry *e in [c entries]) {
				if (e.purchase) {
					NSNumber *unitsOfProduct = [temp objectForKey:[e productName]];
					int u = (unitsOfProduct != nil) ? ([unitsOfProduct intValue]) : 0;
					u += [e units];
					[temp setObject:[NSNumber numberWithInt:u] forKey:[e productName]];
				}
			}
		}
		salesByProduct = temp;
	} else {
		salesByProduct = [summary objectForKey:kSummarySales];
	}
		
	NSMutableString *productSummary = [NSMutableString stringWithString:@"("];
	
	NSEnumerator *reverseEnum = [[salesByProduct keysSortedByValueUsingSelector:@selector(compare:)] reverseObjectEnumerator];
	NSString *productName;
	while ((productName = reverseEnum.nextObject) != nil) {
		NSNumber *productSales = [salesByProduct objectForKey:productName];
		[productSummary appendFormat:@"%@ × %@, ", productSales, productName];
	}
	if (productSummary.length >= 2)
		[productSummary deleteCharactersInRange:NSMakeRange(productSummary.length - 2, 2)];
	[productSummary appendString:@")"];
	if ([productSummary isEqual:@"()"]) {
		return NSLocalizedString(@"No sales",nil);
	}
	return productSummary;
}

- (float)totalRevenueInBaseCurrency
{
	if (self.summary) {
		float sum = 0.0;
		NSDictionary *revenueByCurrency = [summary objectForKey:kSummaryRevenue];
		for (NSString *currency in revenueByCurrency) {
			float revenue = [[CurrencyManager sharedManager] convertValue:[[revenueByCurrency objectForKey:currency] floatValue] fromCurrency:currency];
			sum += revenue;
		}
		return sum;
	} else {
		float sum = 0.0;
		for (Country *c in [self.countries allValues]) {
			sum += [c totalRevenueInBaseCurrency];
		}
		return sum;
	}
}

- (float)totalRevenueInBaseCurrencyForAppWithID:(NSString *)appID {
	if (appID == nil)
		return [self totalRevenueInBaseCurrency];
	float sum = 0.0;
	for (Country *c in [self.countries allValues]) {
		sum += [c totalRevenueInBaseCurrencyForAppWithID:appID];
	}
	return sum;
}

- (int)totalUnitsForAppWithID:(NSString *)appID {
	if (appID == nil)
		return [self totalUnits];
	int sum = 0;
	for (Country *c in [self.countries allValues]) {
		sum += [c totalUnitsForAppWithID:appID];
	}
	return sum;
}


- (int)totalUnits
{
	int sum = 0;
	for (Country *c in self.countries.allValues) {
		sum += c.totalUnits;
	}
	return sum;
}

- (NSArray *)allProductIDs
{
	NSMutableSet *names = [NSMutableSet set];
	for (Country *c in self.countries.allValues) {
		[names addObjectsFromArray:c.allProductIDs];
	}
	return names.allObjects;
}

//- (NSArray *)allProductNames
//{
//	NSMutableSet *names = [NSMutableSet set];
//	for (Country *c in [self.countries allValues]) {
//		[names addObjectsFromArray:[c allProductNames]];
//	}
//	return [names allObjects];
//}

- (NSString *)totalRevenueString
{
	return [[CurrencyManager sharedManager] baseCurrencyDescriptionForAmount:
			[NSNumber numberWithFloat:self.totalRevenueInBaseCurrency] withFraction:YES];
}

- (NSString *)totalRevenueStringForApp:(NSString *)appName
{
	NSString *appID = [[AppManager sharedManager] appIDForAppName:appName];
	return [[CurrencyManager sharedManager] baseCurrencyDescriptionForAmount:[NSNumber numberWithFloat:[self totalRevenueInBaseCurrencyForAppWithID:appID]] withFraction:YES];
}

- (NSString *)dayString
{
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit fromDate:self.date];
	return [NSString stringWithFormat:@"%i", [components day]];
}

- (NSString *)weekdayString
{
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateFormat:@"EEE"];
	return [[dateFormatter stringFromDate:self.date] uppercaseString];
}

- (UIColor *)weekdayColor
{
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSWeekdayCalendarUnit fromDate:self.date];
	int weekday = [components weekday];
	if (weekday == 1) {
		return [UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0];
	}
	return [UIColor blackColor];
}

- (NSString *)weekEndDateString
{
	NSDateComponents *comp = [[[NSDateComponents alloc] init] autorelease];
	[comp setHour:167];
	NSDate *dateWeekLater = [[NSCalendar currentCalendar] dateByAddingComponents:comp toDate:self.date options:0];
	NSDateFormatter *dateFormatter = [[NSDateFormatter new] autorelease];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	return [dateFormatter stringFromDate:dateWeekLater];
}


- (NSArray *)children
{
	NSSortDescriptor *sorter = [[[NSSortDescriptor alloc] initWithKey:@"totalUnits" ascending:NO] autorelease];
	NSArray *sortedChildren = [self.countries.allValues sortedArrayUsingDescriptors:[NSArray arrayWithObject:sorter]];
	return sortedChildren;
}


- (NSString *)proposedFilename
{
//	if (proposedFileName == nil) {
//		// use year/month/day, so serialized files are sortable by date
//		NSDateComponents *components = [[NSCalendar currentCalendar] components:NSYearCalendarUnit
//																				| NSMonthCalendarUnit 
//																				| NSDayCalendarUnit
//																	   fromDate:self.date];
//		NSString *sortableName = [NSString stringWithFormat:@"%d/%02d/%02d", components.year, components.month, components.day];
//		proposedFileName = [[Day fileNameForString:sortableName extension:@"dat" isWeek:isWeek] retain];
//	}
//	return proposedFileName;
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormatter setDateFormat:@"MM_dd_yyyy"];
	NSString *dateString = [dateFormatter stringFromDate:self.date];
	if (self.isWeek) {
		return [NSString stringWithFormat:@"week_%@.dat", dateString];
	} else {
		return [NSString stringWithFormat:@"day_%@.dat", dateString];
	}
}

- (NSString *)appIDForApp:(NSString *)appName {
	NSString *appID = nil;
	for(Country *c in [self.countries allValues]){
		appID = [c appIDForApp:appName];
		if(appID)
			break;
	}
	return appID;
}

- (void)dealloc
{
	[countries release];
	[date release];
	[summary release];
	
	[super dealloc];
}

@end
