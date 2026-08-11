#include <jni.h>

JNIEXPORT jstring JNICALL
Java_dev_redroid_arm64smoke_MainActivity_nativeMessage(JNIEnv *env,
                                                        jclass clazz) {
    (void)clazz;
    return (*env)->NewStringUTF(env, "ARM64 native bridge: ok");
}
