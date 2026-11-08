#pragma once

void GPU_InitCompute(void);
void GPU_ShutdownCompute(void);
void GPU_ResetParticleTerrain(void);
Boolean GPU_SkinSkeleton(ObjNode* node);
void GPU_ValidateSkin(ObjNode* node);
Boolean GPU_MoveParticleGroup(ParticleGroupType* group, float dt);
Boolean GPU_DrawParticleGroup(ParticleGroupType* group, const OGLPoint3D* camera);
extern int gGPUDeformedVertices;
extern int gGPUSimulatedParticles;
