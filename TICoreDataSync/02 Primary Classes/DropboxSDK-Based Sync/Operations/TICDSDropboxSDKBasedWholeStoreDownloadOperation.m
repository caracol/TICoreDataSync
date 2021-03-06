//
//  TICDSDropboxSDKBasedWholeStoreDownloadOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//


#import "TICoreDataSync.h"

@interface TICDSDropboxSDKBasedWholeStoreDownloadOperation ()

/** A mutable dictionary to hold the last modified dates of each client identifier's whole store. */
@property (nonatomic, strong) NSMutableDictionary *wholeStoreModifiedDates;

@end

@implementation TICDSDropboxSDKBasedWholeStoreDownloadOperation

- (BOOL)needsMainThread
{
    return YES;
}

- (void)checkForMostRecentClientWholeStore
{
    [[self restClient] loadMetadata:[self thisDocumentWholeStoreDirectoryPath]];
}

- (void)sortOutWhichStoreIsNewest
{
    NSDate *mostRecentDate = nil;
    NSString *identifier = nil;
    for( NSString *eachIdentifier in [self wholeStoreModifiedDates] ) {
        NSDate *eachDate = [[self wholeStoreModifiedDates] valueForKey:eachIdentifier];
        
        if( [eachDate isKindOfClass:[NSNull class]] ) {
            continue;
        }
        
        if( !mostRecentDate ) {
            mostRecentDate = eachDate;
            identifier = eachIdentifier;
            continue;
        }
        
        if( [mostRecentDate compare:eachDate] == NSOrderedAscending ) {
            mostRecentDate = eachDate;
            identifier = eachIdentifier;
            continue;
        }
    }
    
    if( !identifier ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeNoPreviouslyUploadedStoreExists classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    [self determinedMostRecentWholeStoreWasUploadedByClientWithIdentifier:identifier];
}

- (void)downloadWholeStoreFile
{
    NSString *storeToDownload = [self pathToWholeStoreFileForClientWithIdentifier:[self requestedWholeStoreClientIdentifier]];
    
    [[self restClient] loadFile:storeToDownload intoPath:[[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSWholeStoreFilename]];
}

- (void)downloadAppliedSyncChangeSetsFile
{
    NSString *fileToDownload = [self pathToAppliedSyncChangesFileForClientWithIdentifier:[self requestedWholeStoreClientIdentifier]];
    
    [[self restClient] loadFile:fileToDownload intoPath:[[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSAppliedSyncChangeSetsFilename]];
}

- (void)fetchRemoteIntegrityKey
{
    NSString *directoryPath = [[self thisDocumentDirectoryPath] stringByAppendingPathComponent:TICDSIntegrityKeyDirectoryName];
    
    [[self restClient] loadMetadata:directoryPath];
}

#pragma mark - Rest Client Delegate
#pragma mark Metadata
- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
    NSString *path = [metadata path];
    
    if( [path isEqualToString:[self thisDocumentWholeStoreDirectoryPath]] ) {
        [self setWholeStoreModifiedDates:[NSMutableDictionary dictionaryWithCapacity:[[metadata contents] count]]];
        
        for( DBMetadata *eachSubMetadata in [metadata contents] ) {
            if( ![eachSubMetadata isDirectory] || [eachSubMetadata isDeleted] ) {
                continue;
            }
            
            _numberOfWholeStoresToCheck++;
        }
        
        if( _numberOfWholeStoresToCheck < 1 ) {
            [self sortOutWhichStoreIsNewest];
            return;
        }
        
        for( DBMetadata *eachSubMetadata in [metadata contents] ) {
            if( ![eachSubMetadata isDirectory] || [eachSubMetadata isDeleted] ) {
                continue;
            }
            
            [[self restClient] loadMetadata:[eachSubMetadata path]];
        }
        return;
    }
    
    if( [[path stringByDeletingLastPathComponent] isEqualToString:[self thisDocumentWholeStoreDirectoryPath]] ) {
        id modifiedDate = [NSNull null];
        for( DBMetadata *eachSubMetadata in [metadata contents] ) {
            if( [[[eachSubMetadata path] lastPathComponent] isEqualToString:TICDSWholeStoreFilename] ) {
                modifiedDate = [eachSubMetadata lastModifiedDate];
            }
        }
        
        [[self wholeStoreModifiedDates] setValue:modifiedDate forKey:[path lastPathComponent]];
        
        if( [[self wholeStoreModifiedDates] count] < _numberOfWholeStoresToCheck ) {
            return;
        }
        
        // if we get here, we've got all the modified dates (or NSNulls)
        [self sortOutWhichStoreIsNewest];
        return;
    }
    
    if( [[path lastPathComponent] isEqualToString:TICDSIntegrityKeyDirectoryName] ) {
        for( DBMetadata *eachSubMetadata in [metadata contents] ) {
            if( [[[eachSubMetadata path] lastPathComponent] length] < 5 ) {
                continue;
            }
            
            [self fetchedRemoteIntegrityKey:[[eachSubMetadata path] lastPathComponent]];
            return;
        }
        
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeUnexpectedOrIncompleteFileLocationOrDirectoryStructure classAndMethod:__PRETTY_FUNCTION__]];
        [self fetchedRemoteIntegrityKey:nil];
        return;
    }
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path
{
    
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error
{
    NSString *path = [[error userInfo] valueForKey:@"path"];
    NSInteger errorCode = [error code];
    
    if (errorCode == 503) {
        TICDSLog(TICDSLogVerbosityErrorsOnly, @"Encountered an error 503, retrying immediately. %@", path);
        [client loadMetadata:path];
        return;
    }
    
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
    
    if( [path isEqualToString:[self thisDocumentWholeStoreDirectoryPath]] ) {
        [self determinedMostRecentWholeStoreWasUploadedByClientWithIdentifier:nil];
        return;
    }
    
    if( [[path stringByDeletingLastPathComponent] isEqualToString:[self thisDocumentWholeStoreDirectoryPath]] ) {
        [[self wholeStoreModifiedDates] setValue:[NSNull null] forKey:[path lastPathComponent]];
        
        if( [[self wholeStoreModifiedDates] count] < _numberOfWholeStoresToCheck ) {
            return;
        }
        
        // if we get here, we've got all the dates (or NSNulls)
        [self sortOutWhichStoreIsNewest];
        return;
    }
    
    if( [[path lastPathComponent] isEqualToString:TICDSIntegrityKeyDirectoryName] ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
        [self fetchedRemoteIntegrityKey:nil];
        return;
    }
}

#pragma mark Loading Files
- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath
{
    NSError *anyError = nil;
    BOOL success = YES;
    
    if( [[destPath lastPathComponent] isEqualToString:TICDSWholeStoreFilename] ) {
        if( [self shouldUseEncryption] ) {
            success = [[self cryptor] decryptFileAtLocation:[NSURL fileURLWithPath:destPath] writingToLocation:[self localWholeStoreFileLocation] error:&anyError];
            
            if( !success ) {
                [self setError:[TICDSError errorWithCode:TICDSErrorCodeEncryptionError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
            }
        } else {
            success = [[self fileManager] moveItemAtPath:destPath toPath:[[self localWholeStoreFileLocation] path] error:&anyError];
            
            if( !success ) {
                [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
            }
        }
        [self downloadedWholeStoreFileWithSuccess:success];
        return;
    }
    
    if( [[destPath lastPathComponent] isEqualToString:TICDSAppliedSyncChangeSetsFilename] ) {
        success = [[self fileManager] moveItemAtPath:destPath toPath:[[self localAppliedSyncChangeSetsFileLocation] path] error:&anyError];
        
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        }
        
        [self downloadedAppliedSyncChangeSetsFileWithSuccess:success];
        return;
    }
}

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error
{
    NSString *path = [[error userInfo] valueForKey:@"path"];
    NSString *destinationPath = [[error userInfo] valueForKey:@"destinationPath"];
    NSInteger errorCode = error.code;
    
    if (errorCode == 503) { // Potentially bogus rate-limiting error code. Current advice from Dropbox is to retry immediately. --M.Fey, 2012-12-19
        TICDSLog(TICDSLogVerbosityErrorsOnly, @"Encountered an error 503, retrying immediately. %@", path);
        [client loadFile:path intoPath:destinationPath];
        return;
    }
    
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
    
    if( [[path lastPathComponent] isEqualToString:TICDSWholeStoreFilename] ) {
        [self downloadedWholeStoreFileWithSuccess:NO];
        return;
    }
    
    if( [[path lastPathComponent] isEqualToString:TICDSAppliedSyncChangeSetsFilename] ) {
        if( [error code] == 404 ) {
            [self setError:nil];
            [self downloadedAppliedSyncChangeSetsFileWithSuccess:YES];
        } else {
            [self downloadedAppliedSyncChangeSetsFileWithSuccess:NO];
        }
        return;
    }
}

#pragma mark - Paths
- (NSString *)pathToWholeStoreFileForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSWholeStoreFilename];
}

- (NSString *)pathToAppliedSyncChangesFileForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSAppliedSyncChangeSetsFilename];
}

#pragma mark - Initialization and Deallocation
- (void)dealloc
{
    [_restClient setDelegate:nil];

    _restClient = nil;
    _thisDocumentDirectoryPath = nil;
    _thisDocumentWholeStoreDirectoryPath = nil;

}

#pragma mark - Lazy Accessors
- (DBRestClient *)restClient
{
    if( _restClient ) return _restClient;
    
    _restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    [_restClient setDelegate:self];
    
    return _restClient;
}

#pragma mark - Properties
@synthesize thisDocumentDirectoryPath = _thisDocumentDirectoryPath;
@synthesize thisDocumentWholeStoreDirectoryPath = _thisDocumentWholeStoreDirectoryPath;
@synthesize wholeStoreModifiedDates = _wholeStoreModifiedDates;

@end

