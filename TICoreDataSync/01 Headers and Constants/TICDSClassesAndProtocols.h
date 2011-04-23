//
//  TICDSClassesAndProtocols.h
//  ShoppingListMac
//
//  Created by Tim Isted on 21/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#pragma mark -
#pragma mark PRIMARY CLASSES
@class TICDSApplicationSyncManager;
@class TICDSDocumentSyncManager;
@class TICDSSynchronizedManagedObjectContext;
@class TICDSSynchronizedManagedObject;

#pragma mark Operations
@class TICDSOperation;
@class TICDSApplicationRegistrationOperation;
@class TICDSDocumentRegistrationOperation;

#pragma mark File Manager-Based
@class TICDSFileManagerBasedApplicationSyncManager;
@class TICDSFileManagerBasedDocumentSyncManager;
@class TICDSFileManagerBasedApplicationRegistrationOperation;
@class TICDSFileManagerBasedDocumentRegistrationOperation;

#pragma mark -
#pragma mark INTERNAL DATA MODEL
@class TICDSSyncChange;

#pragma mark -
#pragma mark EXTERNAL CLASSES
@class TICoreDataFactory;

#pragma mark -
#pragma mark DELEGATE PROTOCOLS
#pragma mark Application Sync Manager
@protocol TICDSApplicationSyncManagerDelegate <NSObject>

@optional
// REGISTRATION PHASE
- (void)syncManagerDidStartRegistration:(TICDSApplicationSyncManager *)aSyncManager;
- (void)syncManager:(TICDSApplicationSyncManager *)aSyncManager encounteredRegistrationError:(NSError *)anError;
// end of registration
- (void)syncManagerFailedToRegister:(TICDSApplicationSyncManager *)aSyncManager;
- (void)syncManagerDidRegisterSuccessfully:(TICDSApplicationSyncManager *)aSyncManager;

@end

#pragma mark Document Sync Manager
@protocol TICDSDocumentSyncManagerDelegate <NSObject>

@optional
// REGISTRATION PHASE
- (void)syncManagerDidStartDocumentRegistration:(TICDSDocumentSyncManager *)aSyncManager;
- (void)syncManager:(TICDSDocumentSyncManager *)aSyncManager encounteredDocumentRegistrationError:(NSError *)anError;
// additional setup
@required
- (void)syncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseRegistrationAsRemoteFileStructureDoesNotExistForDocumentWithIdentifier:(NSString *)anIdentifier description:(NSString *)aDescription userInfo:(NSDictionary *)userInfo;
@optional
- (void)syncManagerDidResumeRegistration:(TICDSDocumentSyncManager *)aSyncManager;
// end of registration
- (void)syncManagerFailedToRegisterDocument:(TICDSDocumentSyncManager *)aSyncManager;
- (void)syncManagerDidRegisterDocumentSuccessfully:(TICDSDocumentSyncManager *)aSyncManager;

// HELPER FILE LOCATIONS
- (NSURL *)syncManager:(TICDSDocumentSyncManager *)aSyncManager helperFileDirectoryLocationForDocumentWithIdentifier:(NSString *)anIdentifier description:(NSString *)aDescription userInfo:(NSDictionary *)userInfo;

// MOC SAVING
- (void)syncManager:(TICDSDocumentSyncManager *)aSyncManager didBeginProcessingAfterMOCDidSave:(TICDSSynchronizedManagedObjectContext *)aMoc;
- (void)syncManager:(TICDSDocumentSyncManager *)aSyncManager failedToProcessAfterMOCDidSave:(TICDSSynchronizedManagedObjectContext *)aMoc;

@end

#pragma mark Operations
@protocol TICDSOperationDelegate <NSObject>

- (void)operationCompletedSuccessfully:(TICDSOperation *)anOperation;
- (void)operationWasCancelled:(TICDSOperation *)anOperation;
- (void)operationFailedToComplete:(TICDSOperation *)anOperation;

@end