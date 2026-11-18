#pragma once

#include <SDL3/SDL_opengl.h>

GLuint OGL_BuildShaderProgram(const char* label, const char* vertexSource, const char* fragmentSource);
