#include "framesharpen.h"
#include "shaderprogram.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_opengl.h>
#include <SDL3/SDL_opengl_glext.h>

#define SHARPEN_GL_FUNCTIONS(X) \
	X(ActiveTexture, PFNGLACTIVETEXTUREPROC) \
	X(DeleteProgram, PFNGLDELETEPROGRAMPROC) \
	X(UseProgram, PFNGLUSEPROGRAMPROC) \
	X(GetUniformLocation, PFNGLGETUNIFORMLOCATIONPROC) \
	X(Uniform1f, PFNGLUNIFORM1FPROC) \
	X(Uniform2f, PFNGLUNIFORM2FPROC)

#define DECLARE_GL(name, type) static type p##name;
SHARPEN_GL_FUNCTIONS(DECLARE_GL)
#undef DECLARE_GL

static GLuint gSharpenProgram;
static GLuint gFrameTexture;
static GLint gTexelSizeLocation;
static GLint gStrengthLocation;
static GLint gMaxTextureSize;
static int gFrameTextureWidth;
static int gFrameTextureHeight;

static const GLchar kVertexShader[] =
	"#version 110\n"
	"void main() { gl_Position = gl_Vertex; }\n";

// Boost detail within the local color range to keep text and silhouettes clean.
static const GLchar kFragmentShader[] =
	"#version 110\n"
	"uniform sampler2D frame;\n"
	"uniform vec2 texelSize;\n"
	"uniform float strength;\n"
	"void main() {\n"
	"    vec2 uv = gl_FragCoord.xy * texelSize;\n"
	"    vec4 center = texture2D(frame, uv);\n"
	"    vec3 left = texture2D(frame, uv - vec2(texelSize.x, 0.0)).rgb;\n"
	"    vec3 right = texture2D(frame, uv + vec2(texelSize.x, 0.0)).rgb;\n"
	"    vec3 down = texture2D(frame, uv - vec2(0.0, texelSize.y)).rgb;\n"
	"    vec3 up = texture2D(frame, uv + vec2(0.0, texelSize.y)).rgb;\n"
	"    vec3 low = min(center.rgb, min(min(left, right), min(down, up)));\n"
	"    vec3 high = max(center.rgb, max(max(left, right), max(down, up)));\n"
	"    vec3 blur = 0.25 * (left + right + down + up);\n"
	"    vec3 color = clamp(center.rgb + strength * (center.rgb - blur), low, high);\n"
	"    gl_FragColor = vec4(color, center.a);\n"
	"}\n";

bool OGL_InitFrameSharpening(void)
{
	if (SDL_getenv("CMR_DISABLE_SHARPENING"))
		return false;

#define LOAD_GL(name, type) p##name = (type) SDL_GL_GetProcAddress("gl" #name); if (!p##name) return false;
	SHARPEN_GL_FUNCTIONS(LOAD_GL)
#undef LOAD_GL

	gSharpenProgram = OGL_BuildShaderProgram("Frame sharpening", kVertexShader, kFragmentShader);
	if (!gSharpenProgram)
		return false;

	// The frame sampler defaults to texture unit zero.
	gTexelSizeLocation = pGetUniformLocation(gSharpenProgram, "texelSize");
	gStrengthLocation = pGetUniformLocation(gSharpenProgram, "strength");
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &gMaxTextureSize);
	glGenTextures(1, &gFrameTexture);
	if (!gFrameTexture)
	{
		OGL_DisposeFrameSharpening();
		return false;
	}
	return true;
}

void OGL_DisposeFrameSharpening(void)
{
	if (gFrameTexture)
		glDeleteTextures(1, &gFrameTexture);
	if (gSharpenProgram)
		pDeleteProgram(gSharpenProgram);
	gFrameTexture = 0;
	gSharpenProgram = 0;
	gFrameTextureWidth = 0;
	gFrameTextureHeight = 0;
}

bool OGL_IsFrameSharpeningAvailable(void)
{
	return gSharpenProgram != 0;
}

bool OGL_SharpenFrame(int width, int height, float strength)
{
	if (!(strength > 0.0f) || !OGL_IsFrameSharpeningAvailable()
		|| width <= 0 || height <= 0 || width > gMaxTextureSize || height > gMaxTextureSize)
		return false;

	glPushAttrib(GL_COLOR_BUFFER_BIT | GL_ENABLE_BIT | GL_PIXEL_MODE_BIT | GL_TEXTURE_BIT | GL_VIEWPORT_BIT);
	pActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, gFrameTexture);
	if (width != gFrameTextureWidth || height != gFrameTextureHeight)
	{
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		gFrameTextureWidth = width;
		gFrameTextureHeight = height;
	}

	// Copy directly into a GPU texture before presenting the completed frame.
	glReadBuffer(GL_BACK);
	glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 0, 0, width, height);
	GLenum error = glGetError();
	if (error == GL_NO_ERROR)
	{
		GLint previousProgram = 0;
		glGetIntegerv(GL_CURRENT_PROGRAM, &previousProgram);
		glViewport(0, 0, width, height);
		glDisable(GL_SCISSOR_TEST);
		glDisable(GL_DEPTH_TEST);
		glDisable(GL_STENCIL_TEST);
		glDisable(GL_ALPHA_TEST);
		glDisable(GL_BLEND);
		glDisable(GL_CULL_FACE);
		glDisable(GL_COLOR_LOGIC_OP);
		glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

		pUseProgram(gSharpenProgram);
		pUniform2f(gTexelSizeLocation, 1.0f / width, 1.0f / height);
		pUniform1f(gStrengthLocation, SDL_min(strength, 1.0f));
		glBegin(GL_TRIANGLES);
		glVertex2f(-1.0f, -1.0f);
		glVertex2f(3.0f, -1.0f);
		glVertex2f(-1.0f, 3.0f);
		glEnd();
		pUseProgram((GLuint) previousProgram);
		error = glGetError();
	}
	glPopAttrib();

	if (error != GL_NO_ERROR)
	{
		SDL_Log("Frame sharpening disabled after OpenGL error 0x%x", error);
		OGL_DisposeFrameSharpening();
		return false;
	}
	return true;
}
