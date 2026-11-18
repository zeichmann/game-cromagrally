#include "shaderprogram.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_opengl_glext.h>

#define SHADER_GL_FUNCTIONS(X) \
	X(CreateShader, PFNGLCREATESHADERPROC) \
	X(ShaderSource, PFNGLSHADERSOURCEPROC) \
	X(CompileShader, PFNGLCOMPILESHADERPROC) \
	X(GetShaderiv, PFNGLGETSHADERIVPROC) \
	X(GetShaderInfoLog, PFNGLGETSHADERINFOLOGPROC) \
	X(DeleteShader, PFNGLDELETESHADERPROC) \
	X(CreateProgram, PFNGLCREATEPROGRAMPROC) \
	X(AttachShader, PFNGLATTACHSHADERPROC) \
	X(LinkProgram, PFNGLLINKPROGRAMPROC) \
	X(GetProgramiv, PFNGLGETPROGRAMIVPROC) \
	X(GetProgramInfoLog, PFNGLGETPROGRAMINFOLOGPROC) \
	X(DeleteProgram, PFNGLDELETEPROGRAMPROC)

#define DECLARE_GL(name, type) static type p##name;
SHADER_GL_FUNCTIONS(DECLARE_GL)
#undef DECLARE_GL

static GLuint CompileShader(const char* label, GLenum stage, const GLchar* source)
{
	GLuint shader = pCreateShader(stage);
	if (!shader)
		return 0;

	pShaderSource(shader, 1, &source, NULL);
	pCompileShader(shader);
	GLint compiled = GL_FALSE;
	pGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
	if (compiled)
		return shader;

	char log[512] = {0};
	pGetShaderInfoLog(shader, sizeof(log), NULL, log);
	SDL_Log("%s shader (%s): %s", label, stage == GL_VERTEX_SHADER ? "vertex" : "fragment", log);
	pDeleteShader(shader);
	return 0;
}

GLuint OGL_BuildShaderProgram(const char* label, const char* vertexSource, const char* fragmentSource)
{
#define LOAD_GL(name, type) p##name = (type)SDL_GL_GetProcAddress("gl" #name); if (!p##name) return 0;
	SHADER_GL_FUNCTIONS(LOAD_GL)
#undef LOAD_GL

	GLuint vertex = CompileShader(label, GL_VERTEX_SHADER, vertexSource);
	if (!vertex)
		return 0;

	GLuint fragment = CompileShader(label, GL_FRAGMENT_SHADER, fragmentSource);
	if (!fragment)
	{
		pDeleteShader(vertex);
		return 0;
	}

	GLuint program = pCreateProgram();
	if (program)
	{
		pAttachShader(program, vertex);
		pAttachShader(program, fragment);
		pLinkProgram(program);
	}
	pDeleteShader(fragment);
	pDeleteShader(vertex);
	if (!program)
		return 0;

	GLint linked = GL_FALSE;
	pGetProgramiv(program, GL_LINK_STATUS, &linked);
	if (!linked)
	{
		char log[512] = {0};
		pGetProgramInfoLog(program, sizeof(log), NULL, log);
		SDL_Log("%s program: %s", label, log);
		pDeleteProgram(program);
		return 0;
	}
	return program;
}
