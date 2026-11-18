class_name IRTeaGeometry
extends RefCounted
## Small bevels use explicit edge loops instead of subdividing every flat face.
static func rounded_box(root: Node3D,size: Vector3,p: Vector3,material: Material,radius: float=.08) -> MeshInstance3D:
	var half: Vector3=size*.5
	radius=minf(radius,minf(half.x,minf(half.y,half.z))*.95)
	var inner: Vector3=half-Vector3.ONE*radius
	var st: SurfaceTool=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in range(3):
		var u: int=(axis+1)%3
		var v: int=(axis+2)%3
		var us: Array[float]=[-half[u],-inner[u],inner[u],half[u]]
		var vs: Array[float]=[-half[v],-inner[v],inner[v],half[v]]
		for sign_value in [-1.0,1.0]:
			for row in range(3):
				for column in range(3):
					var points: Array[Vector3]=[]
					var normals: Array[Vector3]=[]
					var uv: Array[Vector2]=[]
					for offset in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
						var q: Vector3=Vector3.ZERO
						q[axis]=half[axis]*sign_value
						q[u]=us[column+offset.x]
						q[v]=vs[row+offset.y]
						var core: Vector3=q.clamp(-inner,inner)
						var normal: Vector3=(q-core).normalized()
						points.append(core+normal*radius)
						normals.append(normal)
						uv.append(Vector2(q[u]/maxf(size[u],.001)+.5,q[v]/maxf(size[v],.001)+.5))
					for index in ([0,2,1,1,2,3] if sign_value>0 else [0,1,2,2,1,3]):
						st.set_normal(normals[index])
						st.set_uv(uv[index])
						st.add_vertex(points[index])
	st.index()
	return IRArt.part(root,st.commit(),p,material)
