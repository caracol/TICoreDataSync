//
//  TICDSSynchronizedManagedObject.m
//  ShoppingListMac
//
//  Created by Tim Isted on 23/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICoreDataSync.h"


@implementation TICDSSynchronizedManagedObject

#pragma mark -
#pragma mark Sync Change Creation
- (void)createSyncChangeForInsertion
{
     
}

- (void)createSyncChangeForDeletion
{
    
}

- (void)createSyncChangesForChangedProperties
{
    
}

#pragma mark -
#pragma mark Save Notification
- (void)willSave
{
    [super willSave];
    
    // if not in a synchronized MOC, or we don't have a doc sync manager, exit now
    if( ![[self managedObjectContext] isKindOfClass:[TICDSSynchronizedManagedObjectContext class]] || ![(TICDSSynchronizedManagedObjectContext *)[self managedObjectContext] documentSyncManager] ) {
        return;
    }
    
    if( [self isInserted] ) {
        [self createSyncChangeForInsertion];
    }
    
    if( [self isDeleted] ) {
        [self createSyncChangeForDeletion];
    }
    
    if( [self isUpdated] ) {
        [self createSyncChangesForChangedProperties];
    }
}

#pragma mark -
#pragma mark Managed Object Lifecycle
- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setValue:[TICDSUtilities uuidString] forKey:TICDSSyncIDAttributeName];
}

#pragma mark -
#pragma mark Properties
- (NSManagedObjectContext *)syncChangesMOC
{
    if( ![[self managedObjectContext] isKindOfClass:[TICDSSynchronizedManagedObjectContext class]] ) return nil;
    
    return [[(TICDSSynchronizedManagedObjectContext *)[self managedObjectContext] documentSyncManager] syncChangesMOC];
}

@end