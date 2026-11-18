#include "game.h"

#define ReactionTime SpecialF[0]
#define IdleTime SpecialF[1]
#define TriggerRadius SpecialF[2]
#define PlayerNearby Flag[0]

static float EaseInOut(float start, float end, float time)
{
	const float t = SDL_clamp((time-start)/(end-start), 0.0f, 1.0f);
	return t*t*(3.0f-2.0f*t);
}

static void PlaceGagPart(const ObjNode* parent, ObjNode* part, OGLPoint3D pivot, OGLVector3D rotation)
{
	OGLMatrix4x4 local;
	OGLMatrix4x4_SetRotate_XYZ(&local, rotation.x, rotation.y, rotation.z);
	local.value[M03] = pivot.x;
	local.value[M13] = pivot.y;
	local.value[M23] = pivot.z;
	OGLMatrix4x4_Multiply(&local, &parent->BaseTransformMatrix, &part->BaseTransformMatrix);
	part->Coord.x = part->BaseTransformMatrix.value[M03];
	part->Coord.y = part->BaseTransformMatrix.value[M13];
	part->Coord.z = part->BaseTransformMatrix.value[M23];
	SetObjectTransformMatrix(part);
}

static void PoseDesertGag(ObjNode* base, float previousTime)
{
	ObjNode* part = base->ChainNode;
	ObjNode* tip = part->ChainNode;
	const float t = base->ReactionTime;
	const float idle = base->IdleTime;

	switch (base->Type)
	{
		case DESERT_GAG_ObjType_OstrichBody:
		{
			const float surprise = EaseInOut(0.0f, .09f, t) * (1-EaseInOut(.09f, .20f, t));
			const float dip = EaseInOut(.11f, .35f, t) * (1-EaseInOut(.75f, 1.23f, t));
			const float pitch = .045f*sinf(3*idle)*(1-dip) + .13f*surprise - 2.12f*dip;
			PlaceGagPart(base, part, (OGLPoint3D){0, 175, -33}, (OGLVector3D){pitch, 0, 0});
			PlaceGagPart(part, tip, (OGLPoint3D){0, 146, -24},
				(OGLVector3D){.14f*dip, .13f*sinf(1.6f*idle)*(1-dip), 0});
			if (previousTime < .12f && t >= .12f)
				PlayEffect_Parms3D(EFFECT_BIRDCAW, &tip->Coord, NORMAL_CHANNEL_RATE * 11 / 10, .5f);
			break;
		}

		case DESERT_GAG_ObjType_Cactus:
		{
			const float aim = EaseInOut(0.0f, .20f, t) * (1-EaseInOut(.40f, .78f, t));
			const float recoil = EaseInOut(.22f, .29f, t) * (1-EaseInOut(.29f, .51f, t));
			PlaceGagPart(base, part, (OGLPoint3D){0, 131+6*aim, -77+5*recoil},
				(OGLVector3D){.12f*aim-.15f*recoil, .10f*sinf(2*idle)*(1-aim), 0});
			PlaceGagPart(part, tip, (OGLPoint3D){0, 0, -48}, (OGLVector3D){0, 0, 0});
			SetObjectVisible(tip, t >= .22f && t < .33f);
			if (previousTime < .22f && t >= .22f)
				PlayEffect_Parms3D(EFFECT_SELECTCLICK, &part->Coord, NORMAL_CHANNEL_RATE, .6f);
			break;
		}

		case DESERT_GAG_ObjType_Turtle:
		{
			const float wave = EaseInOut(.34f, .65f, t) * (1-EaseInOut(1.50f, 1.96f, t));
			PlaceGagPart(base, part, (OGLPoint3D){0, 63, -98},
				(OGLVector3D){.09f*sinf(2*idle) + .22f*wave, .15f*sinf(1.4f*idle)*(1-wave), 0});
			PlaceGagPart(base, tip, (OGLPoint3D){110, 60, -45},
				(OGLVector3D){.20f*wave, .10f, -.20f - .58f*sinf(10*(t-.34f))*wave});
			break;
		}
	}
}

static void MoveDesertGag(ObjNode* base)
{
	const float dt = gFramesPerSecondFrac;
	float previousTime = base->ReactionTime;
	if (!gNoCarControls)
	{
		// Hysteresis lets each scene react once per pass, including on subsequent laps.
		bool nearby = false;
		const float radius = base->TriggerRadius * (base->PlayerNearby ? 1.25f : 1.0f);
		for (int i = 0; i < gNumRealPlayers; i++)
		{
			const PlayerInfoType* player = &gPlayerInfo[i];
			const ObjNode* car = player->objNode;
			if (!car || !player->onThisMachine || player->isComputer || player->isEliminated)
				continue;
			if (!base->PlayerNearby && car->Speed2D < 240.0f)
				continue;

			const float dx = car->Coord.x - base->Coord.x;
			const float dz = car->Coord.z - base->Coord.z;
			if (dx*dx + dz*dz < radius*radius)
			{
				nearby = true;
				break;
			}
		}
		if (nearby && !base->PlayerNearby)
			previousTime = 0.0f;
		base->PlayerNearby = nearby;
	}

	base->ReactionTime = fminf(previousTime + dt, 3.0f);
	base->IdleTime += dt;
	PoseDesertGag(base, previousTime);
}

void CreateDesertGags(void)
{
	if (!UseDesertScenery())
		return;

	// Desert path coordinates. Keep every footprint outside the driving line.
	static const struct
	{
		float x, z, yaw, scale, triggerRadius;
		int body, part, tip;
	} scenes[] =
	{
		{75320, 89490, .86f, 1.48f, 2480,
			DESERT_GAG_ObjType_OstrichBody, DESERT_GAG_ObjType_OstrichNeck, DESERT_GAG_ObjType_OstrichHead},
		{82495, 84450, 2.55f, 1.63f, 3230,
			DESERT_GAG_ObjType_Cactus, DESERT_GAG_ObjType_Camera, DESERT_GAG_ObjType_Flash},
		{80310, 76435, 3.57f, 1.65f, 2800,
			DESERT_GAG_ObjType_Turtle, DESERT_GAG_ObjType_TurtleHead, DESERT_GAG_ObjType_Flag},
	};

	for (int i = 0; i < SDL_arraysize(scenes); i++)
	{
		const float x = scenes[i].x, z = scenes[i].z;
		NewObjectDefinitionType def =
		{
			.group = MODEL_GROUP_DESERT_GAGS,
			.type = scenes[i].body,
			.coord = {x, GetTerrainY(x, z), z},
			.flags = gAutoFadeStatusBits,
			.slot = ENEMY_SLOT + 1,
			.moveCall = MoveDesertGag,
			.rot = scenes[i].yaw,
			.scale = scenes[i].scale,
		};
		ObjNode* base = MakeNewDisplayGroupObject(&def);
		base->ReactionTime = 3.0f;
		base->TriggerRadius = scenes[i].triggerRadius;
		AttachShadowToObject(base, SHADOW_TYPE_CIRCULAR, 6*def.scale, 7*def.scale, false);
		UpdateShadow(base);

		def.moveCall = nil;
		def.type = scenes[i].part;
		def.slot++;
		ObjNode* part = MakeNewDisplayGroupObject(&def);
		AppendNodeToChain(base, part);
		def.type = scenes[i].tip;
		def.slot++;
		if (def.type == DESERT_GAG_ObjType_Flash)
			def.flags |= STATUS_BIT_NOLIGHTING;
		AppendNodeToChain(part, MakeNewDisplayGroupObject(&def));
		PoseDesertGag(base, base->ReactionTime);
	}
}
