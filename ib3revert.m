//
//  ib3revert.m
//  ib3revert
//
//  Created by Jeremiah Sypult on 10/14/13.
//
//  Released under no license. PUBLIC DOMAIN. NO WARRANTY. USE AT YOUR OWN RISK.
//  http://unlicense.org
//
//==============================================================================
//
//	when reading XIB files that have been altered by Xcode 5, here are the
//	elements we are interested in traversing & modifying to allow the file
//	open in Xcode 3:
//
//	<archive ...
//		<data ...
//			<object class="IBObjectContainer" key="IBDocument.Objects">
//				<array class="NSMutableArray" key="connectionRecords">
//					<object class="IBConnectionRecord">
//						<string key="id">AAA-BB-CCC</string>
//
//						(Xcode 3: <int key="connectionID">####</int>)
//
//				<object class="IBMutableOrderedSet" key="objectRecords">
//					<object class="IBObjectRecord">
//						<string key="id">XXX-YY-ZZZ</string>
//
//						(Xcode 3: <int key="objectID">####</int>)
//
//				<dictionary class="NSMutableDictionary" key="flattenedProperties">
//					<string key="XXX-YY-ZZZ.IBPluginDependency">com.apple.InterfaceBuilder.CocoaPlugin</string>
//
//					(Xcode 3: <string key="####....">....</string>
//
//				must add this key in IBObjectContainer since Xcode 5 removes it:
//				<int key="maxID">##maxID##</int>

#import <Cocoa/Cocoa.h>

#define AUTHOR "jeremiah sypult"
#define VERSION "1.0"

//==============================================================================

static NSString *kIBkey = @"key";
static NSString *kIBclass = @"class";

static NSString *kIBarchive = @"archive";
static NSString *kIBdata = @"data";
static NSString *kIBobject = @"object";
static NSString *kIBarray = @"array";
static NSString *kIBstring = @"string";
static NSString *kIBint = @"int";
static NSString *kIBdictionary = @"dictionary";

static NSString *kIBconnectionID = @"connectionID";
static NSString *kIBobjectID = @"objectID";
static NSString *kIBid = @"id";
static NSString *kIBmaxID = @"maxID";

static NSString *kIBObjectContainer = @"IBObjectContainer";
static NSString *kIBDocumentObjects = @"IBDocument.Objects";

static NSString *kIBNSMutableArray = @"NSMutableArray";
static NSString *kIBMutableOrderedSet = @"IBMutableOrderedSet";
static NSString *kIBNSMutableDictionary = @"NSMutableDictionary";

static NSString *kIBconnectionRecords = @"connectionRecords";
static NSString *kIBobjectRecords = @"objectRecords";
static NSString *kIBflattenedProperties = @"flattenedProperties";

//==============================================================================
// searches an elements children for a specific name, class and key
NSXMLElement *elementFor(NSXMLElement *data, NSString *elementName, NSString *classValueMatch, NSString *keyValueMatch)
{
	NSArray *children = [data elementsForName:elementName];
	NSUInteger count = children.count;

	for (NSUInteger i = 0; i < count; i++) {
		NSXMLElement *element = [children objectAtIndex:i];
		NSString *classValue = [element attributeForName:kIBclass].stringValue;
		NSString *keyValue = [element attributeForName:kIBkey].stringValue;

		if ([classValue isEqualToString:classValueMatch] && [keyValue isEqualToString:keyValueMatch]) {
			return element;
		}
	}

	return nil;
}

//==============================================================================

int main(int argc, const char * argv[])
{
	NSAutoreleasePool *autoreleasepool = [[NSAutoreleasePool alloc] init];
	BOOL didConfirmOverwrite = NO;
	BOOL didMakeChanges = NO;
	const char *path = argv[0];
	const char *file = argv[1];
	char *app = (char*)path + strlen( path ) - 1;
	int returnValue = 0;

	// work backwards from the string in an attempt to find the first
	// path separator. a char* pointer from there should trim the app name
	while ( app > path && *(app - 1) != '/' ) {
		app--;
	}

	printf( "%s v%s\n", app, VERSION );
	printf( "attempts to revert XIB for Xcode 3 use.\n" );
	printf( "code: %s, PUBLIC DOMAIN\n", AUTHOR );
	printf( "** NO WARRANTY! USE AT YOUR OWN RISK! **\n" );
	printf( "----------------------------------------\n" );

	if ( argc < 2 ) {
		printf( "%s <filepath.xib> [-confirm]\n\n", app );
		returnValue = 1;
		goto end;
	}

	if ( argc >= 3 ) {
		const char *confirm = argv[2];
		char *confirmResult = strstr( confirm, "-confirm" );
		if ( confirmResult ) {
			didConfirmOverwrite = YES;
		}
	}

	NSError *error = nil;
	NSString *xmlString = [NSString stringWithUTF8String:file];
	NSURL *xmlURL = [NSURL fileURLWithPath:xmlString];
	NSXMLDocument *xmlDocument = [[NSXMLDocument alloc] initWithContentsOfURL:xmlURL
																	  options:NSXMLNodePreserveAll
																		error:(NSError **)&error];
	NSXMLElement *archive = [xmlDocument rootElement];
	NSXMLElement *data = [archive.children objectAtIndex:0];

	NSXMLElement *ibObjectContainer = nil;
	NSXMLElement *connectionRecords = nil;
	NSXMLElement *objectRecords = nil;
	NSXMLElement *flattenedProperties = nil;

	if ( !xmlDocument || !archive || !data || ![archive.name isEqualToString:kIBarchive] || ![data.name isEqualToString:kIBdata] ) {
		printf( "error loading XIB XML.\n" );
		returnValue = 1;
		goto releaseXML;
	}

	printf( "opened: %s\n", xmlURL.path.fileSystemRepresentation );

	if ( didConfirmOverwrite ) {
		printf( "**** OVERWRITE CONFIRMED - YOU HAVE BEEN WARNED ****\n" );
	}

	printf( "\n" );

	ibObjectContainer = elementFor( data, kIBobject, kIBObjectContainer, kIBDocumentObjects );
	if ( !ibObjectContainer ) {
		printf( "error locating IBDocument.Objects.\n" );
		returnValue = 1;
		goto releaseXML;
	}

	connectionRecords = elementFor( ibObjectContainer, kIBarray, kIBNSMutableArray, kIBconnectionRecords );
	if ( !connectionRecords ) {
		printf( "error locating connectionRecords.\n" );
		printf( "this XIB may already be compatible with Xcode 3?\n" );
		returnValue = 1;
		goto releaseXML;
	}

	objectRecords = elementFor( ibObjectContainer, kIBobject, kIBMutableOrderedSet, kIBobjectRecords );
	if ( !objectRecords ) {
		printf( "error locating objectRecords.\n" );
		returnValue = 1;
		goto releaseXML;
	}

	flattenedProperties = elementFor( ibObjectContainer, kIBdictionary, kIBNSMutableDictionary, kIBflattenedProperties );
	if ( !flattenedProperties ) {
		printf( "error locating flattenedProperties.\n" );
		returnValue = 1;
		goto releaseXML;
	}

	NSMutableDictionary *oldIDDict = [[NSMutableDictionary alloc] init];
	NSMutableDictionary *newIDDict = [[NSMutableDictionary alloc] init];

	// TODO: check for duplicate id's between connectionRecords and objectRecords?
	// is that possible? are the ids all globally unique vs. scope?

	// connectionRecords
	NSArray *connectionRecordObjects = [connectionRecords elementsForName:kIBobject];

	for ( NSUInteger i = 0; i < connectionRecordObjects.count; i++ ) {
		NSXMLElement *object = [connectionRecordObjects objectAtIndex:i];
		NSArray *objectStrings = [object elementsForName:kIBstring];

		for ( NSUInteger j = 0; j < objectStrings.count; j++ ) {
			NSXMLElement *string = [objectStrings objectAtIndex:j];
			NSString *keyValue = [string attributeForName:kIBkey].stringValue;

			if ( [keyValue isEqualToString:kIBid] ) {
				didMakeChanges = YES;
				//printf( "connectionRecords %s: %s\n", keyValue.UTF8String, string.stringValue.UTF8String );

				// transform from <string key="id" ... to <int key="connectionID" ...
				string.name = kIBint;
				[string attributeForName:kIBkey].stringValue = kIBconnectionID;

				[oldIDDict setValue:[NSValue valueWithPointer:(const void*)string] forKey:string.stringValue];
			}
		}
	}

	// objectRecords
	NSArray *objectRecordArray = [objectRecords elementsForName:kIBarray];
	NSXMLElement *objectRecordsExtract = [objectRecordArray objectAtIndex:0];
	NSArray *objectRecordObjects = [objectRecordsExtract elementsForName:kIBobject];

	for ( NSUInteger i = 0; i < objectRecordObjects.count; i++ ) {
		NSXMLElement *object = [objectRecordObjects objectAtIndex:i];
		NSArray *objectStrings = [object elementsForName:kIBstring];

		for ( NSUInteger j = 0; j < objectStrings.count; j++ ) {
			NSXMLElement *string = [objectStrings objectAtIndex:j];
			NSString *keyValue = [string attributeForName:kIBkey].stringValue;

			if ( [keyValue isEqualToString:kIBid] ) {
				didMakeChanges = YES;
				//printf( "objectRecords %s: %s\n", keyValue.UTF8String, string.stringValue.UTF8String );

				// transform from <string key="id" ... to <int key="objectID" ...
				string.name = kIBint;
				[string attributeForName:kIBkey].stringValue = kIBobjectID;

				[oldIDDict setValue:[NSValue valueWithPointer:(const void*)string] forKey:string.stringValue];
			}
		}
	}

	// find the highest ID between connection & object records
	int maxKeyID = -99999;

	for ( NSUInteger i = 0; i < oldIDDict.allKeys.count; i++ ) {
		NSString *key = [oldIDDict.allKeys objectAtIndex:i];
		int keyID = -99999;

		if ( sscanf( key.UTF8String, "%i", &keyID ) == 1 ) {
			if ( keyID > maxKeyID ) {
				maxKeyID = keyID;
			}
		}
	}

	// create a dictionary map of id replacements
	// key is the new, incremented replacement integer id.
	// value is a pointer to the XML element containing the id to be replcaed.
	int nextKeyID = maxKeyID;

	for ( NSUInteger i = 0; i < oldIDDict.allKeys.count; i++ ) {
		NSString *key = [oldIDDict.allKeys objectAtIndex:i];
		int keyint = -99999;
		char bogus = -127;

		int bigmatch = sscanf( key.UTF8String, "%c%c%c-%c%c-%c%c%c", &bogus, &bogus, &bogus, &bogus, &bogus, &bogus, &bogus, &bogus );
		int littlematch = sscanf( key.UTF8String, "%i", &keyint );

		//printf( "dict id: %s\n", key.UTF8String );

		if ( bigmatch == 8 ) {
			NSXMLElement *replacementID = [(NSValue*)[oldIDDict valueForKey:key] pointerValue];
			bogus = -127;

			if ( replacementID ) {
				NSString *newID = [NSString stringWithFormat:@"%i", ++nextKeyID];
				[newIDDict setValue:[NSValue valueWithPointer:(const void*)replacementID] forKey:newID];
			}
		} else if ( littlematch == 1 ) {
			keyint = -9999;
		} else {
			// badness!
			printf( "unexpected result reading key %s\n", key.UTF8String );
			returnValue = 1;
			goto releaseDicts;
		}
	}

	// flattenedProperties
	// iterate through the flattenedProperties looking for keys that have
	// a prefix of the desired string ids to be replaced
	// replace the text with our incremented integer id string
	for ( NSUInteger i = 0; i < flattenedProperties.children.count; i++ ) {
		NSXMLElement *prop = [flattenedProperties.children objectAtIndex:i];
		NSXMLNode *propNode = [prop attributeForName:kIBkey];
		NSString *keyValue = propNode.stringValue;

		for ( NSUInteger j = 0; j < newIDDict.allValues.count; j++ ) {
			NSString *key = [newIDDict.allKeys objectAtIndex:j];
			NSXMLElement *replacementID = [(NSValue*)[newIDDict.allValues objectAtIndex:j] pointerValue];

			// REPLACES XML DATA
			if ( replacementID && keyValue && [keyValue hasPrefix:replacementID.stringValue] ) {
				didMakeChanges = YES;
				NSString *newKeyValue = [keyValue stringByReplacingOccurrencesOfString:replacementID.stringValue withString:key];
				//printf( "%s == %s -> %s\n", replacementID.stringValue.UTF8String, keyValue.UTF8String, newKeyValue.UTF8String );
				printf( "%s -> ", keyValue.UTF8String );
				propNode.stringValue = newKeyValue;
				printf( "%s\n", propNode.stringValue.UTF8String );
			}
		}
	}

	// finally perform the id replacement against the dictionary containing
	// the xml elements where all desired key ids were found.
	for ( NSUInteger i = 0; i < newIDDict.allValues.count; i++ ) {
		NSString *key = [newIDDict.allKeys objectAtIndex:i];
		NSXMLElement *replacementID = [(NSValue*)[newIDDict.allValues objectAtIndex:i] pointerValue];

		// REPLACES XML DATA
		if ( replacementID ) {
			NSXMLNode *nodeAttr = (NSXMLNode*)[replacementID.attributes objectAtIndex:0];
			NSString *attributeName = nodeAttr.stringValue;
			const char *attr = attributeName ? attributeName.UTF8String : "UNKNOWN";

			didMakeChanges = YES;
			printf( "id=\"%s\" -> ", replacementID.stringValue.UTF8String );
			replacementID.stringValue = key;
			printf( "%s=\"%s\"\n", attr, replacementID.stringValue.UTF8String );
		}
	}

	if ( didMakeChanges ) {
		// add <int key="maxID">####</int>
		// TODO: make sure this doesn't already exist?
		NSXMLNode *maxIDKey = [NSXMLNode attributeWithName:kIBkey stringValue:kIBmaxID];
		NSXMLElement *maxID = [NSXMLElement elementWithName:kIBint stringValue:[[NSNumber numberWithInt:nextKeyID] stringValue]];
		[maxID addAttribute:maxIDKey];
		[ibObjectContainer addChild:maxID];

		// WRITE OUT A NEW FILE?
		if ( didConfirmOverwrite ) {
			NSURL *outURL = xmlURL; // OVERWRITES FILE, consider another approach?
			if ( ![[xmlDocument XMLDataWithOptions:NSXMLNodePrettyPrint] writeToURL:outURL atomically:YES] ) {
				printf( "could not write file: %s\n", outURL.path.fileSystemRepresentation );
				returnValue = 1;
				goto releaseDicts;
			} else {
				printf( "overwrite: %s\n\n", outURL.path.fileSystemRepresentation );
			}
		} else {
			printf( "\n" );
			printf( "dry run completed.\n" );
			printf( "you must -confirm to overwrite the source file with these changes.\n\n" );
		}
	} else {
		printf( "no necessary changes were found.\n\n" );
	}

	// clean up
releaseDicts:
	[newIDDict release];
	newIDDict = nil;

	[oldIDDict release];
	oldIDDict = nil;

releaseXML:
	[xmlDocument release];
	xmlDocument = nil;
end:
	[autoreleasepool drain];
	autoreleasepool = nil;

    return returnValue;
}
