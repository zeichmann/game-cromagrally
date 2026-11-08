// A world-locked detail layer preserves the baked track artwork and road layout.
#include "game.h"
#include <SDL3/SDL_opengl_glext.h>

static MOMaterialObject* gDesertDetail;
static PFNGLACTIVETEXTUREPROC gActiveTexture;
static Boolean gDetailActive;

void OGL_ConfigureHighQualityTexture(void)
{
	PFNGLGENERATEMIPMAPPROC generateMipmap=(PFNGLGENERATEMIPMAPPROC)SDL_GL_GetProcAddress("glGenerateMipmap");
	if (generateMipmap)
	{
		generateMipmap(GL_TEXTURE_2D);
		glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);
	}
	if (SDL_GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic"))
	{
		GLfloat maxAnisotropy=1;
		glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT,&maxAnisotropy);
		glTexParameterf(GL_TEXTURE_2D,GL_TEXTURE_MAX_ANISOTROPY_EXT,fminf(maxAnisotropy,16));
	}
}

Boolean OGL_BeginTerrainDetail(void)
{
	if (gTrackNum!=TRACK_NUM_DESERT || SDL_getenv("CMR_ORIGINAL_TEXTURES")) return false;
	if (!gActiveTexture) gActiveTexture=(PFNGLACTIVETEXTUREPROC)SDL_GL_GetProcAddress("glActiveTexture");
	GLint units=0,maxTextureSize=0;
	glGetIntegerv(GL_MAX_TEXTURE_UNITS,&units);
	glGetIntegerv(GL_MAX_TEXTURE_SIZE,&maxTextureSize);
	if (!gActiveTexture || units<2 || maxTextureSize<4096) return false;
	if (!gDesertDetail)
	{
		int oldFlags=gLoadTextureFlags;
		gLoadTextureFlags |= kLoadTextureFlags_NoGammaFix; // Signed-add needs a neutral midpoint.
		gDesertDetail=MO_GetTextureFromFile(":TexturesHD:desert-detail.png",GL_RGBA);
		gLoadTextureFlags=oldFlags;
		OGL_ConfigureHighQualityTexture();
	}
	gActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D,gDesertDetail->objectData.textureName[0]);
	glEnable(GL_TEXTURE_2D);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_REPEAT);
	const GLfloat sPlane[4]={1.0f/1600,0,0,0}, tPlane[4]={0,0,1.0f/1600,0};
	glTexGeni(GL_S,GL_TEXTURE_GEN_MODE,GL_OBJECT_LINEAR);
	glTexGeni(GL_T,GL_TEXTURE_GEN_MODE,GL_OBJECT_LINEAR);
	glTexGenfv(GL_S,GL_OBJECT_PLANE,sPlane);
	glTexGenfv(GL_T,GL_OBJECT_PLANE,tPlane);
	glEnable(GL_TEXTURE_GEN_S); glEnable(GL_TEXTURE_GEN_T);
	glTexEnvi(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_COMBINE);
	glTexEnvi(GL_TEXTURE_ENV,GL_COMBINE_RGB,GL_ADD_SIGNED);
	glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE0_RGB,GL_PREVIOUS);
	glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE1_RGB,GL_TEXTURE);
	glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND0_RGB,GL_SRC_COLOR);
	glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND1_RGB,GL_SRC_COLOR);
	glTexEnvi(GL_TEXTURE_ENV,GL_COMBINE_ALPHA,GL_REPLACE);
	glTexEnvi(GL_TEXTURE_ENV,GL_SOURCE0_ALPHA,GL_PREVIOUS);
	glTexEnvi(GL_TEXTURE_ENV,GL_OPERAND0_ALPHA,GL_SRC_ALPHA);
	gActiveTexture(GL_TEXTURE0);
	gDetailActive=true;
	return true;
}
void OGL_EndTerrainDetail(void)
{
	if (!gDetailActive) return;
	gActiveTexture(GL_TEXTURE1);
	glDisable(GL_TEXTURE_GEN_S); glDisable(GL_TEXTURE_GEN_T);
	glDisable(GL_TEXTURE_2D);
	glTexEnvi(GL_TEXTURE_ENV,GL_TEXTURE_ENV_MODE,GL_MODULATE);
	gActiveTexture(GL_TEXTURE0);
	gDetailActive=false;
}
void OGL_DisposeTerrainDetail(void)
{
	OGL_EndTerrainDetail();
	if (gDesertDetail) MO_DisposeObjectReference(gDesertDetail);
	gDesertDetail=NULL;
}
