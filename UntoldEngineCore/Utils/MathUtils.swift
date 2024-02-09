//
//  MathUtils.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/17/23.
//

import Foundation
import simd

typealias quaternion=vector_float4

//trig
func degreesToRadians(degrees: Float) -> Float {
    return (degrees * .pi / 180.0)
}

func radiansToDegrees(radians:Float) -> Float{
    return (radians*180.0 / .pi)
}

func safeACos(x:inout Double)->Double{
    
    if (x < -1.0){
        x = -1.0 ;
    }else if (x > 1.0){
        x = 1.0 ;
    }
    return acos (x) ;
    
}

func convertToPositiveAngle(degrees:inout Double)->Double{
    
    degrees=fmod(degrees, 360.0)
    
    if (degrees<0.0) {
        degrees+=360.0
    }
    
    return degrees
}

func areEqualAbs(_ uNumber1:Float, _ uNumber2:Float, uEpsilon:Float)->Bool{
    
    return (abs(uNumber1-uNumber2)<=uEpsilon);
}

func areEqualRel(_ uNumber1:Float, _ uNumber2:Float, uEpsilon:Float)->Bool{
    
    return (abs(uNumber1-uNumber2)<=uEpsilon*max(abs(uNumber1),abs(uNumber2)));
    
}

func areEqual(_ uNumber1:Float, _ uNumber2:Float, uEpsilon:Float)->Bool{
    return (abs(uNumber1-uNumber2)<=uEpsilon*max(1.0,max(abs(uNumber1),abs(uNumber2))));
}


// Generic matrix math utility functions

func matrix4x4Identity() -> matrix_float4x4{
    
    return matrix_float4x4(columns: (vector_float4(1,0,0,0),
                                     vector_float4(0,1,0,0),
                                     vector_float4(0,0,1,0),
                                     vector_float4(0,0,0,1)))
    
}

func matrix4x4_from_quaterion(q:quaternion)->matrix_float4x4{

    let xx:Float = q.x * q.x;
    let xy:Float = q.x * q.y;
    let xz:Float = q.x * q.z;
    let xw:Float = q.x * q.w;
    let yy:Float = q.y * q.y;
    let yz:Float = q.y * q.z;
    let yw:Float = q.y * q.w;
    let zz:Float = q.z * q.z;
    let zw:Float = q.z * q.w;

    // indices are m<column><row>
    let m00:Float = 1 - 2 * (yy + zz);
    let m10:Float = 2 * (xy - zw);
    let m20:Float = 2 * (xz + yw);

    let m01:Float = 2 * (xy + zw);
    let m11:Float = 1 - 2 * (xx + zz);
    let m21:Float = 2 * (yz - xw);

    let m02:Float = 2 * (xz - yw);
    let m12:Float = 2 * (yz + xw);
    let m22:Float = 1 - 2 * (xx + yy);

    let matrix:matrix_float4x4=matrix_float4x4(columns: (vector_float4(m00, m01, m02, 0.0),
                                                         vector_float4(m10,m11,m12,0.0),
                                                         vector_float4(m20,m21,m22,0.0),
                                                         vector_float4(0.0,0.0,0.0,1.0)))

    return matrix;
    
}

func matrix4x4Rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4Translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix4x4Scale(_ scaleX: Float, _ scaleY: Float, _ scaleZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(scaleX, 0, 0, 0),
                                         vector_float4(0, scaleY, 0, 0),
                                         vector_float4(0, 0, scaleZ, 0),
                                         vector_float4(0, 0, 0, 1)))
}

func matrix3x3_upper_left(_ m:matrix_float4x4)->matrix_float3x3{

    let x:vector_float3 = vector_float3(m.columns.0.x,m.columns.0.y,m.columns.0.z)
    let y:vector_float3 = vector_float3(m.columns.1.x,m.columns.1.y,m.columns.1.z)
    let z:vector_float3 = vector_float3(m.columns.2.x,m.columns.2.y,m.columns.2.z)
    
    return matrix_float3x3.init(columns: (x,y,z))
    
}

func matrix_float4x4_from_double4x4(_ m:simd_double4x4)->matrix_float4x4{
    
    return matrix_float4x4.init(columns:(simd_make_float4(Float(m.columns.0.x),Float(m.columns.0.y),Float(m.columns.0.z),Float(m.columns.0.w)),
                                         simd_make_float4(Float(m.columns.1.x),Float(m.columns.1.y),Float(m.columns.1.z),Float(m.columns.1.w)),
                                         simd_make_float4(Float(m.columns.2.x),Float(m.columns.2.y),Float(m.columns.2.z),Float(m.columns.2.w)),
                                         simd_make_float4(Float(m.columns.3.x),Float(m.columns.3.y),Float(m.columns.3.z),Float(m.columns.3.w))))
}

func matrixPerspectiveRightHand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func matrix_look_at_right_hand(_ eye:simd_float3, _ target:simd_float3, _ up:simd_float3)->simd_float4x4{
    
    let z:simd_float3=normalize(eye-target)
    let x:simd_float3=normalize(cross(up, z))
    let y:simd_float3=cross(z, x)
    
    let t:simd_float3=simd_float3(-dot(x, eye),-dot(y,eye),-dot(z,eye))
    
    return matrix_float4x4.init(columns:(vector_float4(x.x, y.x, z.x, 0),
                                         vector_float4( x.y, y.y, z.y, 0),
                                         vector_float4( x.z, y.z, z.z , 0),
                                         vector_float4( t.x, t.y, t.z, 1.0)))
}

func matrix_ortho_right_hand(_ left:Float, _ right:Float, _ bottom:Float, _ top:Float, _ nearZ:Float, farZ:Float)->simd_float4x4{
    
    return matrix_float4x4.init(columns:(vector_float4(2.0/(right-left), 0.0, 0.0, 0.0),
                                         vector_float4( 0.0, 2.0/(top-bottom), 0.0 , 0.0),
                                         vector_float4( 0.0, 0.0, -1.0/(farZ-nearZ), 0.0),
                                         vector_float4( (left+right)/(left-right),(top+bottom)/(bottom-top),nearZ/(nearZ-farZ), 1.0)))
}

func quaternion_identity()->quaternion{
    return quaternion(0.0,0.0,0.0,1.0);
}

func quaternion_normalize(q: quaternion)->quaternion{
    return simd_normalize(q)
}

func quaternion_conjugate(q:quaternion)->quaternion{
    return quaternion(-q.x, -q.y, -q.z, q.w);
}

func quaternion_multiply(q0:quaternion, q1:quaternion)->quaternion{
    
    var q:quaternion=quaternion_identity()
    
    q.x = q0.w*q1.x + q0.x*q1.w + q0.y*q1.z - q0.z*q1.y;
    q.y = q0.w*q1.y - q0.x*q1.z + q0.y*q1.w + q0.z*q1.x;
    q.z = q0.w*q1.z + q0.x*q1.y - q0.y*q1.x + q0.z*q1.w;
    q.w = q0.w*q1.w - q0.x*q1.x - q0.y*q1.y - q0.z*q1.z;
    
    return q;
    
}

func quaternion_lookAt(eye:simd_float3, target:simd_float3, up:simd_float3) ->quaternion{
    
    let forward:simd_float3=simd_normalize(eye-target)
    let right:simd_float3=simd_normalize(simd_cross(up, forward))
    let newUp:simd_float3=simd_cross(forward, right);
    
    var q:quaternion=quaternion_identity()
    
    let trace:Float=right.x+newUp.y+forward.z
    
    if(trace>0.0){
        let s:Float=0.5/sqrt(trace+1.0)
        q.w=0.25/s
        q.x=(newUp.z-forward.y)*s
        q.y=(forward.x-right.z)*s
        q.z=(right.y - newUp.x)*s
    }else{
        
        if(right.x>newUp.y && right.x>forward.z){
            let s:Float=2.0*sqrt(1.0 + right.x - newUp.y - forward.z)
            q.w=(newUp.z - forward.y)/s
            q.x=0.25*s
            q.y=(newUp.x+right.y)/s
            q.z=(forward.x+right.z)/s
        
        }else if(newUp.y > forward.z){
            
            let s:Float=2.0*sqrt(1.0 + newUp.y - right.x - forward.z)
            q.w=(forward.x - right.z)/s
            q.x=(newUp.x + right.y)/s
            q.y=0.25*s
            q.z=(forward.y + newUp.z)/s
        
        }else{
            
            let s:Float=2.0*sqrt(1.0 + forward.z - right.x - newUp.y)
            q.w=(right.y - newUp.x)/s
            q.x=(forward.x + right.z)/s
            q.y=(forward.y + newUp.z)/s
            q.z=0.25*s
        }
    }
    
    
    return q
}

func quaternion_from_axis_angle(axis:simd_float3, radians:Float) -> quaternion{
    let t:Float = radians * 0.5;
    return quaternion(x: axis.x * sinf(t), y: axis.y * sinf(t), z: axis.z * sinf(t), w: cosf(t))
}

func forward_direction_vector_from_quaternion(q:quaternion)->simd_float3{
    
    var direction:simd_float3=simd_float3(0.0,0.0,0.0);
    direction.x = 2.0 * (q.x*q.z - q.w*q.y);
    direction.y = 2.0 * (q.y*q.z + q.w*q.x);
    direction.z = 1.0 - 2.0 * ((q.x * q.x) + (q.y * q.y));

    direction = simd_normalize(direction)
    return direction;
    
}

func up_direction_vector_from_quaternion(q:quaternion)->simd_float3{
    
    var direction:simd_float3=simd_float3(0.0,0.0,0.0);
    direction.x = 2.0 * (q.x*q.y + q.w*q.z);
    direction.y = 1.0 - 2.0 * ((q.x * q.x) + (q.z * q.z));
    direction.z = 2.0 * (q.y*q.z - q.w*q.x);
    

    direction = simd_normalize(direction)
    // Negate for a right-handed coordinate system
    return direction;
    
}

func right_direction_vector_from_quaternion(q:quaternion)->simd_float3{
    
    var direction:simd_float3=simd_float3(0.0,0.0,0.0);
    direction.x = 1.0 - 2.0 * ((q.y * q.y) + (q.z * q.z));
    direction.y = 2.0 * (q.x*q.y - q.w*q.z);
    direction.z = 2.0 * (q.x*q.z + q.w*q.y);
    
    direction = simd_normalize(direction)
    // Negate for a right-handed coordinate system
    return direction;
    
}

func quaternion_rotate_vector(q:quaternion, v:simd_float3)->simd_float3{
    let qp:simd_float3 = simd_float3(q.x,q.y,q.z)
    let w:Float=q.w
    
    let v:simd_float3 = 2.0*simd_dot(qp, v)*qp + ((w*w)-simd_dot(qp,qp))*v+2*w*simd_cross(qp, v)
    
    return v
}

func makeAABB(uOrigin:simd_float3, uHalfWidth:simd_float3)->[simd_float3]{
    
    //compute the min and max of the aabb
    let minDim:simd_float3=simd_float3(uOrigin.x-uHalfWidth.x,uOrigin.y-uHalfWidth.y,uOrigin.z-uHalfWidth.z)
    let maxDim:simd_float3=simd_float3(uOrigin.x+uHalfWidth.x,uOrigin.y+uHalfWidth.y,uOrigin.z+uHalfWidth.z)
    
    return makeAABB(uMin: minDim, uMax: maxDim)
}
func makeAABB(uMin:simd_float3, uMax:simd_float3)->[simd_float3]{

    let width:Float=(abs(uMax.x-uMin.x))/2.0
    let height:Float=(abs(uMax.y-uMin.y))/2.0
    let depth:Float=(abs(uMax.z-uMin.z))/2.0
    
    let v0:simd_float3=simd_float3(width,height,depth)
    let v1:simd_float3=simd_float3(width, height, -depth)
    let v2:simd_float3=simd_float3(-width, height, -depth)
    let v3:simd_float3=simd_float3(-width, height, depth)

    let v4:simd_float3=simd_float3(width,-height,depth)
    let v5:simd_float3=simd_float3(width, -height, -depth)
    let v6:simd_float3=simd_float3(-width, -height, -depth)
    let v7:simd_float3=simd_float3(-width,-height,depth)

    let aabb:[simd_float3]=[v0,v1,v2,v3,v4,v5,v6,v7]
    
    return aabb
}

func rayDirectionInWorldSpace(uMouseLocation:simd_float2, uViewPortDim: simd_float2, uPerspectiveSpace:simd_float4x4, uViewSpace:simd_float4x4)->simd_float3{
    
    //step 1. convert to normalize device coordinates
    //range [-1:1,-1:1,-1:1]
    let x:Float = (2.0 * uMouseLocation.x)/uViewPortDim.x-1.0
    var y:Float = 1.0 - (2.0 * uMouseLocation.y)/uViewPortDim.y

    y *= -1.0
    let z:Float=1.0;

    let rayNDS:simd_float3=simd_float3(x,y,z)

    //step 2. convert to homogeneous clip coordiates
    //range [-1:1,-1:1,-1:1]
    let rayClip:simd_float4=simd_float4(rayNDS.x,rayNDS.y,-1.0,1.0)

    //step 3. convert to camera coordinates
    //range [-x:x,-y:y,-z:z,-w:w]
    var rayCamera:simd_float4=simd_mul(simd_inverse(uPerspectiveSpace), rayClip)
    rayCamera.z = -1.0
    rayCamera.w = 0.0

    //step 4. convert to world coordinates
    //range[-x:x,-y:y,-z:z,-w:w]

    var rayWorld:simd_float4=(simd_mul(simd_inverse(uViewSpace),rayCamera))
    rayWorld=simd_normalize(rayWorld)

    return simd_make_float3(rayWorld)
    
}

func indexTo3DGridMap(index:UInt, sizeX:UInt, sizeY:UInt, sizeZ:UInt) -> simd_uint3{
    
    let x:UInt=index % sizeX
    let z:UInt=(index/sizeX)%sizeZ
    let y:UInt=index/(sizeX*sizeZ)
    
    return simd_uint3(UInt32(x),UInt32(y),UInt32(z))
}

func grid3dToIndexMap(coord:simd_uint3, sizeX:UInt, sizeY:UInt, sizeZ:UInt ) -> UInt{
    
    let index:UInt = UInt(coord.x) + UInt(coord.z)*sizeX + UInt(coord.y)*sizeX*sizeZ
    return index;
}

func getAdjacentVoxels(x:UInt, y:UInt, z:UInt)->[(UInt,UInt,UInt)]{
    
    var adjacentVoxels:[(UInt,UInt,UInt)] = []
    let gridRange=0...sizeOfChunk //range 8x8x8
    
    if gridRange.contains(Int(x)-1){
        adjacentVoxels.append((x-1,y,z))
    }
    
    if gridRange.contains(Int(x)+1){
        adjacentVoxels.append((x+1,y,z))
    }
    
    if gridRange.contains(Int(y)-1){
        adjacentVoxels.append((x,y-1,z))
    }
    
    if gridRange.contains(Int(y)+1){
        adjacentVoxels.append((x,y+1,z))
    }
    
    if gridRange.contains(Int(z)-1){
        adjacentVoxels.append((x,y,z-1))
    }
    
    if gridRange.contains(Int(z)+1){
        adjacentVoxels.append((x,y,z+1))
    }
    
    return adjacentVoxels
}

enum VoxelDirection {
    case tuple(dx: Int, dy: Int, dz: Int)
    case named(direction: String)
}

func getSpecificAdjacentVoxel(x: UInt, y: UInt, z: UInt, direction: VoxelDirection) -> simd_uint3? {
    let gridRange = 0...sizeOfChunk  // Assuming sizeOfChunk is defined elsewhere

    func isInRange(_ value: Int) -> Bool {
        return gridRange.contains(value)
    }

    switch direction {
    case .tuple(let dx, let dy, let dz):
        let newX = Int(x) + dx
        let newY = Int(y) + dy
        let newZ = Int(z) + dz
        if isInRange(newX) && isInRange(newY) && isInRange(newZ) {
            return simd_uint3(UInt32(newX), UInt32(newY), UInt32(newZ))
        }
    case .named(let direction):
        switch direction {
        case "right":
            if isInRange(Int(x) + 1) { return simd_uint3(UInt32(x) + 1, UInt32(y), UInt32(z)) }
        case "left":
            if isInRange(Int(x) - 1) { return simd_uint3(UInt32(x) - 1, UInt32(y), UInt32(z)) }
        case "up":
            if isInRange(Int(y) + 1) { return simd_uint3(UInt32(x), UInt32(y) + 1, UInt32(z)) }
        case "down":
            if isInRange(Int(y) - 1) { return simd_uint3(UInt32(x), UInt32(y) - 1, UInt32(z)) }
        case "forward":
            if isInRange(Int(z) + 1) { return simd_uint3(UInt32(x), UInt32(y), UInt32(z) + 1) }
        case "backward":
            if isInRange(Int(z) - 1) { return simd_uint3(UInt32(x), UInt32(y), UInt32(z) - 1) }
        default:
            print("Invalid direction")
        }
    }
    return nil
}
