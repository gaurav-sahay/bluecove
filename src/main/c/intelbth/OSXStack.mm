/**
 *  BlueCove - Java library for Bluetooth
 *  Copyright (C) 2007 Vlad Skarzhevskyy
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *  @version $Id$
 */

#include "OSXStack.h"
#include <pthread.h>

#define CPP_FILE "OSXStack.cpp"

OSXStack* stack = NULL;

OSXStack::OSXStack() {
    deviceInquiryInProcess = FALSE;
    deviceInquiryTerminated = FALSE;
    pthread_mutex_init(&deviceInquiryInProcessMutex, NULL);
    MPCreateEvent(&deviceInquiryNotificationEvent);
    MPCreateEvent(&deviceInquiryFinishedEvent);

    commPool = new ObjectPool(100, 1, TRUE);
}

OSXStack::~OSXStack() {
    if (commPool != NULL) {
		delete commPool;
		commPool = NULL;
	}
    MPSetEvent(deviceInquiryNotificationEvent, 0);
    MPDeleteEvent(deviceInquiryNotificationEvent);
    MPDeleteEvent(deviceInquiryFinishedEvent);
    pthread_mutex_destroy(&deviceInquiryInProcessMutex);
}

BOOL OSXStack::deviceInquiryLock(JNIEnv* env) {
    if (deviceInquiryInProcess && deviceInquiryTerminated) {
        // Wait until it terminates
        MPEventFlags flags;
        MPWaitForEvent(deviceInquiryFinishedEvent, &flags, kDurationMillisecond * 1000 * 3);
    }

    if (deviceInquiryInProcess) {
	    throwBluetoothStateException(env, cINQUIRY_RUNNING);
	    return false;
	}
	if (pthread_mutex_trylock(&deviceInquiryInProcessMutex) != 0) {
	    throwBluetoothStateException(env, cINQUIRY_RUNNING);
	    return false;
	}
	stack->deviceInquiryInProcess = true;
	return true;
}

BOOL OSXStack::deviceInquiryUnlock() {
    deviceInquiryInProcess = false;
    BOOL rc = (pthread_mutex_unlock(&deviceInquiryInProcessMutex) == 0);
    MPSetEvent(deviceInquiryFinishedEvent, 0);
    return rc;
}

Runnable::Runnable() {
    magic1b = MAGIC_1;
	magic2b = MAGIC_2;
	magic1e = MAGIC_1;
	magic2e = MAGIC_2;

    name = "n/a";
    sData[0] = '\0';
    error = 0;
    lData = 0;
    bData = false;
    for (int i = 0; i < RUNNABLE_DATA_MAX; i++) {
		pData[i] = NULL;
	}
}

Runnable::~Runnable() {
	magic1b = 0;
	magic2b = 0;
	magic1e = 0;
	magic2e = 0;
}

BOOL isRunnableCorrupted(Runnable* r) {
    return ((r == NULL) || (r->magic1b != MAGIC_1) || (r->magic2b != MAGIC_2) || (r->magic1e != MAGIC_1) || (r->magic2e != MAGIC_2));
}

// --- One Native Thread and RunLoop, An issue with the OS X BT implementation is all the calls need to come from the same thread.

CFRunLoopRef			mainRunLoop;
CFRunLoopSourceRef		btOperationSource;

typedef struct BTOperationParams {
	Runnable* runnable;
};

void *oneNativeThreadMain(void *initializeCond);

void performBTOperationCallBack(void *info);
pthread_mutex_t	btOperationInProgress;
MPEventID synchronousBTOperationCallComplete;

JavaVM *s_vm;

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {

    pthread_t thread;
	pthread_mutex_t initializeMutex;
	pthread_cond_t  initializeCond;

	pthread_cond_init(&initializeCond, NULL);
	pthread_mutex_init(&initializeMutex, NULL);

	pthread_mutex_lock(&initializeMutex);
	s_vm = vm;
	// Starting the OS X init and run thread
	pthread_create(&thread, NULL, oneNativeThreadMain, (void*) &initializeCond);
	// wait until the OS X thread has initialized before returning
	pthread_cond_wait(&initializeCond, &initializeMutex);

	// clean up
	pthread_cond_destroy(&initializeCond);
	pthread_mutex_unlock(&initializeMutex);
	pthread_mutex_destroy(&initializeMutex);

    return JNI_VERSION_1_2;
}

void *oneNativeThreadMain(void *initializeCond) {

    JavaVMAttachArgs args;
    args.version = JNI_VERSION_1_2;
	args.name = "OS X Bluetooth CFRunLoop";
	args.group = NULL;
	JNIEnv	*env;
	s_vm->AttachCurrentThreadAsDaemon((void**)&env, &args);

    // setup OS X managed memory environment
    NSAutoreleasePool *autoreleasepool = [[NSAutoreleasePool alloc] init];

    mainRunLoop = CFRunLoopGetCurrent();

    pthread_mutex_init(&btOperationInProgress, NULL);
    MPCreateEvent(&synchronousBTOperationCallComplete);

    // create event sources, i.e. requests from the java VM
    CFRunLoopSourceContext context = {0};
    BTOperationParams params = {0};
    // An arbitrary pointer to program-defined data, which can be associated with the CFRunLoopSource at creation time. This pointer is passed to callbacks.
    context.info = &params;
	context.perform = performBTOperationCallBack;
	btOperationSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
	CFRunLoopAddSource(mainRunLoop, btOperationSource, kCFRunLoopDefaultMode);

    // Init complete, releasing the library load thread
    pthread_cond_signal((pthread_cond_t*)initializeCond);

    ndebug("Starting the CFRunLoop");
	// Starting the CFRunLoop
	CFRunLoopRun();
	// should only reach this point when getting unloaded
	pthread_mutex_destroy(&btOperationInProgress);
	MPSetEvent(synchronousBTOperationCallComplete, 0);
    MPDeleteEvent(synchronousBTOperationCallComplete);

	[autoreleasepool release];
	return NULL;
}

void performBTOperationCallBack(void *info) {
    BTOperationParams* params = (BTOperationParams*)info;
    if (params->runnable != NULL) {
        if (isRunnableCorrupted(params->runnable)) {
            ndebug("Error: execute BTOperation got corrupted runnable");
        } else {
            ndebug(" execute  BTOperation %s", params->runnable->name);
            params->runnable->run();
            ndebug(" finished BTOperation %s", params->runnable->name);
        }
    }
    MPSetEvent(synchronousBTOperationCallComplete, 1);
}

void synchronousBTOperation(Runnable* runnable) {

    pthread_mutex_lock(&btOperationInProgress);

	CFRunLoopSourceContext	context={0};
	CFRunLoopSourceGetContext(btOperationSource, &context);
	BTOperationParams* params = (BTOperationParams*)context.info;
	params->runnable = runnable;

    ndebug("invoke    BTOperation %s", params->runnable->name);
	CFRunLoopSourceSignal(btOperationSource);
	CFRunLoopWakeUp(mainRunLoop);

	MPEventFlags flags;
    MPWaitForEvent(synchronousBTOperationCallComplete, &flags, kDurationForever);

	pthread_mutex_unlock(&btOperationInProgress);
	ndebug("return    BTOperation %s", params->runnable->name);
}

void ndebug(const char *fmt, ...) {
	va_list ap;
	va_start(ap, fmt);
	if (nativeDebugCallbackEnabled) {
	    fprintf(stdout, "NATIVE:");
        vfprintf(stdout, fmt, ap);
        fprintf(stdout, "\n");
        fflush(stdout);
    }
    va_end(ap);
}

// --- Helper functions

OSXJNIHelper::OSXJNIHelper() {
    autoreleasepool = [[NSAutoreleasePool alloc] init];
}

OSXJNIHelper::~OSXJNIHelper() {
    [autoreleasepool release];
}

jstring OSxNewJString(JNIEnv *env, NSString *nString) {
    jsize buflength = [nString length];
    unichar buffer[buflength];
    [nString getCharacters:buffer];
    return env->NewString((jchar *)buffer, buflength);
}

void OSxAddrToString(char* addressString, const BluetoothDeviceAddress* addr) {
	snprintf(addressString, 14, "%02x%02x%02x%02x%02x%02x",
			 addr->data[0],
             addr->data[1],
             addr->data[2],
             addr->data[3],
             addr->data[4],
             addr->data[5]);
}

jlong OSxAddrToLong(const BluetoothDeviceAddress* addr) {
	jlong l = 0;
	for (int i = 0; i < 6; i++) {
		l = (l << 8) + addr->data[i];
	}
	return l;
}

void LongToOSxBTAddr(jlong longAddr, BluetoothDeviceAddress* addr) {
	for (int i = 6 - 1; i >= 0; i--) {
		addr->data[i] = (UInt8)(longAddr & 0xFF);
		longAddr >>= 8;
	}
}

// --- JNI function

JNIEXPORT jint JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getLibraryVersion
(JNIEnv *, jobject) {
	return blueCoveVersion();
}

JNIEXPORT jint JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_detectBluetoothStack
(JNIEnv *env, jobject) {
	return BLUECOVE_STACK_DETECT_OSX;
}

JNIEXPORT void JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_enableNativeDebug
(JNIEnv *env, jobject, jclass loggerClass, jboolean on) {
	enableNativeDebug(env, loggerClass, on);
}

JNIEXPORT jboolean JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_initializeImpl
(JNIEnv *env, jobject) {
    stack = new OSXStack();
	return JNI_TRUE;
}

JNIEXPORT void JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_destroyImpl
(JNIEnv *env, jobject) {
    if (stack != NULL) {
		OSXStack* stackTmp = stack;
		stack = NULL;
		delete stackTmp;
	}
}

// --- LocalDevice

RUNNABLE(GetLocalDeviceBluetoothAddress, "GetLocalDeviceBluetoothAddress") {
    if (!IOBluetoothLocalDeviceAvailable()) {
		error = 1;
		return;
    }
    BluetoothDeviceAddress localAddress;
    if (IOBluetoothLocalDeviceReadAddress(&localAddress, NULL, NULL, NULL)) {
        error = 2;
		return;
    }
    OSxAddrToString(sData, &localAddress);
}

JNIEXPORT jstring JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getLocalDeviceBluetoothAddress
(JNIEnv *env, jobject) {
    Edebug("getLocalDeviceBluetoothAddress");
    GetLocalDeviceBluetoothAddress runnable;
    synchronousBTOperation(&runnable);
    switch (runnable.error) {
        case 1:
            throwBluetoothStateException(env, "Bluetooth Device is not available");
		    return NULL;
        case 2:
            throwBluetoothStateException(env, "Bluetooth Device is not ready");
	        return NULL;
    }
    return env->NewStringUTF(runnable.sData);
}

RUNNABLE(GetLocalDeviceName, "GetLocalDeviceName") {
    BluetoothDeviceName localName;
    if (IOBluetoothLocalDeviceReadName(localName, NULL, NULL, NULL)) {
		error = 1;
    } else {
        strncpy(sData, (char*)localName, RUNNABLE_DATA_MAX);
    }
}

JNIEXPORT jstring JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getLocalDeviceName
(JNIEnv *env, jobject) {
    Edebug("getLocalDeviceName");
    GetLocalDeviceName runnable;
    synchronousBTOperation(&runnable);
    if (runnable.error) {
        return NULL;
    }
    return env->NewStringUTF(runnable.sData);
}

RUNNABLE(GetDeviceClass, "GetDeviceClass") {
    BluetoothClassOfDevice cod;
    if (IOBluetoothLocalDeviceReadClassOfDevice(&cod, NULL, NULL, NULL)) {
        error = 1;
    } else {
        lData = cod;
    }
}

JNIEXPORT jint JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getDeviceClassImpl
(JNIEnv *env, jobject) {
    Edebug("getDeviceClassImpl");
    GetDeviceClass runnable;
    synchronousBTOperation(&runnable);
    return (jint)runnable.lData;
}

RUNNABLE(IsLocalDevicePowerOn, "IsLocalDevicePowerOn") {
    if (!IOBluetoothLocalDeviceAvailable()) {
        error = 1;
        bData = false;
        return;
    }
    BluetoothHCIPowerState powerState;
    if (IOBluetoothLocalDeviceGetPowerState(&powerState)) {
        error = 2;
        bData = false;
        return;
    }
    bData = (powerState == kBluetoothHCIPowerStateON)?true:false;
}

JNIEXPORT jboolean JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_isLocalDevicePowerOn
(JNIEnv *env, jobject) {
    Edebug("isLocalDevicePowerOn");
    IsLocalDevicePowerOn runnable;
    synchronousBTOperation(&runnable);
    return (runnable.bData)?JNI_TRUE:JNI_FALSE;
}

RUNNABLE(IsLocalDeviceDiscoverable, "IsLocalDeviceDiscoverable") {
    if (!IOBluetoothLocalDeviceAvailable()) {
        error = 1;
        bData = false;
        return;
    }
    Boolean discoverableStatus;
    if (IOBluetoothLocalDeviceGetDiscoverable(&discoverableStatus)) {
        error = 1;
        bData = false;
        return;
    }
    bData = discoverableStatus;
}

JNIEXPORT jboolean JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getLocalDeviceDiscoverableImpl
(JNIEnv *env, jobject) {
    Edebug("getLocalDeviceDiscoverableImpl");
    IsLocalDeviceDiscoverable runnable;
    synchronousBTOperation(&runnable);
    return (runnable.bData)?JNI_TRUE:JNI_FALSE;
}

RUNNABLE(GetBluetoothHCISupportedFeatures, "GetBluetoothHCISupportedFeatures") {
    BluetoothHCISupportedFeatures features;
    if (IOBluetoothLocalDeviceReadSupportedFeatures(&features, NULL, NULL, NULL)) {
        error = 1;
        return;
    }
    lData = features.data[iData];
}

JNIEXPORT jboolean JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_isLocalDeviceFeatureSwitchRoles
(JNIEnv *env, jobject) {
    Edebug("isLocalDeviceFeatureSwitchRoles");
    GetBluetoothHCISupportedFeatures runnable;
    runnable.iData = 7;
    synchronousBTOperation(&runnable);
    if (runnable.error) {
        return JNI_FALSE;
    }
    return (kBluetoothFeatureSwitchRoles & runnable.lData)?JNI_TRUE:JNI_FALSE;
}

JNIEXPORT jboolean JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_isLocalDeviceFeatureParkMode
(JNIEnv *env, jobject) {
    Edebug("isLocalDeviceFeatureParkMode");
    GetBluetoothHCISupportedFeatures runnable;
    runnable.iData = 6;
    synchronousBTOperation(&runnable);
    if (runnable.error) {
        return JNI_FALSE;
    }
    return (kBluetoothFeatureParkMode & runnable.lData)?JNI_TRUE:JNI_FALSE;
}

JNIEXPORT jint JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getLocalDeviceL2CAPMTUMaximum
(JNIEnv *env, jobject) {
    return (jint)kBluetoothL2CAPMTUMaximum;
}

RUNNABLE(GetLocalDeviceVersion, "GetLocalDeviceVersion") {
    NumVersion* btVersion = (NumVersion*)pData[0];
    BluetoothHCIVersionInfo* hciVersion = (BluetoothHCIVersionInfo*)pData[1];
    if (IOBluetoothGetVersion(btVersion, hciVersion)) {
        error = 1;
    }
}

JNIEXPORT jstring JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getLocalDeviceSoftwareVersionInfo
(JNIEnv *env, jobject) {
    Edebug("getLocalDeviceSoftwareVersionInfo");
    NumVersion btVersion;
	char swVers[133];
    GetLocalDeviceVersion runnable;
    runnable.pData[0] = &btVersion;
    synchronousBTOperation(&runnable);
    if (runnable.error) {
        return NULL;
    }

	snprintf(swVers, 133, "%1d%1d.%1d.%1d rev %d", btVersion.majorRev >> 4, btVersion.majorRev & 0x0F,
	                      btVersion.minorAndBugRev >> 4, btVersion.minorAndBugRev & 0x0F, btVersion.nonRelRev);
    return env->NewStringUTF(swVers);
}

JNIEXPORT jint JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getLocalDeviceManufacturer
(JNIEnv *env, jobject) {
    Edebug("getLocalDeviceManufacturer");
    BluetoothHCIVersionInfo	hciVersion;
	GetLocalDeviceVersion runnable;
    runnable.pData[1] = &hciVersion;
    synchronousBTOperation(&runnable);
    if (runnable.error) {
        return 0;
    }
	return hciVersion.manufacturerName;
}

JNIEXPORT jstring JNICALL Java_com_intel_bluetooth_BluetoothStackOSX_getLocalDeviceVersion
(JNIEnv *env, jobject) {
    Edebug("getLocalDeviceVersion");
    BluetoothHCIVersionInfo	hciVersion;
	GetLocalDeviceVersion runnable;
    runnable.pData[1] = &hciVersion;
    synchronousBTOperation(&runnable);
    if (runnable.error) {
        return 0;
    }
    char swVers[133];
    snprintf(swVers, 133, "LMP Version: %d.%d, HCI Version: %d.%d", hciVersion.lmpVersion, hciVersion.lmpSubVersion,
                          hciVersion.hciVersion, hciVersion.hciRevision);
    return env->NewStringUTF(swVers);
}