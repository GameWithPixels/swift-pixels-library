/**
 * @file
 * @brief Library error codes and a few internal functions.
 */

#ifndef SGBleUtils_h
#define SGBleUtils_h

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

/**
 * @brief Peripheral got disconnected.
 * @ingroup Apple_Objective-C
 */
extern NSError *SGBleDisconnectedError;

/**
 * @brief Peripheral not in proper state to execute request.
 * @ingroup Apple_Objective-C
 */
extern NSError *SGBleInvalidCallError;

/**
 * @brief Peripheral request has some invalid parameters.
 * @ingroup Apple_Objective-C
 */
extern NSError *SGBleInvalidParametersError;

/**
 * @brief Peripheral request got canceled.
 * @ingroup Apple_Objective-C
 */
extern NSError *SGBleCanceledError;

//
// Internal
//

// Gets the serial queue used to run all BLE operations
dispatch_queue_t sgBleGetSerialQueue();

// Gets the error domain of the BLE library
NSErrorDomain sgBleGetErrorDomain();

#endif /* SGBleUtils_h */
