#ifndef ROTATION_BRIDGE_H
#define ROTATION_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Returns 0 when the rotation request was accepted by macOS.
int32_t RBSetDisplayRotation(uint32_t displayID, int32_t degrees);

/// Human-readable detail for the most recent bridge error.
const char *RBLastErrorMessage(void);

#ifdef __cplusplus
}
#endif

#endif
