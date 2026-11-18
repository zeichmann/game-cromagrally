#include "game.h"
#include <math.h>


enum
{
	RIGHT_SHOULDER = 2,
	RIGHT_ELBOW = 4,
	RIGHT_HAND = 5,
};

static const OGLPoint3D kHandGrip = {0, -3, -6};

enum
{
	CLUB_WHEEL,
	CLUB_GRAB,
	CLUB_LIFT,
	CLUB_STRIKE,
	CLUB_FOLLOW_THROUGH,
	CLUB_STOW,
	CLUB_RETURN,
};

typedef struct
{
	float time;
	OGLVector3D reach;
	OGLVector3D clubAxis;
} ClubPose;

// Reach is relative to the right shoulder, in fractions of the arm's length.
static const OGLVector3D kRackAxis = {.15f, .97f, .19f};
static const ClubPose kClubPoses[] =
{
	[CLUB_WHEEL]          = {0.00f, {0},                       {.15f, .97f, .19f}},
	[CLUB_GRAB]           = {0.16f, {0},                       {.15f, .97f, .19f}},
	[CLUB_LIFT]           = {0.34f, {.50f,  .74f,  .12f},    {.17f,  .98f, .04f}},
	[CLUB_STRIKE]         = {0.52f, {.82f, -.32f, -.05f},    {.73f, -.68f, .02f}},
	[CLUB_FOLLOW_THROUGH] = {0.62f, {.72f, -.48f, -.08f},    {.46f, -.88f, .04f}},
	[CLUB_STOW]           = {0.86f, {0},                       {.15f, .97f, .19f}},
	[CLUB_RETURN]         = {1.02f, {0},                       {.15f, .97f, .19f}},
};

// Local to DriverClub.bg3d. The origin is inside the driver's palm.
static const OGLPoint3D kClubContact = {-4, 94, 0};
static const float kClubHeadRadius = 26;

#define ClubHitPlayers Special[0]


static OGLPoint3D GetRackGrip(const ObjNode* driver)
{
	static const OGLPoint3D stockMounts[] = {{87, 12, 54}, {77, 0, 51}};
	static const OGLPoint3D wickerMount = {63, 43, 52};
	const PlayerInfoType* player = &gPlayerInfo[driver->PlayerNum];
	const bool wicker = player->vehicleType == CAR_TYPE_WICKER;
	const OGLPoint3D* mount = wicker ? &wickerMount : &stockMounts[player->sex];
	const ObjNode* base = wicker ? player->objNode : driver;
	OGLPoint3D grip;
	OGLPoint3D_Transform(mount, &base->BaseTransformMatrix, &grip);
	return grip;
}


static OGLPoint3D GetTranslation(const OGLMatrix4x4* matrix)
{
	return (OGLPoint3D) {matrix->value[M03], matrix->value[M13], matrix->value[M23]};
}


static OGLPoint3D InterpolatePoint(OGLPoint3D a, OGLPoint3D b, float t)
{
	return (OGLPoint3D) {a.x + t*(b.x-a.x), a.y + t*(b.y-a.y), a.z + t*(b.z-a.z)};
}


static void SetClubRotation(OGLVector3D from, OGLVector3D to, OGLMatrix4x4* matrix)
{
	OGLVector3D_Normalize(&from, &from);
	OGLVector3D_Normalize(&to, &to);
	const float cosine = OGLVector3D_Dot(&from, &to);
	const float parallel = 1.0f - 1e-6f;
	if (cosine >= parallel)
	{
		OGLMatrix4x4_SetIdentity(matrix);
		return;
	}

	OGLVector3D axis;
	if (cosine <= -parallel)
	{
		const OGLVector3D reference = fabsf(from.y) < .8f ? (OGLVector3D){0, 1, 0} : (OGLVector3D){1, 0, 0};
		OGLVector3D_Cross(&from, &reference, &axis);
	}
	else
		OGLVector3D_Cross(&from, &to, &axis);
	OGLMatrix4x4_SetRotateAboutAxis(matrix, &axis, acosf(SDL_clamp(cosine, -1.0f, 1.0f)));
}


static void PlaceClubPiece(ObjNode* piece, const ObjNode* car, OGLPoint3D grip, OGLVector3D localAxis)
{
	const OGLVector3D up = {0, 1, 0};
	OGLMatrix4x4 rotation;
	SetClubRotation(up, localAxis, &rotation);
	OGLMatrix4x4_Multiply(&rotation, &car->BaseTransformMatrix, &piece->BaseTransformMatrix);
	piece->BaseTransformMatrix.value[M03] = grip.x;
	piece->BaseTransformMatrix.value[M13] = grip.y;
	piece->BaseTransformMatrix.value[M23] = grip.z;
	piece->Coord = grip;
	SetObjectTransformMatrix(piece);
}


static void AimArmJoint(OGLMatrix4x4* matrix, OGLPoint3D pivot, OGLVector3D from, OGLVector3D to)
{
	OGLMatrix4x4 rotation;
	SetClubRotation(from, to, &rotation);
	OGLMatrix4x4_Multiply(matrix, &rotation, matrix);
	matrix->value[M03] = pivot.x;
	matrix->value[M13] = pivot.y;
	matrix->value[M23] = pivot.z;
}


static OGLVector3D ProjectPerpendicular(OGLVector3D vector, OGLVector3D axis)
{
	// OGLVector3D_Dot clamps to [-1, 1] for angles. This projection uses lengths.
	const float along = vector.x*axis.x + vector.y*axis.y + vector.z*axis.z;
	return (OGLVector3D) {vector.x - along*axis.x, vector.y - along*axis.y, vector.z - along*axis.z};
}


static OGLPoint3D ReachForClub(ObjNode* driver, OGLPoint3D target,
							  OGLMatrix4x4 shoulderMatrix, OGLMatrix4x4 elbowMatrix, OGLPoint3D grip)
{
	const OGLPoint3D shoulder = GetTranslation(&shoulderMatrix);
	const OGLPoint3D elbow = GetTranslation(&elbowMatrix);
	OGLVector3D upper, lower, direction;
	OGLPoint3D_Subtract(&elbow, &shoulder, &upper);
	OGLPoint3D_Subtract(&grip, &elbow, &lower);
	OGLPoint3D_Subtract(&target, &shoulder, &direction);

	const float upperLength = CalcVectorLength(&upper);
	const float lowerLength = CalcVectorLength(&lower);
	const float reach = SDL_clamp(CalcVectorLength(&direction),
								  fabsf(upperLength-lowerLength) + .1f, upperLength+lowerLength-.1f);
	OGLVector3D_Normalize(&direction, &direction);

	// Bend the elbow in the plane of the current pose and keep both bone lengths.
	OGLVector3D bend = ProjectPerpendicular(upper, direction);
	if (CalcVectorLength(&bend) < .1f)
	{
		const OGLVector3D pole = fabsf(direction.y) < .8f ? (OGLVector3D){0, -1, 0} : (OGLVector3D){0, 0, -1};
		bend = ProjectPerpendicular(pole, direction);
	}
	OGLVector3D_Normalize(&bend, &bend);
	const float along = (reach*reach + upperLength*upperLength - lowerLength*lowerLength) / (2*reach);
	const float height = sqrtf(fmaxf(0, upperLength*upperLength - along*along));

	const OGLVector3D aimedUpper = {direction.x*along + bend.x*height,
								   direction.y*along + bend.y*height,
								   direction.z*along + bend.z*height};
	const OGLVector3D aimedLower = {direction.x*reach - aimedUpper.x,
								   direction.y*reach - aimedUpper.y,
								   direction.z*reach - aimedUpper.z};
	const OGLPoint3D newElbow = {shoulder.x + aimedUpper.x, shoulder.y + aimedUpper.y, shoulder.z + aimedUpper.z};
	const OGLPoint3D newGrip = {shoulder.x + direction.x*reach, shoulder.y + direction.y*reach, shoulder.z + direction.z*reach};

	AimArmJoint(&shoulderMatrix, shoulder, upper, aimedUpper);
	AimArmJoint(&elbowMatrix, newElbow, lower, aimedLower);

	SkeletonObjDataType* skeleton = driver->Skeleton;
	const short parent = skeleton->skeletonDefinition->Bones[RIGHT_SHOULDER].parentBone;
	OGLMatrix4x4 parentMatrix, inverse;
	FindJointFullMatrix(driver, parent, &parentMatrix);
	OGLMatrix4x4_Invert(&parentMatrix, &inverse);
	OGLMatrix4x4_Multiply(&shoulderMatrix, &inverse, &skeleton->jointTransformMatrix[RIGHT_SHOULDER]);
	OGLMatrix4x4_Invert(&shoulderMatrix, &inverse);
	OGLMatrix4x4_Multiply(&elbowMatrix, &inverse, &skeleton->jointTransformMatrix[RIGHT_ELBOW]);
	return newGrip;
}


static bool ClubPathHitsCar(OGLPoint3D from, OGLPoint3D to, float enter, float exit, const CollisionBoxType* box)
{
	// Test the club head's path relative to the other car's movement this frame.
	const float start[] = {from.x + (box->left - box->oldLeft),
						   from.y + (box->bottom - box->oldBottom),
						   from.z + (box->back - box->oldBack)};
	const float end[] = {to.x, to.y, to.z};
	const float low[] = {box->left, box->bottom, box->back};
	const float high[] = {box->right, box->top, box->front};
	for (int axis = 0; axis < 3; axis++)
	{
		const float a = low[axis] - kClubHeadRadius - start[axis];
		const float b = high[axis] + kClubHeadRadius - start[axis];
		const float travel = end[axis] - start[axis];
		if (fabsf(travel) < EPS)
		{
			if (a > 0 || b < 0)
				return false;
			continue;
		}

		const float t1 = a / travel;
		const float t2 = b / travel;
		enter = fmaxf(enter, fminf(t1, t2));
		exit = fminf(exit, fmaxf(t1, t2));
		if (enter > exit)
			return false;
	}
	return true;
}


static void CheckClubHits(ObjNode* club, const ObjNode* car, OGLPoint3D from, OGLPoint3D to, float start, float stop)
{
	const float rightX = cosf(car->Rot.y);
	const float rightZ = -sinf(car->Rot.y);
	for (int i = 0; i < gNumTotalPlayers; i++)
	{
		PlayerInfoType* rival = &gPlayerInfo[i];
		ObjNode* target = rival->objNode;
		if (i == car->PlayerNum || (club->ClubHitPlayers & (1u << i))
			|| !target || !target->CollisionBoxes || target->CType == INVALID_NODE_FLAG || rival->isEliminated)
			continue;

		const float side = (target->Coord.x - car->Coord.x) * rightX + (target->Coord.z - car->Coord.z) * rightZ;
		if (side <= 0 || !ClubPathHitsCar(from, to, start, stop, target->CollisionBoxes))
			continue;

		club->ClubHitPlayers |= 1u << i;
		target->Delta.x += 625.0f * rightX;
		target->Delta.z += 625.0f * rightZ;
		target->DeltaRot.y += 2.4f;
		rival->greasedTiresTimer = fmaxf(rival->greasedTiresTimer, .40f);
		rival->isPlaning = true;
		PlayEffect_Parms3D(EFFECT_CRASH2, &to, NORMAL_CHANNEL_RATE, .8f);
	}
}


void CreatePlayerClub(ObjNode* driver)
{
	NewObjectDefinitionType def =
	{
		.group = MODEL_GROUP_DRIVER_CLUB,
		.type = DRIVER_CLUB_ObjType_Rack,
		.slot = driver->Slot,
		.scale = 1,
		.player = driver->PlayerNum,
	};
	ObjNode* rack = MakeNewDisplayGroupObject(&def);
	GAME_ASSERT(rack);

	def.type = DRIVER_CLUB_ObjType_Club;
	ObjNode* club = MakeNewDisplayGroupObject(&def);
	GAME_ASSERT(club);

	driver->ChainNode = rack;
	rack->ChainNode = club;
	PlayerInfoType* player = &gPlayerInfo[driver->PlayerNum];
	player->clubSwingTime = 0;

	const OGLPoint3D stowed = GetRackGrip(driver);
	PlaceClubPiece(rack, player->objNode, stowed, kRackAxis);
	PlaceClubPiece(club, player->objNode, stowed, kRackAxis);
}


void UpdatePlayerClub(ObjNode* driver)
{
	PlayerInfoType* player = &gPlayerInfo[driver->PlayerNum];
	ObjNode* rack = driver->ChainNode;
	ObjNode* club = rack->ChainNode;
	const ObjNode* car = player->objNode;
	const OGLPoint3D stowed = GetRackGrip(driver);
	PlaceClubPiece(rack, car, stowed, kRackAxis);

	const int anim = driver->Skeleton->AnimNum;
	const bool canSwing = !gNoCarControls && !player->isEliminated && !player->raceComplete
		&& player->frozenTimer <= 0 && anim != PLAYER_ANIM_THROWFORWARD && anim != PLAYER_ANIM_THROWBACKWARD;
	const float previousTime = player->clubSwingTime;
	const float time = previousTime + gFramesPerSecondFrac;
	if (!canSwing || time >= kClubPoses[CLUB_RETURN].time
		|| (previousTime == 0 && !GetControlStateNew(driver->PlayerNum, kControlBit_ClubSwing)))
	{
		player->clubSwingTime = 0;
		PlaceClubPiece(club, car, stowed, kRackAxis);
		return;
	}

	player->clubSwingTime = time;
	if (previousTime == 0)
		club->ClubHitPlayers = 0;

	OGLMatrix4x4 shoulderMatrix, elbowMatrix;
	OGLPoint3D steeringGrip;
	FindJointFullMatrix(driver, RIGHT_SHOULDER, &shoulderMatrix);
	FindJointFullMatrix(driver, RIGHT_ELBOW, &elbowMatrix);
	FindCoordOnJoint(driver, RIGHT_HAND, &kHandGrip, &steeringGrip);
	const OGLPoint3D shoulder = GetTranslation(&shoulderMatrix);
	const OGLPoint3D elbow = GetTranslation(&elbowMatrix);
	const float armLength = OGLPoint3D_Distance(&shoulder, &elbow) + OGLPoint3D_Distance(&elbow, &steeringGrip);
	OGLPoint3D grips[] = {steeringGrip, stowed, {0}, {0}, {0}, stowed, steeringGrip};
	for (int i = CLUB_LIFT; i <= CLUB_FOLLOW_THROUGH; i++)
	{
		OGLVector3D reach = kClubPoses[i].reach;
		OGLVector3D direction;
		OGLVector3D_Transform(&reach, &driver->BaseTransformMatrix, &direction);
		// The vector transform returns a unit direction.
		const float length = armLength * CalcVectorLength(&reach);
		grips[i] = (OGLPoint3D) {shoulder.x + length*direction.x, shoulder.y + length*direction.y, shoulder.z + length*direction.z};
	}

	int phase = CLUB_WHEEL;
	while (time >= kClubPoses[phase+1].time)
		phase++;
	const ClubPose* a = &kClubPoses[phase];
	const ClubPose* b = &kClubPoses[phase+1];
	const float fraction = (time - a->time) / (b->time - a->time);
	float ease = fraction*fraction*(3 - 2*fraction);
	if (phase == CLUB_LIFT)
		ease = fraction*fraction;
	else if (phase == CLUB_STRIKE)
		ease = fraction*(2 - fraction);
	const OGLPoint3D targetGrip = InterpolatePoint(grips[phase], grips[phase+1], ease);
	const OGLPoint3D heldGrip = ReachForClub(driver, targetGrip, shoulderMatrix, elbowMatrix, steeringGrip);

	OGLPoint3D previousContact;
	OGLPoint3D_Transform(&kClubContact, &club->BaseTransformMatrix, &previousContact);
	if (phase >= CLUB_GRAB && phase < CLUB_STOW)
	{
		const OGLVector3D direction = {a->clubAxis.x + ease*(b->clubAxis.x-a->clubAxis.x),
									   a->clubAxis.y + ease*(b->clubAxis.y-a->clubAxis.y),
									   a->clubAxis.z + ease*(b->clubAxis.z-a->clubAxis.z)};
		PlaceClubPiece(club, car, heldGrip, direction);
	}
	else
		PlaceClubPiece(club, car, stowed, kRackAxis);

	const float hitStart = kClubPoses[CLUB_LIFT].time;
	const float hitEnd = kClubPoses[CLUB_FOLLOW_THROUGH].time;
	if (previousTime < hitStart && time >= hitStart)
		PlayEffect_Parms3D(EFFECT_THROW1, &club->Coord, NORMAL_CHANNEL_RATE, .7f);
	if (time > hitStart && previousTime < hitEnd)
	{
		OGLPoint3D contact;
		OGLPoint3D_Transform(&kClubContact, &club->BaseTransformMatrix, &contact);
		const float dt = time - previousTime;
		const float start = fmaxf(0, (hitStart-previousTime)/dt);
		const float stop = fminf(1, (hitEnd-previousTime)/dt);
		CheckClubHits(club, car, previousContact, contact, start, stop);
	}
}
