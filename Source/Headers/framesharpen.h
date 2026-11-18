#pragma once

#include <stdbool.h>

bool OGL_InitFrameSharpening(void);
void OGL_DisposeFrameSharpening(void);
bool OGL_IsFrameSharpeningAvailable(void);
bool OGL_SharpenFrame(int width, int height, float strength);
