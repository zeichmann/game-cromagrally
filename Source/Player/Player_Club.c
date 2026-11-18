#include "game.h"
#include <math.h>


typedef struct
{
	short shoulder;
	short elbow;
	short wrist;
	OGLPoint3D grip[2];		// Brog and Grag, in wrist coordinates
} DriverArm;

static const DriverArm kRightArm = {2, 4, 5, {{-22, -10, -9}, {-22, -8, -18}}};
static const DriverArm kLeftArm  = {3, 6, 7, {{27, -8, -9}, {17, -8, -10}}};

enum
{
	CLUB_WHEEL,
	CLUB_GRAB,
	CLUB_LIFT,
	CLUB_STRIKE,
	CLUB_FOLLOW_THROUGH,
	CLUB_RECOVER,
	CLUB_STOW,
	CLUB_RETURN,
	NUM_CLUB_POSES,
};

typedef struct
{
	float time;
	OGLVector3D reach;
	OGLPoint3D torso;		// pitch, yaw, roll in degrees
	float tilt;				// shaft angle away from vertical
	float azimuth;			// shaft direction measured from the car's right side
	float wristRoll;		// rotation around the shaft
} ClubPose;

// Reach is relative to the right shoulder, in fractions of the arm's length.
static const ClubPose kClubPoses[NUM_CLUB_POSES] =
{
	[CLUB_WHEEL]          = {0.00f, {0},                     {0,   0,   0},    14,  52, -115},
	[CLUB_GRAB]           = {0.19f, {0},                     {1, -10,  -5},    14,  52, -115},
	[CLUB_LIFT]           = {0.43f, {.33f,  .47f,  .15f},    {5, -12,   2},    35,  66,  -47},
	[CLUB_STRIKE]         = {0.54f, {.60f,  .21f,  .02f},    {0,  -7,  -7},    82,   7,   31},
	[CLUB_FOLLOW_THROUGH] = {0.65f, {.69f, -.31f, -.09f},  {-10, -10, -13},   141,  -8,   48},
	[CLUB_RECOVER]        = {0.85f, {.42f, -.12f,  .24f},   { -3,  -8,  -5},    55,  42,  -44},
	[CLUB_STOW]           = {1.03f, {0},                     {1,  -8,  -4},    14,  52, -115},
	[CLUB_RETURN]         = {1.19f, {0},                     {0,   0,   0},    14,  52, -115},
};

typedef struct
{
	int before, from, to, after;
	float t, span, beforeSpan, afterSpan;
} ClubInterval;

// Local to DriverClub.bg3d. The origin is inside the driver's palm.
static const OGLPoint3D kClubContact = {-4, 94, 0};
static const float kClubHeadRadius = 26;

#define ClubHitPlayers Special[0]


static OGLPoint3D GetRackGrip(const ObjNode* driver)
{
	static const OGLPoint3D stockMounts[] = {{87, 12, 54}, {77, 0, 51}};
	static const OGLPoint3D wickerMount = {63, 50, 52};
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


static void SetTranslation(OGLMatrix4x4* matrix, OGLPoint3D point)
{
	matrix->value[M03] = point.x;
	matrix->value[M13] = point.y;
	matrix->value[M23] = point.z;
}


static ClubInterval FindClubInterval(float time)
{
	int from = CLUB_WHEEL;
	while (time >= kClubPoses[from+1].time)
		from++;
	const int to = from + 1;
	const int before = GAME_MAX(CLUB_WHEEL, from - 1);
	const int after = GAME_MIN(CLUB_RETURN, to + 1);
	const float span = kClubPoses[to].time - kClubPoses[from].time;
	return (ClubInterval)
	{
		.before = before, .from = from, .to = to, .after = after,
		.t = (time - kClubPoses[from].time) / span,
		.span = span,
		.beforeSpan = kClubPoses[from].time - kClubPoses[before].time,
		.afterSpan = kClubPoses[after].time - kClubPoses[to].time,
	};
}


static float ClubTangent(float incoming, float outgoing)
{
	// A component eases to a stop at a reversal. It flows through knots along the rest of the arc.
	return incoming * outgoing > 0 ? 2*incoming*outgoing / (incoming + outgoing) : 0;
}


static float SampleClubCurve(const ClubInterval* interval, float before, float from, float to, float after)
{
	const float speed = (to - from) / interval->span;
	const float start = interval->beforeSpan > 0 ? ClubTangent((from - before)/interval->beforeSpan, speed) : 0;
	const float end = interval->afterSpan > 0 ? ClubTangent(speed, (after - to)/interval->afterSpan) : 0;
	const float t = interval->t;
	const float u = 1 - t;
	return from + (to-from)*t*t*(3 - 2*t) + interval->span*t*u*(u*start - t*end);
}


static OGLPoint3D SampleClubPoint(const ClubInterval* interval, OGLPoint3D before, OGLPoint3D from, OGLPoint3D to, OGLPoint3D after)
{
	return (OGLPoint3D)
	{
		SampleClubCurve(interval, before.x, from.x, to.x, after.x),
		SampleClubCurve(interval, before.y, from.y, to.y, after.y),
		SampleClubCurve(interval, before.z, from.z, to.z, after.z),
	};
}


static OGLVector3D GetClubAxis(float tilt, float azimuth)
{
	const float radians = PI / 180.0f;
	const float side = sinf(tilt*radians);
	return (OGLVector3D) {side*cosf(azimuth*radians), cosf(tilt*radians), side*sinf(azimuth*radians)};
}


static OGLVector3D GetRackAxis(void)
{
	return GetClubAxis(kClubPoses[CLUB_GRAB].tilt, kClubPoses[CLUB_GRAB].azimuth);
}


static void SetDirectionRotation(OGLVector3D from, OGLVector3D to, float blend, OGLMatrix4x4* matrix)
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
	OGLMatrix4x4_SetRotateAboutAxis(matrix, &axis, blend*acosf(SDL_clamp(cosine, -1.0f, 1.0f)));
}


static OGLMatrix4x4 MakeClubFrame(const ObjNode* car, OGLVector3D localAxis)
{
	const OGLVector3D up = {0, 1, 0};
	OGLMatrix4x4 rotation, frame;
	SetDirectionRotation(up, localAxis, 1, &rotation);
	OGLMatrix4x4_Multiply(&rotation, &car->BaseTransformMatrix, &frame);
	return frame;
}


static void PlaceClubPiece(ObjNode* piece, const OGLMatrix4x4* frame, OGLPoint3D grip)
{
	piece->BaseTransformMatrix = *frame;
	SetTranslation(&piece->BaseTransformMatrix, grip);
	piece->Coord = grip;
	SetObjectTransformMatrix(piece);
}


static void AimArmJoint(OGLMatrix4x4* matrix, OGLPoint3D pivot, OGLVector3D from, OGLVector3D to)
{
	OGLMatrix4x4 rotation;
	SetDirectionRotation(from, to, 1, &rotation);
	OGLMatrix4x4_Multiply(matrix, &rotation, matrix);
	SetTranslation(matrix, pivot);
}


static OGLVector3D ProjectPerpendicular(OGLVector3D vector, OGLVector3D axis)
{
	// OGLVector3D_Dot clamps to [-1, 1] for angles. This projection uses lengths.
	const float along = vector.x*axis.x + vector.y*axis.y + vector.z*axis.z;
	return (OGLVector3D) {vector.x - along*axis.x, vector.y - along*axis.y, vector.z - along*axis.z};
}


static OGLVector3D PerpendicularDirection(OGLVector3D vector, OGLVector3D axis)
{
	OGLVector3D perpendicular = ProjectPerpendicular(vector, axis);
	if (CalcVectorLength(&perpendicular) < .001f)
	{
		const OGLVector3D pole = fabsf(axis.y) < .8f ? (OGLVector3D){0, -1, 0} : (OGLVector3D){0, 0, -1};
		perpendicular = ProjectPerpendicular(pole, axis);
	}
	OGLVector3D_Normalize(&perpendicular, &perpendicular);
	return perpendicular;
}


static OGLPoint3D SolveElbow(OGLPoint3D shoulder, OGLPoint3D* wrist, OGLVector3D pole, float upperLength, float lowerLength)
{
	OGLVector3D direction;
	OGLPoint3D_Subtract(wrist, &shoulder, &direction);
	const float distance = CalcVectorLength(&direction);
	const float reach = SDL_clamp(distance,
								  fabsf(upperLength-lowerLength) + .1f, upperLength+lowerLength-.1f);
	if (distance < EPS)
		direction = (OGLVector3D){1, 0, 0};
	else
		OGLVector3D_Normalize(&direction, &direction);
	const OGLVector3D bend = PerpendicularDirection(pole, direction);
	const float along = (reach*reach + upperLength*upperLength - lowerLength*lowerLength) / (2*reach);
	const float height = sqrtf(fmaxf(0, upperLength*upperLength - along*along));

	*wrist = (OGLPoint3D){shoulder.x + direction.x*reach, shoulder.y + direction.y*reach, shoulder.z + direction.z*reach};
	return (OGLPoint3D)
	{
		shoulder.x + direction.x*along + bend.x*height,
		shoulder.y + direction.y*along + bend.y*height,
		shoulder.z + direction.z*along + bend.z*height,
	};
}


static OGLPoint3D WristForGrip(const OGLMatrix4x4* hand, const OGLPoint3D* localGrip, OGLPoint3D target)
{
	const OGLPoint3D wrist = GetTranslation(hand);
	OGLPoint3D grip;
	OGLPoint3D_Transform(localGrip, hand, &grip);
	return (OGLPoint3D){target.x + (wrist.x-grip.x), target.y + (wrist.y-grip.y), target.z + (wrist.z-grip.z)};
}


static void TurnHandToClub(OGLMatrix4x4* hand, const OGLMatrix4x4* frame, float wristRoll, float blend)
{
	const float angle = wristRoll * (PI / 180.0f);
	const OGLVector3D backAroundShaft = {sinf(angle), 0, cosf(angle)};
	const OGLVector3D downShaft = {0, -1, 0};
	OGLVector3D gripBack, gripAcross;
	OGLVector3D_Transform(&backAroundShaft, frame, &gripBack);
	OGLVector3D_Transform(&downShaft, frame, &gripAcross);

	const OGLVector3D across = {hand->value[M00], hand->value[M10], hand->value[M20]};
	const OGLVector3D back = {hand->value[M02], hand->value[M12], hand->value[M22]};
	const OGLPoint3D wrist = GetTranslation(hand);

	// Rotate onto the shaft first. Then roll the palm around it to match the authored wrist pose.
	OGLMatrix4x4 swivel;
	SetDirectionRotation(across, gripAcross, 1, &swivel);
	OGLVector3D fullBack, rollTangent;
	OGLVector3D_Transform(&back, &swivel, &fullBack);
	OGLVector3D_Cross(&gripAcross, &fullBack, &rollTangent);
	const float roll = atan2f(OGLVector3D_Dot(&rollTangent, &gripBack), OGLVector3D_Dot(&fullBack, &gripBack));

	SetDirectionRotation(across, gripAcross, blend, &swivel);
	OGLMatrix4x4_Multiply(hand, &swivel, hand);
	OGLVector3D wristAxis = {hand->value[M00], hand->value[M10], hand->value[M20]};
	OGLVector3D_Normalize(&wristAxis, &wristAxis);
	OGLMatrix4x4_SetRotateAboutAxis(&swivel, &wristAxis, blend*roll);
	OGLMatrix4x4_Multiply(hand, &swivel, hand);
	SetTranslation(hand, wrist);
}


static OGLPoint3D PoseDriverArm(ObjNode* driver, const DriverArm* arm, const OGLPoint3D* localGrip,
								OGLPoint3D target, OGLMatrix4x4 hand, float elbowGuide)
{
	OGLMatrix4x4 shoulderMatrix, elbowMatrix;
	OGLPoint3D wrist;
	FindJointFullMatrix(driver, arm->shoulder, &shoulderMatrix);
	FindJointFullMatrix(driver, arm->elbow, &elbowMatrix);
	FindCoordOfJoint(driver, arm->wrist, &wrist);
	const OGLPoint3D shoulder = GetTranslation(&shoulderMatrix);
	const OGLPoint3D elbow = GetTranslation(&elbowMatrix);
	OGLVector3D upper, lower;
	OGLPoint3D_Subtract(&elbow, &shoulder, &upper);
	OGLPoint3D_Subtract(&wrist, &elbow, &lower);
	const float upperLength = CalcVectorLength(&upper);
	const float lowerLength = CalcVectorLength(&lower);

	OGLVector3D pole = upper;
	if (elbowGuide > 0)
	{
		// Guide the striking elbow out and back during the lift rather than across the driver's chest.
		const OGLVector3D localGuide = {.70f, -.50f, .75f};
		OGLVector3D guide;
		OGLVector3D_Transform(&localGuide, &driver->BaseTransformMatrix, &guide);
		pole.x = (1-elbowGuide)*upper.x + elbowGuide*upperLength*guide.x;
		pole.y = (1-elbowGuide)*upper.y + elbowGuide*upperLength*guide.y;
		pole.z = (1-elbowGuide)*upper.z + elbowGuide*upperLength*guide.z;
	}

	// Fit the wrist to the oriented grip. The hand stays connected to the forearm.
	OGLPoint3D newWrist = WristForGrip(&hand, localGrip, target);
	const OGLPoint3D newElbow = SolveElbow(shoulder, &newWrist, pole, upperLength, lowerLength);
	OGLVector3D aimedUpper, aimedLower;
	OGLPoint3D_Subtract(&newElbow, &shoulder, &aimedUpper);
	OGLPoint3D_Subtract(&newWrist, &newElbow, &aimedLower);

	AimArmJoint(&shoulderMatrix, shoulder, upper, aimedUpper);
	AimArmJoint(&elbowMatrix, newElbow, lower, aimedLower);
	SetTranslation(&hand, newWrist);

	SkeletonObjDataType* skeleton = driver->Skeleton;
	const short parent = skeleton->skeletonDefinition->Bones[arm->shoulder].parentBone;
	OGLMatrix4x4 parentMatrix, inverse;
	FindJointFullMatrix(driver, parent, &parentMatrix);
	OGLMatrix4x4_Invert(&parentMatrix, &inverse);
	OGLMatrix4x4_Multiply(&shoulderMatrix, &inverse, &skeleton->jointTransformMatrix[arm->shoulder]);
	OGLMatrix4x4_Invert(&shoulderMatrix, &inverse);
	OGLMatrix4x4_Multiply(&elbowMatrix, &inverse, &skeleton->jointTransformMatrix[arm->elbow]);
	OGLMatrix4x4_Invert(&elbowMatrix, &inverse);
	OGLMatrix4x4_Multiply(&hand, &inverse, &skeleton->jointTransformMatrix[arm->wrist]);

	OGLPoint3D grip;
	OGLPoint3D_Transform(localGrip, &hand, &grip);
	return grip;
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


static void LeanDriver(ObjNode* driver, OGLPoint3D angles)
{
	const float radians = PI / 180.0f;
	OGLMatrix4x4* torso = &driver->Skeleton->jointTransformMatrix[0];
	const OGLPoint3D hips = GetTranslation(torso);
	OGLMatrix4x4 lean;
	OGLMatrix4x4_SetRotate_XYZ(&lean, angles.x*radians, angles.y*radians, angles.z*radians);
	OGLMatrix4x4_Multiply(torso, &lean, torso);
	SetTranslation(torso, hips);
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
	const OGLMatrix4x4 rackFrame = MakeClubFrame(player->objNode, GetRackAxis());
	PlaceClubPiece(rack, &rackFrame, stowed);
	PlaceClubPiece(club, &rackFrame, stowed);
}


void UpdatePlayerClub(ObjNode* driver)
{
	PlayerInfoType* player = &gPlayerInfo[driver->PlayerNum];
	ObjNode* rack = driver->ChainNode;
	ObjNode* club = rack->ChainNode;
	const ObjNode* car = player->objNode;
	const OGLPoint3D stowed = GetRackGrip(driver);
	const OGLMatrix4x4 rackFrame = MakeClubFrame(car, GetRackAxis());
	PlaceClubPiece(rack, &rackFrame, stowed);

	const int anim = driver->Skeleton->AnimNum;
	const bool canSwing = !gNoCarControls && !player->isEliminated && !player->raceComplete
		&& player->frozenTimer <= 0 && anim != PLAYER_ANIM_THROWFORWARD && anim != PLAYER_ANIM_THROWBACKWARD;
	const float previousTime = player->clubSwingTime;
	const float time = previousTime + gFramesPerSecondFrac;
	if (!canSwing || time >= kClubPoses[CLUB_RETURN].time
		|| (previousTime == 0 && !GetControlStateNew(driver->PlayerNum, kControlBit_ClubSwing)))
	{
		player->clubSwingTime = 0;
		PlaceClubPiece(club, &rackFrame, stowed);
		return;
	}

	player->clubSwingTime = time;
	if (previousTime == 0)
		club->ClubHitPlayers = 0;

	const ClubInterval interval = FindClubInterval(time);
	const ClubPose* before = &kClubPoses[interval.before];
	const ClubPose* from = &kClubPoses[interval.from];
	const ClubPose* to = &kClubPoses[interval.to];
	const ClubPose* after = &kClubPoses[interval.after];
	const float tilt = SampleClubCurve(&interval, before->tilt, from->tilt, to->tilt, after->tilt);
	const float azimuth = SampleClubCurve(&interval, before->azimuth, from->azimuth, to->azimuth, after->azimuth);
	const float wristRoll = SampleClubCurve(&interval, before->wristRoll, from->wristRoll, to->wristRoll, after->wristRoll);
	const OGLMatrix4x4 clubFrame = MakeClubFrame(car, GetClubAxis(tilt, azimuth));

	const OGLPoint3D* rightGrip = &kRightArm.grip[player->sex];
	const OGLPoint3D* leftGrip = &kLeftArm.grip[player->sex];
	OGLMatrix4x4 rightHand, leftHand;
	OGLPoint3D rightWheelGrip, leftWheelGrip;
	FindJointFullMatrix(driver, kRightArm.wrist, &rightHand);
	FindJointFullMatrix(driver, kLeftArm.wrist, &leftHand);
	OGLPoint3D_Transform(rightGrip, &rightHand, &rightWheelGrip);
	OGLPoint3D_Transform(leftGrip, &leftHand, &leftWheelGrip);

	LeanDriver(driver, SampleClubPoint(&interval, before->torso, from->torso, to->torso, after->torso));
	PoseDriverArm(driver, &kLeftArm, leftGrip, leftWheelGrip, leftHand, 0);

	OGLPoint3D shoulder;
	FindCoordOfJoint(driver, kRightArm.shoulder, &shoulder);
	const BoneDefinitionType* bones = driver->Skeleton->skeletonDefinition->Bones;
	const float armLength = driver->Scale.x * (OGLPoint3D_Distance(&bones[kRightArm.shoulder].coord, &bones[kRightArm.elbow].coord)
		+ OGLPoint3D_Distance(&bones[kRightArm.elbow].coord, &bones[kRightArm.wrist].coord));
	OGLPoint3D grips[NUM_CLUB_POSES] =
	{
		[CLUB_WHEEL] = rightWheelGrip, [CLUB_GRAB] = stowed,
		[CLUB_STOW] = stowed, [CLUB_RETURN] = rightWheelGrip,
	};
	for (int i = CLUB_LIFT; i <= CLUB_RECOVER; i++)
	{
		OGLVector3D reach = kClubPoses[i].reach;
		OGLVector3D reachDirection;
		OGLVector3D_Transform(&reach, &driver->BaseTransformMatrix, &reachDirection);
		const float length = armLength * CalcVectorLength(&reach);
		grips[i] = (OGLPoint3D){shoulder.x + length*reachDirection.x,
							   shoulder.y + length*reachDirection.y,
							   shoulder.z + length*reachDirection.z};
	}

	const OGLPoint3D targetGrip = SampleClubPoint(&interval,
			grips[interval.before], grips[interval.from], grips[interval.to], grips[interval.after]);
	const float grasp = interval.from == CLUB_WHEEL ? interval.t : interval.from == CLUB_STOW ? 1-interval.t : 1;
	const float gripBlend = grasp*grasp*(3 - 2*grasp);
	TurnHandToClub(&rightHand, &clubFrame, wristRoll, gripBlend);
	const OGLPoint3D heldGrip = PoseDriverArm(driver, &kRightArm, rightGrip, targetGrip, rightHand, .65f * gripBlend);

	OGLPoint3D previousContact;
	OGLPoint3D_Transform(&kClubContact, &club->BaseTransformMatrix, &previousContact);
	if (interval.from >= CLUB_GRAB && interval.from < CLUB_STOW)
		PlaceClubPiece(club, &clubFrame, heldGrip);
	else
		PlaceClubPiece(club, &rackFrame, stowed);

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
