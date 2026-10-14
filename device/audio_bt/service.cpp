/*
 * SPDX-FileCopyrightText: The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

// Registers the AOSP Bluetooth audio provider factory and the AOSP Bluetooth audio module
// (IModule/a2dp) in the same process, like AOSP's audio services do
// (hardware/interfaces/audio/common/all-versions/default/service/service.cpp:136-140, 162-167
// and audio/aidl/default/main.cpp). See docs/BT_AUDIO_1001.md.

#include <cstdlib>
#include <string>

#define LOG_TAG "AHAL_EssiBt"
#include <android-base/logging.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include "core-impl/ChildInterface.h"
#include "core-impl/Configuration.h"
#include "core-impl/Module.h"

using aidl::android::hardware::audio::core::ChildInterface;
using aidl::android::hardware::audio::core::Module;

// Exported by android.hardware.bluetooth.audio-impl
// (hardware/interfaces/bluetooth/audio/aidl/default/service.cpp:28-38).
extern "C" binder_status_t createIBluetoothAudioProviderFactory();

int main() {
    ABinderProcess_setThreadPoolMaxThreadCount(16);
    ABinderProcess_startThreadPool();

    if (binder_status_t status = createIBluetoothAudioProviderFactory(); status != STATUS_OK) {
        LOG(ERROR) << "createIBluetoothAudioProviderFactory failed: " << status;
    }

    // Module::createInstance(type) alone would pass an empty configuration
    // (include/core-impl/Module.h:51-53), so pass the built-in Bluetooth one.
    ChildInterface<Module> module;
    module = Module::createInstance(
            Module::Type::BLUETOOTH,
            aidl::android::hardware::audio::core::internal::getConfiguration(
                    Module::Type::BLUETOOTH));
    // "a2dp", not "bluetooth": Samsung's audio HAL already registers IModule/bluetooth, and
    // audioserver orders "a2dp" before "bluetooth" (libaudiohal DevicesFactoryHalAidl.cpp:163-165),
    // so the policy finds A2DP devices in this module first.
    const std::string moduleFqn = std::string().append(Module::descriptor).append("/a2dp");
    if (binder_status_t status = AServiceManager_addService(module.getBinder(), moduleFqn.c_str());
        status != STATUS_OK) {
        LOG(ERROR) << "failed to register " << moduleFqn << ": " << status;
    }

    ABinderProcess_joinThreadPool();
    return EXIT_FAILURE;  // should not reach
}
