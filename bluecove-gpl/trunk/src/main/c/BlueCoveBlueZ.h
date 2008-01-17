/**
 * BlueCove BlueZ module - Java library for Bluetooth on Linux
 *  Copyright (C) 2008 Mina Shokry
 *  Copyright (C) 2007 Vlad Skarzhevskyy
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author: mina
 * Created on December 24, 2007, 4:17 PM
 *
 * @version $Id$
 */

#ifndef _BLUECOVEBLUEZ_H
#define	_BLUECOVEBLUEZ_H

#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>
#include <bluetooth/sdp.h>
#include <bluetooth/sdp_lib.h>
#include <jni.h>

#include "com_intel_bluetooth_BluetoothStackBlueZ.h"
#include "com_intel_bluetooth_BluetoothStackBlueZConsts.h"
#include "common.h"

const int TIMEOUT=5000;
const int DEVICE_NAME_MAX_SIZE=248;

int deviceClassBytesToInt(uint8_t* deviceClass);

jlong deviceAddrToLong(bdaddr_t* address);
void longToDeviceAddr(jlong addr, bdaddr_t* address);

void populateServiceRecord(JNIEnv* env,jobject serviceRecrod,sdp_record_t* sdpRecord,sdp_list_t* attributeList);
jobject createDataElement(JNIEnv* env,sdp_data_t* data);
void reverseArray(jbyte* array,int length);
uuid_t getUuidFromJavaUUID(JNIEnv *env,jobject javaUUID);
jobject createJavaUUID(JNIEnv *env,uuid_t uuid);

#define INQUIRY_COMPLETED  com_intel_bluetooth_BluetoothStackBlueZConsts_INQUIRY_COMPLETED
#define INQUIRY_TERMINATED com_intel_bluetooth_BluetoothStackBlueZConsts_INQUIRY_TERMINATED
#define INQUIRY_ERROR      com_intel_bluetooth_BluetoothStackBlueZConsts_INQUIRY_ERROR

#define SERVICE_SEARCH_COMPLETED            com_intel_bluetooth_BluetoothStackBlueZConsts_SERVICE_SEARCH_COMPLETED
#define SERVICE_SEARCH_TERMINATED           com_intel_bluetooth_BluetoothStackBlueZConsts_SERVICE_SEARCH_TERMINATED
#define SERVICE_SEARCH_ERROR                com_intel_bluetooth_BluetoothStackBlueZConsts_SERVICE_SEARCH_ERROR
#define SERVICE_SEARCH_NO_RECORDS           com_intel_bluetooth_BluetoothStackBlueZConsts_SERVICE_SEARCH_NO_RECORDS
#define SERVICE_SEARCH_DEVICE_NOT_REACHABLE com_intel_bluetooth_BluetoothStackBlueZConsts_SERVICE_SEARCH_DEVICE_NOT_REACHABLE

#define DATA_ELEMENT_TYPE_NULL     com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_NULL
#define DATA_ELEMENT_TYPE_U_INT_1  com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_U_INT_1
#define DATA_ELEMENT_TYPE_U_INT_2  com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_U_INT_2
#define DATA_ELEMENT_TYPE_U_INT_4  com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_U_INT_4
#define DATA_ELEMENT_TYPE_U_INT_8  com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_U_INT_8
#define DATA_ELEMENT_TYPE_U_INT_16 com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_U_INT_16
#define DATA_ELEMENT_TYPE_INT_1    com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_INT_1
#define DATA_ELEMENT_TYPE_INT_2    com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_INT_2
#define DATA_ELEMENT_TYPE_INT_4    com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_INT_4
#define DATA_ELEMENT_TYPE_INT_8    com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_INT_8
#define DATA_ELEMENT_TYPE_INT_16   com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_INT_8
#define DATA_ELEMENT_TYPE_URL      com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_URL
#define DATA_ELEMENT_TYPE_UUID     com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_UUID
#define DATA_ELEMENT_TYPE_BOOL     com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_BOOL
#define DATA_ELEMENT_TYPE_STRING   com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_STRING
#define DATA_ELEMENT_TYPE_DATSEQ   com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_DATSEQ
#define DATA_ELEMENT_TYPE_DATALT   com_intel_bluetooth_BluetoothStackBlueZConsts_DataElement_DATALT

#define BT_CONNECTION_ERROR_UNKNOWN_PSM         com_intel_bluetooth_BluetoothStackBlueZConsts_CONNECTION_ERROR_UNKNOWN_PSM
#define BT_CONNECTION_ERROR_SECURITY_BLOCK      com_intel_bluetooth_BluetoothStackBlueZConsts_CONNECTION_ERROR_SECURITY_BLOCK
#define BT_CONNECTION_ERROR_NO_RESOURCES        com_intel_bluetooth_BluetoothStackBlueZConsts_CONNECTION_ERROR_NO_RESOURCES
#define BT_CONNECTION_ERROR_FAILED_NOINFO       com_intel_bluetooth_BluetoothStackBlueZConsts_CONNECTION_ERROR_FAILED_NOINFO
#define BT_CONNECTION_ERROR_TIMEOUT             com_intel_bluetooth_BluetoothStackBlueZConsts_CONNECTION_ERROR_TIMEOUT
#define BT_CONNECTION_ERROR_UNACCEPTABLE_PARAMS com_intel_bluetooth_BluetoothStackBlueZConsts_CONNECTION_ERROR_UNACCEPTABLE_PARAMS

#endif	/* _BLUECOVEBLUEZ_H */
