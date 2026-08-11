//
// Copyright 2017 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#define LOG_TAG "android.hardware.bluetooth@1.1-service.btlinux"

#include <android/hardware/bluetooth/1.1/IBluetoothHci.h>
#include <errno.h>
#include <fcntl.h>
#include <hidl/HidlSupport.h>
#include <hidl/HidlTransportSupport.h>
#include <sched.h>
#include <string.h>
#include <unistd.h>
#include <utils/Log.h>

#include "bluetooth_hci.h"

using ::android::sp;
using ::android::hardware::configureRpcThreadpool;
using ::android::hardware::joinRpcThreadpool;
using ::android::hardware::bluetooth::V1_1::IBluetoothHci;
using ::android::hardware::bluetooth::V1_1::btlinux::BluetoothHci;

namespace {

constexpr char kHostNetworkNamespace[] = "/redroid-host-netns";

bool EnterHostNetworkNamespace() {
  const int fd = open(kHostNetworkNamespace, O_RDONLY | O_CLOEXEC);
  if (fd < 0) {
    ALOGE("Cannot open %s: %s", kHostNetworkNamespace, strerror(errno));
    return false;
  }

  if (setns(fd, CLONE_NEWNET) < 0) {
    ALOGE("Cannot enter host network namespace: %s", strerror(errno));
    close(fd);
    return false;
  }

  close(fd);
  ALOGI("Entered host network namespace");
  return true;
}

}  // namespace

int main(int /* argc */, char** /* argv */) {
  if (!EnterHostNetworkNamespace()) return 1;

  sp<IBluetoothHci> bluetooth = new BluetoothHci;
  configureRpcThreadpool(1, true);
  android::status_t status = bluetooth->registerAsService();
  if (status == android::OK)
    joinRpcThreadpool();
  else
    ALOGE("Could not register as a service!");
  return status == android::OK ? 0 : 1;
}
