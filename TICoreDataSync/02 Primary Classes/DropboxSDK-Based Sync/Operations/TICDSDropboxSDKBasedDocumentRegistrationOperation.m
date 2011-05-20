//
//  TICDSDropboxSDKBasedDocumentRegistrationOperation.m
//  iOSNotebook
//
//  Created by Tim Isted on 14/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "TICDSDropboxSDKBasedDocumentRegistrationOperation.h"


@implementation TICDSDropboxSDKBasedDocumentRegistrationOperation

#pragma mark -
#pragma mark Helper Methods
- (void)createDirectoryContentsFromDictionary:(NSDictionary *)aDictionary inDirectory:(NSString *)aDirectoryPath
{
    for( NSString *eachName in [aDictionary allKeys] ) {
        
        id object = [aDictionary valueForKey:eachName];
        
        if( [object isKindOfClass:[NSDictionary class]] ) {
            NSString *thisPath = [aDirectoryPath stringByAppendingPathComponent:eachName];
            
            // create directory
            _numberOfDocumentDirectoriesToCreate++;
            
            [[self restClient] createFolder:thisPath];
            
            [self createDirectoryContentsFromDictionary:object inDirectory:thisPath];            
        }
    }
}

#pragma mark -
#pragma mark Overridden Document Methods
- (BOOL)needsMainThread
{
    return YES;
}

#pragma mark -
#pragma mark Document Directory
- (void)checkWhetherRemoteDocumentDirectoryExists
{
    [[self restClient] loadMetadata:[self thisDocumentDirectoryPath]];
}

- (void)createRemoteDocumentDirectoryStructure
{
    [self createDirectoryContentsFromDictionary:[TICDSUtilities remoteDocumentDirectoryHierarchy] inDirectory:[self thisDocumentDirectoryPath]];
}

- (void)checkForRemoteDocumentDirectoryCompletion
{
    if( _numberOfDocumentDirectoriesThatWereCreated == _numberOfDocumentDirectoriesToCreate ) {
        [self createdRemoteDocumentDirectoryStructureWithSuccess:YES];
        return;
    }
    
    if( _numberOfDocumentDirectoriesThatWereCreated + _numberOfDocumentDirectoriesThatFailedToBeCreated == _numberOfDocumentDirectoriesToCreate ) {
        [self createdRemoteDocumentDirectoryStructureWithSuccess:NO];
        return;
    }
}

#pragma mark documentInfo.plist
- (void)saveRemoteDocumentInfoPlistFromDictionary:(NSDictionary *)aDictionary
{
    BOOL success = YES;
    NSError *anyError = nil;
    
    NSString *finalFilePath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:TICDSDocumentInfoPlistFilenameWithExtension];
    
    if( [self shouldUseEncryption] ) {
        NSString *cryptFilePath = [finalFilePath stringByAppendingFormat:@"tmp"];
        
        success = [aDictionary writeToFile:cryptFilePath atomically:NO];
        
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError classAndMethod:__PRETTY_FUNCTION__]];
            [self savedRemoteDocumentInfoPlistWithSuccess:NO];
            return;
        }
        
        success = [[self cryptor] encryptFileAtLocation:[NSURL fileURLWithPath:cryptFilePath] writingToLocation:[NSURL fileURLWithPath:finalFilePath] error:&anyError];
        
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeEncryptionError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        }
    } else {
        success = [aDictionary writeToFile:finalFilePath atomically:NO];
        
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError classAndMethod:__PRETTY_FUNCTION__]];
        }
    }
    
    if( !success ) {
        [self savedRemoteDocumentInfoPlistWithSuccess:NO];
        return;
    }
    
    [[self restClient] uploadFile:TICDSDocumentInfoPlistFilenameWithExtension toPath:[self thisDocumentDirectoryPath] fromPath:finalFilePath];
}

#pragma mark -
#pragma mark Client Directories
- (void)checkWhetherClientDirectoryExistsInRemoteDocumentSyncChangesDirectory
{
    [[self restClient] loadMetadata:[self thisDocumentSyncChangesThisClientDirectoryPath]];
}

- (void)createClientDirectoriesInRemoteDocumentDirectories
{
    [[self restClient] createFolder:[self thisDocumentSyncChangesThisClientDirectoryPath]];
    [[self restClient] createFolder:[self thisDocumentSyncCommandsThisClientDirectoryPath]];
}

- (void)checkForThisDocumentClientDirectoryCompletion
{
    if( _completedThisDocumentSyncChangesThisClientDirectory && _completedThisDocumentSyncChangesThisClientDirectory && (_errorCreatingThisDocumentSyncChangesThisClientDirectory || _errorCreatingThisDocumentSyncCommandsThisClientDirectory) ) {
        [self createdClientDirectoriesInRemoteDocumentDirectoriesWithSuccess:NO];
    }
    
    if( _completedThisDocumentSyncChangesThisClientDirectory && _completedThisDocumentSyncCommandsThisClientDirectory ) {
        [self createdClientDirectoriesInRemoteDocumentDirectoriesWithSuccess:YES];
    }
}

#pragma mark -
#pragma mark Rest Client Delegate
#pragma mark Metadata
- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
    NSString *path = [metadata path];
    TICDSRemoteFileStructureExistsResponseType status = [metadata isDeleted] ? TICDSRemoteFileStructureExistsResponseTypeDoesNotExist : TICDSRemoteFileStructureExistsResponseTypeDoesExist;
    
    if( [path isEqualToString:[self thisDocumentDirectoryPath]] ) {
        [self discoveredStatusOfRemoteDocumentDirectory:status];
        return;
    }
    
    if( [path isEqualToString:[self thisDocumentSyncChangesThisClientDirectoryPath]] ) {
        [self discoveredStatusOfClientDirectoryInRemoteDocumentSyncChangesDirectory:status];
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
    TICDSRemoteFileStructureExistsResponseType status = TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
    
    if( errorCode != 404 ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
        status = TICDSRemoteFileStructureExistsResponseTypeError;
    }
    
    if( [path isEqualToString:[self thisDocumentDirectoryPath]] ) {
        [self discoveredStatusOfRemoteDocumentDirectory:status];
        return;
    }
    
    if( [path isEqualToString:[self thisDocumentSyncChangesThisClientDirectoryPath]] ) {
        [self discoveredStatusOfClientDirectoryInRemoteDocumentSyncChangesDirectory:status];
        return;
    }
}

#pragma mark Directories
- (void)restClient:(DBRestClient *)client createdFolder:(DBMetadata *)folder
{
    NSString *path = [folder path];
    
    if( [path isEqualToString:[self thisDocumentSyncChangesThisClientDirectoryPath]] ) {
        _completedThisDocumentSyncChangesThisClientDirectory = YES;
        [self checkForThisDocumentClientDirectoryCompletion];
        return;
    }
    
    if( [path isEqualToString:[self thisDocumentSyncCommandsThisClientDirectoryPath]] ) {
        _completedThisDocumentSyncCommandsThisClientDirectory = YES;
        [self checkForThisDocumentClientDirectoryCompletion];
        return;
    }
    
    // if we get here, it's part of the document directory hierarchy
    _numberOfDocumentDirectoriesThatWereCreated++;
    [self checkForRemoteDocumentDirectoryCompletion];
}

- (void)restClient:(DBRestClient *)client createFolderFailedWithError:(NSError *)error
{
    NSString *path = [[error userInfo] valueForKey:@"path"];
    
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
    
    if( [path isEqualToString:[self thisDocumentSyncChangesThisClientDirectoryPath]] ) {
        _completedThisDocumentSyncChangesThisClientDirectory = YES;
        _errorCreatingThisDocumentSyncChangesThisClientDirectory = YES;
        [self checkForThisDocumentClientDirectoryCompletion];
        return;
    }
    
    if( [path isEqualToString:[self thisDocumentSyncCommandsThisClientDirectoryPath]] ) {
        _completedThisDocumentSyncCommandsThisClientDirectory = YES;
        _errorCreatingThisDocumentSyncCommandsThisClientDirectory = YES;
        [self checkForThisDocumentClientDirectoryCompletion];
        return;
    }
    
    // if we get here, it's part of the document directory hierarchy
    _numberOfDocumentDirectoriesThatFailedToBeCreated++;
    [self checkForRemoteDocumentDirectoryCompletion];
}

#pragma mark Uploads
- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath
{
    if( [[destPath stringByDeletingLastPathComponent] isEqualToString:[self thisDocumentDirectoryPath]] ) {
        [self savedRemoteDocumentInfoPlistWithSuccess:YES];
        return;
    }
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
    NSString *path = [[error userInfo] valueForKey:@"path"];
    
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeDropboxSDKRestClientError underlyingError:error classAndMethod:__PRETTY_FUNCTION__]];
    
    if( [[path stringByDeletingLastPathComponent] isEqualToString:[self thisDocumentDirectoryPath]] ) {
        [self savedRemoteDocumentInfoPlistWithSuccess:NO];
        return;
    }
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    [_dbSession release], _dbSession = nil;
    [_restClient release], _restClient = nil;
    [_documentsDirectoryPath release], _documentsDirectoryPath = nil;
    [_thisDocumentDirectoryPath release], _thisDocumentDirectoryPath = nil;
    [_thisDocumentSyncChangesThisClientDirectoryPath release], _thisDocumentSyncChangesThisClientDirectoryPath = nil;
    [_thisDocumentSyncCommandsThisClientDirectoryPath release], _thisDocumentSyncCommandsThisClientDirectoryPath = nil;
    
    [super dealloc];
}

#pragma mark -
#pragma mark Lazy Accessors
- (DBRestClient *)restClient
{
    if( _restClient ) return _restClient;
    
    _restClient = [[DBRestClient alloc] initWithSession:[self dbSession]];
    [_restClient setDelegate:self];
    
    return _restClient;
}

#pragma mark -
#pragma mark Properties
@synthesize dbSession = _dbSession;
@synthesize restClient = _restClient;
@synthesize documentsDirectoryPath = _documentsDirectoryPath;
@synthesize thisDocumentDirectoryPath = _thisDocumentDirectoryPath;
@synthesize thisDocumentSyncChangesThisClientDirectoryPath = _thisDocumentSyncChangesThisClientDirectoryPath;
@synthesize thisDocumentSyncCommandsThisClientDirectoryPath = _thisDocumentSyncCommandsThisClientDirectoryPath;

@end

#endif